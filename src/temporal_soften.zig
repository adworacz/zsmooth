const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;
const cmn = @import("common.zig");

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
};

// 68 fps with u8, radius 1
// 27 fps with u8, radius 7
// 65 fps with u16, radius 1
// 26 fps with u16, radius 7
// 70 fps with f32, radius 1
fn process_plane_scalar(comptime T: type, srcp: [MAX_DIAMETER][*]const T, dstp: [*]T, width: usize, height: usize, frames: u8, threshold: u32) void {
    const half_frames: u8 = @divTrunc(frames, 2);
    //TODO: Clean up all the damn "if f32/f16" logic to use something a bit more friendly.
    const UnsignedType = if (cmn.IsFloat(T)) f32 else u32;
    const SignedType = if (cmn.IsFloat(T)) f32 else i32;

    for (0..height) |row| {
        for (0..width) |column| {
            const current_pixel = row * width + column;
            const current_value: T = srcp[@intCast(half_frames)][current_pixel];

            var sum: UnsignedType = 0;

            for (0..@intCast(frames)) |i| {
                var value = current_value;
                const frame_value: T = srcp[@intCast(i)][current_pixel];
                if (@abs(@as(SignedType, value) - frame_value) <= @as(UnsignedType, @bitCast(threshold))) {
                    value = frame_value;
                }
                sum += value;
            }

            if (cmn.IsFloat(T)) {
                //TODO: Avisynth doesn't include the half_frames when processing float.
                // dstp[current_pixel] = (sum + common.scale_8bit(T, half_frames, false)) / @as(T, @floatFromInt(frames));
                dstp[current_pixel] = sum / @as(T, @floatFromInt(frames));
            } else {
                dstp[current_pixel] = @intCast((sum + half_frames) / frames);
            }
        }
    }
}

// 91 fps with u8, radius 1
// 93 fps with u8, radius 1, float mode optimized
// 64 fps with u8, radius 7
// 83 fps with u16, radius 1
// 87 fps with u16, radius 1, float mode optimized
// 60 fps with u16, radius 7
// 76 fps with fp32, radius 1
// 100 fps with fp32, radius 1, float mode optimized
// 55 fps with fp32, radius 7
fn process_plane_vec(comptime T: type, srcp: [MAX_DIAMETER][*]const T, dstp: [*]T, width: usize, height: usize, frames: u8, threshold: u32) void {
    const vec_size = cmn.GetVecSize(T);
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
    @setFloatMode(.Optimized);
    const half_frames: u8 = @divTrunc(frames, 2);
    const vec_size = cmn.GetVecSize(T);
    const VecType = @Vector(vec_size, T);

    const UnsignedType = if (cmn.IsFloat(T)) f32 else u32;
    const UnsignedVecType = @Vector(vec_size, UnsignedType);
    const SignedType = if (cmn.IsFloat(T)) f32 else i32;
    const SignedVecType = @Vector(vec_size, SignedType);

    const threshold_vec: UnsignedVecType = @splat(@as(UnsignedType, @bitCast(threshold)));
    const current_value_vec: VecType = cmn.loadVec(vec_size, T, srcp[@intCast(half_frames)], offset);

    var sum_vec: UnsignedVecType = @splat(0);

    for (0..@intCast(frames)) |i| {
        const value_vec = current_value_vec;
        const frame_value_vec = cmn.loadVec(vec_size, T, srcp[@intCast(i)], offset);

        const abs_vec = @abs(@as(SignedVecType, value_vec) - frame_value_vec);
        const lte_threshold_vec = abs_vec <= threshold_vec;

        sum_vec += @select(T, lte_threshold_vec, frame_value_vec, value_vec);
    }

    const result = blk: {
        if (cmn.IsFloat(T)) {
            break :blk sum_vec / @as(VecType, @splat(@floatFromInt(frames)));
        }
        const half_frames_vec: UnsignedVecType = @splat(@intCast(half_frames));
        const frames_vec: UnsignedVecType = @splat(frames);
        break :blk @as(VecType, @intCast((sum_vec + half_frames_vec) / frames_vec));
    };

    cmn.storeVec(vec_size, T, dstp, offset, result);
}

test "process_plane should find the average value" {
    //Emulate a 2 x 64 (height x width) video.
    const T = u8;
    const height = 2;
    const width = 64;
    const size = width * height;

    const radius = 2;
    const diameter = radius * 2 + 1;
    const threshold = 4;
    const expectedAverage = ([_]T{3} ** size)[0..];

    var src: [MAX_DIAMETER][*]const T = undefined;
    for (0..diameter) |i| {
        const frame = try testingAllocator.alloc(T, size);
        @memset(frame, @intCast(i + 1));
        src[i] = frame.ptr;
    }
    defer {
        for (0..diameter) |i| {
            testingAllocator.free(src[i][0..size]);
        }
    }

    const dstp_scalar = try testingAllocator.alloc(T, size);
    const dstp_vec = try testingAllocator.alloc(T, size);
    defer testingAllocator.free(dstp_scalar);
    defer testingAllocator.free(dstp_vec);

    process_plane_scalar(T, src, dstp_scalar.ptr, width, height, diameter, threshold);
    process_plane_vec(T, src, dstp_vec.ptr, width, height, diameter, threshold);

    try testing.expectEqualDeep(expectedAverage, dstp_scalar);
    try testing.expectEqualDeep(expectedAverage, dstp_vec);
}

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
            if (d.threshold[0] > 0) null else src_frames[@intCast(d.radius)],
            if (d.threshold[1] > 0) null else src_frames[@intCast(d.radius)],
            if (d.threshold[2] > 0) null else src_frames[@intCast(d.radius)],
        };
        const planes = [_]c_int{ 0, 1, 2 };

        const dst = vsapi.?.newVideoFrame2.?(&d.vi.format, d.vi.width, d.vi.height, @ptrCast(&plane_src), @ptrCast(&planes), src_frames[@intCast(d.radius)], core);

        var plane: c_int = 0;
        while (plane < d.vi.format.numPlanes) : (plane += 1) {
            // Skip planes we aren't supposed to process
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
    d.radius = vsh.mapGetN(i8, in, "radius", 0, vsapi) orelse 1;

    if ((d.radius < 1) or (d.radius > MAX_RADIUS)) {
        vsapi.?.mapSetError.?(out, "TemporalSoften: Radius must be between 1 and 7 (inclusive)");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    // check luma_threshold param
    d.threshold[0] = vsh.mapGetN(u32, in, "luma_threshold", 0, vsapi) orelse 4;
    if (d.vi.format.colorFamily == vs.ColorFamily.RGB) {
        d.threshold[1] = d.threshold[0];
    }

    if (d.vi.format.colorFamily == vs.ColorFamily.YUV) {
        d.threshold[1] = vsh.mapGetN(u32, in, "chroma_threshold", 0, vsapi) orelse 8;
    }

    d.threshold[2] = d.threshold[1];

    if (d.threshold[0] < 0 or d.threshold[0] > 255) {
        vsapi.?.mapSetError.?(out, "TemporalSoften2: luma_threshold must be between 0 and 255 (inclusive)");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    if (d.threshold[1] < 0 or d.threshold[1] > 255) {
        vsapi.?.mapSetError.?(out, "TemporalSoften2: chroma_threshold must be between 0 and 255 (inclusive)");
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

    // Scale the thresholds accordingly.
    for (&d.threshold, 0..) |*t, i| {
        const isChroma = d.vi.format.colorFamily == vs.ColorFamily.RGB or i > 0;

        t.* = switch (d.vi.format.bytesPerSample) {
            1 => t.*,
            2 => if (d.vi.format.sampleType == vs.SampleType.Integer) cmn.scale_8bit(u16, @intCast(t.*), false) else @bitCast(cmn.scale_8bit(f32, @intCast(t.*), isChroma)),
            4 => @bitCast(cmn.scale_8bit(f32, @intCast(t.*), isChroma)),
            else => unreachable,
        };
    }

    // TODO: Support scenechanges

    const mode = vsh.mapGetN(u8, in, "mode", 0, vsapi) orelse 2;

    if (mode != 2) {
        vsapi.?.mapSetError.?(out, "TemporalSoften2: mode must be 2. mode 1 is not implemented.");
        vsapi.?.freeNode.?(d.node);
        return;
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