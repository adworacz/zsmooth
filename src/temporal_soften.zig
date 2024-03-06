const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;
const common = @import("common.zig");

const math = std.math;
const vs = vapoursynth.vapoursynth4;
const vsh = vapoursynth.vshelper;

const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;
const st = vs.SampleType;

// https://ziglang.org/documentation/master/#Choosing-an-Allocator
//
// Using the C allocator since we're passing pointers to allocated memory between Zig and C code,
// specifically the filter data between the Create and GetFrame functions.
const allocator = std.heap.c_allocator;

const MAX_RADIUS = 7;
const MAX_DIAMETER = MAX_RADIUS * 2 + 1;

const TemporalSoftenData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    vi: *const vs.VideoInfo,

    // The temporal radius from which we'll build a median.
    radius: i8,
    // Figure out how to make this work with floating point.
    // maybe use @bitCast to cast back and forth between u32 and f32, etc.
    threshold: [3]u32,
    scenechange: u8,

    // TODO: Perhaps consolidate "process" into "threshold", since they effectively
    // dictate the same thing.
    // Which planes we will process.
    process: [3]bool,
};

// 68 fps with u8, radius 1
// 27 fps with u8, radius 7
// 65 fps with u16, radius 1
// 26 fps with u16, radius 7
// 70 fps with f32, radius 1
fn process_plane_scalar(comptime T: type, srcp: [MAX_DIAMETER][*]const T, dstp: [*]T, width: usize, height: usize, frames: u8, threshold: u32) void {
    const half_frames: u8 = @divTrunc(frames, 2);
    //TODO: Clean up all the damn "if f32/f16" logic to use something a bit more friendly.
    const UnsignedType = if (common.IsFloat(T)) f32 else u32;
    const SignedType = if (common.IsFloat(T)) f32 else i32;

    for (0..height) |row| {
        for (0..width) |column| {
            const current_pixel = row * width + column;
            const current_value: T = srcp[@intCast(half_frames)][current_pixel];

            var sum: UnsignedType = 0;

            for (0..@intCast(frames)) |i| {
                var value = current_value;
                const frame_value: T = srcp[@intCast(i)][current_pixel];
                if (@abs(@as(SignedType, value) - @as(SignedType, frame_value)) <= @as(UnsignedType, @bitCast(threshold))) {
                    value = frame_value;
                }
                sum += value;
            }

            if (common.IsFloat(T)) {
                //TODO: Avisynth doesn't include the half_frames when processing float.
                // dstp[current_pixel] = (sum + common.scale_8bit(T, half_frames, false)) / @as(T, @floatFromInt(frames));
                dstp[current_pixel] = sum / @as(T, @floatFromInt(frames));
            } else {
                dstp[current_pixel] = @intCast((sum + half_frames) / frames);
            }
        }
    }
}

fn process_plane_vec(comptime T: type, srcp: [MAX_DIAMETER][*]const T, dstp: [*]T, width: usize, height: usize, frames: u8, threshold: u32) void {
    const vec_size = common.GetVecSize(T);
    const width_simd = width / vec_size * vec_size;

    for (0..height) |h| {
        var x: usize = 0;
        while (x < width_simd) : (x += vec_size) {
            const offset = h * width + x;
            temporal_smooth_vec(T, srcp, dstp, offset, frames, threshold);
        }

        if (width_simd < width) {
            temporal_smooth_vec(T, srcp, dstp, width - vec_size, frames, threshold);
        }
    }
}

inline fn temporal_smooth_vec(comptime T: type, srcp: [MAX_DIAMETER][*]const T, dstp: [*]T, offset: usize, frames: u8, threshold: u32) void {
    const half_frames: u8 = @divTrunc(frames, 2);
    const vec_size = common.GetVecSize(T);
    const VecType = @Vector(vec_size, T);
    const UnsignedType = if (common.IsFloat(T)) f32 else u32;
    const UnsignedVecType = @Vector(vec_size, UnsignedType);
    const SignedType = if (common.IsFloat(T)) f32 else i32;
    const SignedVecType = @Vector(vec_size, SignedType);

    const threshold_vec: UnsignedVecType = @splat(@as(UnsignedType, @bitCast(threshold)));
    const current_value_vec: VecType = common.loadVec(T, srcp[@intCast(half_frames)], offset, vec_size);

    var sum_vec: @Vector(vec_size, UnsignedType) = @splat(0);

    for (0..@intCast(frames)) |i| {
        const value_vec = current_value_vec;
        // const frame_value_vec: VecType = srcp[@intCast(i)][offset..][0..vec_size].*;
        const frame_value_vec: VecType = common.loadVec(T, srcp[@intCast(i)], offset, vec_size);

        const abs_vec: UnsignedVecType = @abs(@as(SignedVecType, value_vec) - @as(SignedVecType, frame_value_vec));
        const lte_threshold_vec = abs_vec <= threshold_vec;

        sum_vec += @select(T, lte_threshold_vec, frame_value_vec, value_vec);
    }

    const result = blk: {
        if (common.IsFloat(T)) {
            break :blk sum_vec / @as(VecType, @splat(@floatFromInt(frames)));
        }
        const half_frames_vec: UnsignedVecType = @splat(@intCast(half_frames));
        const frames_vec: UnsignedVecType = @splat(frames);
        break :blk @as(VecType, @intCast((sum_vec + half_frames_vec) / frames_vec));
    };

    common.storeVec(T, dstp, offset, vec_size, result);
}
// test "process_plane should find the median value" {
//     //Emulate a 2 x 64 (height x width) video.
//     const T = u8;
//     const height = 2;
//     const width = 64;
//     const size = width * height;
//
//     // Bug is found for radius 6
//     const radius = 6;
//     const diameter = radius * 2 + 1;
//     const expectedMedian = ([_]T{radius + 1} ** size)[0..];
//
//     var src: [MAX_DIAMETER][*]const T = undefined;
//     for (0..diameter) |i| {
//         const frame = try testingAllocator.alloc(T, size);
//         @memset(frame, @intCast(i + 1));
//         src[i] = frame.ptr;
//     }
//     defer {
//         for (0..diameter) |i| {
//             testingAllocator.free(src[i][0..size]);
//         }
//     }
//
//     const dstp_scalar = try testingAllocator.alloc(T, size);
//     const dstp_vec = try testingAllocator.alloc(T, size);
//     defer testingAllocator.free(dstp_scalar);
//     defer testingAllocator.free(dstp_vec);
//
//     process_plane_scalar(T, src, dstp_scalar.ptr, width, height, diameter);
//     process_plane_vec(T, src, dstp_vec.ptr, width, height, diameter);
//
//     try testing.expectEqualDeep(expectedMedian, dstp_scalar);
//     try testing.expectEqualDeep(expectedMedian, dstp_vec);
// }

export fn temporalSoftenGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const d: *TemporalSoftenData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        if (n < d.radius or n > d.vi.numFrames - 1 - d.radius) {
            vsapi.?.requestFrameFilter.?(n, d.node, frame_ctx);
        } else {
            // Request previous, current, and next frames, based on the filter radius.
            var i = -d.radius;
            while (i <= d.radius) : (i += 1) {
                vsapi.?.requestFrameFilter.?(n + i, d.node, frame_ctx);
            }
        }
    } else if (activation_reason == ar.AllFramesReady) {
        // Skip filtering on the first and last frames that lie inside the filter radius,
        // since we do not have enough information to filter them properly.
        if (n < d.radius or n > d.vi.numFrames - 1 - d.radius) {
            return vsapi.?.getFrameFilter.?(n, d.node, frame_ctx);
        }

        const diameter: u8 = @as(u8, @intCast(d.radius)) * 2 + 1;
        var src_frames: [MAX_DIAMETER]?*const vs.Frame = undefined;

        //TODO: Commonize requesting frames in a temporal radius. TemporalMedian does it as well.

        // Retrieve all source frames within the filter radius.
        {
            var i = -d.radius;
            while (i <= d.radius) : (i += 1) {
                src_frames[@intCast(d.radius + i)] = vsapi.?.getFrameFilter.?(n + i, d.node, frame_ctx);
            }
        }
        // Free all source frames within the filter radius when this function exits.
        defer {
            var i = -d.radius;
            while (i <= d.radius) : (i += 1) {
                vsapi.?.freeFrame.?(src_frames[@intCast(d.radius + i)]);
            }
        }

        // Prepare array of frame pointers, with null for planes we will process,
        // and pointers to the source frame for planes we won't process.
        var plane_src = [_]?*const vs.Frame{
            if (d.process[0]) null else src_frames[@intCast(d.radius)],
            if (d.process[1]) null else src_frames[@intCast(d.radius)],
            if (d.process[2]) null else src_frames[@intCast(d.radius)],
        };
        const planes = [_]c_int{ 0, 1, 2 };

        const dst = vsapi.?.newVideoFrame2.?(&d.vi.format, d.vi.width, d.vi.height, @ptrCast(&plane_src), @ptrCast(&planes), src_frames[@intCast(d.radius)], core);

        var plane: c_int = 0;
        while (plane < d.vi.format.numPlanes) : (plane += 1) {
            // Skip planes we aren't supposed to process
            if (!d.process[@intCast(plane)]) {
                continue;
            }

            if (d.threshold[@intCast(plane)] == 0) {
                continue;
            }

            const dstp: [*]u8 = vsapi.?.getWritePtr.?(dst, plane);
            const width: usize = @intCast(vsapi.?.getFrameWidth.?(dst, plane));
            const height: usize = @intCast(vsapi.?.getFrameHeight.?(dst, plane));

            // TODO: The original vapoursynth plugin stores the current frame in
            // srcp[0], and then stores all previous frames, and then next frames in the rest of the array.
            // Part of the reason it does this is that it respects SceneChanges, which may lead to a variable number of frames to be processed.
            //
            // I need to update this implementation to follow a similar behavior.

            //TODO: If Zig gets updated to support functions that return exportable (C compatible) functions,
            //this whole function can be type-paramed, and shrunk significantly.
            //
            //TODO: See if the srcp loading can be optimized a bit more... Maybe a reusable func.
            //TODO: Support an 'opt' param to switch between vector and scalar algoritms.
            switch (d.vi.format.bytesPerSample) {
                1 => {
                    // 8 bit content
                    var srcp: [MAX_DIAMETER][*]const u8 = undefined;
                    for (0..@intCast(diameter)) |i| {
                        srcp[i] = vsapi.?.getReadPtr.?(src_frames[i], plane);
                    }
                    // process_plane_scalar(u8, srcp, dstp, width, height, diameter, d.threshold[@intCast(plane)]);
                    process_plane_vec(u8, srcp, dstp, width, height, diameter, d.threshold[@intCast(plane)]);
                },
                2 => {
                    // 9-16 bit content
                    var srcp: [MAX_DIAMETER][*]const u16 = undefined;
                    for (0..@intCast(diameter)) |i| {
                        srcp[i] = @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[i], plane)));
                    }
                    process_plane_vec(u16, srcp, @ptrCast(@alignCast(dstp)), width, height, diameter, d.threshold[@intCast(plane)]);
                },
                4 => {
                    // 32 bit float content
                    var srcp: [MAX_DIAMETER][*]const f32 = undefined;
                    for (0..@intCast(diameter)) |i| {
                        srcp[i] = @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[i], plane)));
                    }
                    process_plane_vec(f32, srcp, @ptrCast(@alignCast(dstp)), width, height, diameter, d.threshold[@intCast(plane)]);
                },
                else => unreachable,
            }
        }

        return dst;
    }

    return null;
}

export fn temporalSoftenFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *TemporalSoftenData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

pub export fn temporalSoftenCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    var d: TemporalSoftenData = undefined;

    // TODO: Add error handling.
    var err: vs.MapPropertyError = undefined;

    d.node = vsapi.?.mapGetNode.?(in, "clip", 0, &err).?;
    d.vi = vsapi.?.getVideoInfo.?(d.node);

    // Check video format.
    if (!vsh.isConstantVideoFormat(d.vi) or
        (d.vi.format.colorFamily != vs.ColorFamily.YUV and
        d.vi.format.colorFamily != vs.ColorFamily.RGB and
        d.vi.format.colorFamily != vs.ColorFamily.Gray))
    {
        vsapi.?.mapSetError.?(out, "TemporalSoften: only constant format YUV, RGB or Grey input is supported");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    // Check radius param
    const radius = vsh.mapGetN(i64, in, "radius", 0, vsapi) orelse 1;

    if ((radius < 1) or (radius > MAX_RADIUS)) {
        vsapi.?.mapSetError.?(out, "TemporalSoften: Radius must be between 1 and 7 (inclusive)");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    d.radius = @intCast(radius);

    // TODO: Consider if the threshold should be scaled internally.

    // check luma_threshold param
    d.threshold[0] = vsh.mapGetN(u32, in, "luma_threshold", 0, vsapi) orelse 4;
    if (d.vi.format.colorFamily == vs.ColorFamily.RGB) {
        d.threshold[1] = d.threshold[0];
    }

    if (d.vi.format.colorFamily == vs.ColorFamily.YUV) {
        d.threshold[1] = vsh.mapGetN(u32, in, "chroma_threshold", 0, vsapi) orelse 8;
    }

    d.threshold[2] = d.threshold[1];

    // Scale the thresholds accordingly.
    for (&d.threshold, 0..) |*t, i| {
        const isChroma = d.vi.format.colorFamily == vs.ColorFamily.RGB or i > 0;

        t.* = switch (d.vi.format.bytesPerSample) {
            1 => t.*,
            2 => if (d.vi.format.sampleType == vs.SampleType.Integer) common.scale_8bit(u16, @intCast(t.*), false) else @bitCast(common.scale_8bit(f32, @intCast(t.*), isChroma)),
            4 => @bitCast(common.scale_8bit(f32, @intCast(t.*), isChroma)),
            else => unreachable,
        };
    }

    // TODO: Support scenechanges

    const peak = common.get_peak(d.vi.format);

    if (d.threshold[0] < 0 or
        (d.vi.format.sampleType == vs.SampleType.Float and @as(f32, @bitCast(d.threshold[0])) > @as(f32, @bitCast(peak))) or
        (d.vi.format.sampleType == vs.SampleType.Integer and d.threshold[0] > peak))
    {
        vsapi.?.mapSetError.?(out, "TemporalSoften2: luma_threshold must be between 0 and 255 (inclusive, integer) or 1.0 (inclusive, float)");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    if (d.threshold[1] < 0 or
        (d.vi.format.sampleType == vs.SampleType.Float and @as(f32, @bitCast(d.threshold[2])) > @as(f32, @bitCast(peak))) or
        (d.vi.format.sampleType == vs.SampleType.Integer and d.threshold[2] > peak))
    {
        vsapi.?.mapSetError.?(out, "TemporalSoften2: chroma_threshold must be between 0 and 255 (inclusive, integer) or 1.0 (inclusive, float)");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    if (d.threshold[0] == 0 and (d.vi.format.colorFamily == vs.ColorFamily.RGB or d.vi.format.colorFamily == vs.ColorFamily.Gray)) {
        vsapi.?.mapSetError.?(out, "TemporalSoften2: luma_threshold must not be 0 when input is RGB or Gray");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    if (d.threshold[0] == 0 and d.threshold[1] == 0) {
        vsapi.?.mapSetError.?(out, "TemporalSoften2: luma_threshold and chroma_threshold can't both be 0");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    const mode = vsh.mapGetN(u8, in, "mode", 0, vsapi) orelse 2;

    if (mode != 2) {
        vsapi.?.mapSetError.?(out, "TemporalSoften2: mode must be 2. mode 1 is not implemented.");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    //mapNumElements returns -1 if the element doesn't exist (aka, the user doesn't specify the option.)
    const requestedPlanesSize = vsapi.?.mapNumElements.?(in, "planes");
    const requestedPlanesIsEmpty = requestedPlanesSize <= 0;
    const numPlanes = d.vi.format.numPlanes;
    d.process = [_]bool{ requestedPlanesIsEmpty, requestedPlanesIsEmpty, requestedPlanesIsEmpty };

    //TODO: Commonize this
    if (!requestedPlanesIsEmpty) {
        for (0..@intCast(requestedPlanesSize)) |i| {
            const plane: u8 = vsh.mapGetN(u8, in, "planes", @intCast(i), vsapi) orelse unreachable;

            if (plane < 0 or plane > numPlanes) {
                vsapi.?.freeNode.?(d.node);
                // TODO: Add string formatting.
                vsapi.?.mapSetError.?(out, "TemporalSoften: plane index out of range.");
            }

            if (d.process[plane]) {
                vsapi.?.freeNode.?(d.node);
                // TODO: Add string formatting.
                vsapi.?.mapSetError.?(out, "TemporalSoften: plane specified twice.");
            }

            d.process[plane] = true;
        }
    }

    const data: *TemporalSoftenData = allocator.create(TemporalSoftenData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.General,
        },
    };

    vsapi.?.createVideoFilter.?(out, "TemporalSoften2", d.vi, temporalSoftenGetFrame, temporalSoftenFree, fm.Parallel, &deps, deps.len, data, core);
}
