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

/// Provides a type for numbers that is compatible with the given type T
/// and conditionally supports unsigned or signed values.
fn GetMathType(comptime T: type, isUnsigned: bool) type {
    return switch (T) {
        u8, u16 => if (isUnsigned) u32 else i32,
        f16 => f16,
        f32 => f32,
        else => unreachable,
    };
}

// Returns a type capable of holding a sum of multiple values of the provided type without overflowing.
// The maximum temporal radius sets the upper bound here, but we have plenty of head room.
fn GetSumType(comptime T: type) type {
    return switch (T) {
        u8 => u16,
        u16 => u32,
        f16 => f16, // Should this be f32???
        f32 => f32, // Should this be a f64 (double)? TODO: Check avisynth.
        // https://github.com/AviSynth/AviSynthPlus/blob/master/avs_core/filters/focus.cpp#L722
        // Looks like they use int for 8-16 bit integer, and float for 32bit float.
        else => unreachable,
    };
}

// 68 fps with u8, radius 1
// 27 fps with u8, radius 7
// 65 fps with u16, radius 1
// 26 fps with u16, radius 7
// 70 fps with f32, radius 1
// TODO: Fix the types in this, as they're overly wide.
fn process_plane_scalar(comptime T: type, srcp: [MAX_DIAMETER][*]const T, dstp: [*]T, width: usize, height: usize, frames: u8, threshold: u32) void {
    const half_frames: u8 = @divTrunc(frames, 2);
    const UnsignedType = GetMathType(T, true);
    const SignedType = GetMathType(T, false);

    for (0..height) |row| {
        for (0..width) |column| {
            const current_pixel = row * width + column;
            const current_value: T = srcp[@intCast(half_frames)][current_pixel];

            var sum: GetSumType(T) = 0;

            for (0..@intCast(frames)) |i| {
                var value = current_value;
                const frame_value: T = srcp[@intCast(i)][current_pixel];
                if (@abs(@as(SignedType, value) - frame_value) <= @as(UnsignedType, @bitCast(threshold))) {
                    value = frame_value;
                }
                sum += value;
            }

            if (cmn.isFloat(T)) {
                // Normal division for floating point
                dstp[current_pixel] = sum / @as(T, @floatFromInt(frames));
            } else {
                // Add half_frames to round the integer value up to the nearest integer value.
                // So a pixel value of 2.5 will be round (and truncated) to 3, while a pixel value of 2.4 will be truncated to 2.
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
    const vec_size = cmn.getVecSize(T);
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
    const vec_size = cmn.getVecSize(T);
    const VecType = @Vector(vec_size, T);

    const threshold_vec: VecType = switch (T) {
        u8, u16 => @splat(@intCast(threshold)),
        f16 => @splat(@floatCast(@as(f32, @bitCast(threshold)))),
        f32 => @splat(@bitCast(threshold)),
        else => unreachable,
    };
    const current_value_vec = cmn.loadVec(VecType, srcp[@intCast(half_frames)], offset);

    const SumType = GetSumType(T);
    var sum_vec: @Vector(vec_size, SumType) = @splat(0);

    for (0..@intCast(frames)) |i| {
        const value_vec = current_value_vec;
        const frame_value_vec = cmn.loadVec(VecType, srcp[@intCast(i)], offset);

        //TODO: this could be optimized further if there was a good way to
        //do @abs(value_vec - frame_value_vec) and *not* overflow the integer.
        //Casting to a higher signed bit depth works, but it's not faster than the max - min approach below.
        const abs_vec = cmn.maxFastVec(value_vec, frame_value_vec) - cmn.minFastVec(value_vec, frame_value_vec);
        const lte_threshold_vec = abs_vec <= threshold_vec;

        sum_vec += @select(T, lte_threshold_vec, frame_value_vec, value_vec);
    }

    const result = blk: {
        if (cmn.isFloat(T)) {
            break :blk sum_vec / @as(VecType, @splat(@floatFromInt(frames)));
        }
        const half_frames_vec: VecType = @splat(@intCast(half_frames));
        const frames_vec: VecType = @splat(frames);
        break :blk @as(VecType, @intCast((sum_vec + half_frames_vec) / frames_vec));
    };

    cmn.storeVec(VecType, dstp, offset, result);
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

fn TemporalSoften(comptime T: type) type {
    return struct {
        pub fn getFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
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

                    var srcp: [MAX_DIAMETER][*]const T = undefined;
                    for (0..@intCast(diameter)) |i| {
                        srcp[i] = @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[i], plane)));
                    }
                    const dstp: [*]T = @ptrCast(@alignCast(vsapi.?.getWritePtr.?(dst, plane)));
                    const width: usize = @intCast(vsapi.?.getFrameWidth.?(dst, plane));
                    const height: usize = @intCast(vsapi.?.getFrameHeight.?(dst, plane));

                    // process_plane_scalar(T, srcp, @ptrCast(@alignCast(dstp)), width, height, diameter, d.threshold[@intCast(plane)]);
                    process_plane_vec(T, srcp, @ptrCast(@alignCast(dstp)), width, height, diameter, d.threshold[@intCast(plane)]);

                    // TODO: The original vapoursynth plugin stores the current frame in
                    // srcp[0], and then stores all previous frames, and then next frames in the rest of the array.
                    // Part of the reason it does this is that it respects SceneChanges, which may lead to a variable number of frames to be processed.
                    //
                    // I need to update this implementation to follow a similar behavior.
                }

                return dst;
            }

            return null;
        }
    };
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
    if (vsh.mapGetN(i32, in, "radius", 0, vsapi)) |radius| {
        if ((radius < 1) or (radius > MAX_RADIUS)) {
            vsapi.?.mapSetError.?(out, "TemporalSoften: Radius must be between 1 and 7 (inclusive)");
            vsapi.?.freeNode.?(d.node);
            return;
        }
        d.radius = @intCast(radius);
    } else {
        d.radius = 1;
    }

    // check luma_threshold param
    // TODO: Add proper validation to these threshold values. Right now I can pass "-1" and the code takes it.
    // Also passing 655555 works even for floating point values, so I need to
    // properly validate these params as the lossy cast is screwing things up.
    d.threshold[0] = vsh.mapGetN(u32, in, "luma_threshold", 0, vsapi) orelse cmn.scaleToSample(d.vi.format, 4);
    if (d.vi.format.colorFamily == vs.ColorFamily.RGB) {
        d.threshold[1] = d.threshold[0];
    }

    if (d.vi.format.colorFamily == vs.ColorFamily.YUV) {
        d.threshold[1] = vsh.mapGetN(u32, in, "chroma_threshold", 0, vsapi) orelse cmn.scaleToSample(d.vi.format, 8);
    }

    d.threshold[2] = d.threshold[1];

    // TODO: There's a bug with checking floating point values, as getPeak returns a u32 that should be @bitCast.
    if (d.threshold[0] < 0 or d.threshold[0] > cmn.getPeak(d.vi.format)) {
        vsapi.?.mapSetError.?(out, cmn.printf(allocator, "TemporalSoften2: luma_threshold must be between 0 and {d} (inclusive)", .{cmn.getPeak(d.vi.format)}).ptr);
        vsapi.?.freeNode.?(d.node);
        return;
    }

    if (d.threshold[1] < 0 or d.threshold[1] > cmn.getPeak(d.vi.format)) {
        vsapi.?.mapSetError.?(out, cmn.printf(allocator, "TemporalSoften2: chroma_threshold must be between 0 and {d} (inclusive)", .{cmn.getPeak(d.vi.format)}).ptr);
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

    // Since the value passed in may be negative or overly large,
    // using a local variable to
    if (vsh.mapGetN(i32, in, "scenechange", 0, vsapi)) |scenechange| {
        if (scenechange < 0 or scenechange > 254) {
            vsapi.?.mapSetError.?(out, "TemporalSoften2: scenechange must be between 0 and 254 (inclusive)");
            vsapi.?.freeNode.?(d.node);
            return;
        }
        d.scenechange = @intCast(scenechange);
    } else {
        d.scenechange = 0;
    }

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

    const getFrame = switch (d.vi.format.bytesPerSample) {
        1 => &TemporalSoften(u8).getFrame,
        2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &TemporalSoften(u16).getFrame else &TemporalSoften(f16).getFrame,
        4 => &TemporalSoften(f32).getFrame,
        else => unreachable,
    };

    vsapi.?.createVideoFilter.?(out, "TemporalSoften2", d.vi, getFrame, temporalSoftenFree, fm.Parallel, &deps, deps.len, data, core);
}
