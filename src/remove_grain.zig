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

const RemoveGrainData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    vi: *const vs.VideoInfo,

    // The modes for each plane we will process.
    modes: [3]u5,
};

/// Every pixel is clamped to the lowest and highest values in the pixel's
/// 3x3 neighborhood, center pixel not included.
fn rgMode1(comptime T: type, c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
    return @max(@min(a1, a2, a3, a4, a5, a6, a7, a8), @min(c, @max(a1, a2, a3, a4, a5, a6, a7, a8)));
}

test rgMode1 {
    // In range
    try std.testing.expectEqual(5, rgMode1(u8, 5, 1, 1, 1, 1, 8, 8, 8, 8));

    // Out of range - high
    try std.testing.expectEqual(8, rgMode1(u8, 10, 1, 1, 1, 1, 8, 8, 8, 8));

    // Out of range - low
    try std.testing.expectEqual(2, rgMode1(u8, 1, 2, 2, 2, 2, 8, 8, 8, 8));
}

/// Same as mode 1, except the second-lowest and second-highest values are used.
fn rgMode2(comptime T: type, c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
    // "normal" implementation, but stupid slow due to the sorting algorithm.
    var a = [_]T{ c, a1, a2, a3, a4, a5, a6, a7, a8 };
    // std.mem.sortUnstable(T, &a, {}, comptime std.sort.asc(T));
    // // clamp to 2nd lowest and 2nd highest.
    // return std.math.clamp(c, a[2 - 1], a[7 - 1]);

    // min-max sorting algorithm.

    // Sort pixel pairs 1 pixel away
    cmn.compare_swap(T, &a[1], &a[2]);
    cmn.compare_swap(T, &a[3], &a[4]);
    cmn.compare_swap(T, &a[5], &a[6]);
    cmn.compare_swap(T, &a[7], &a[8]);

    // Sort pixel pairs 2 pixels away
    cmn.compare_swap(T, &a[1], &a[3]);
    cmn.compare_swap(T, &a[2], &a[4]);
    cmn.compare_swap(T, &a[5], &a[7]);
    cmn.compare_swap(T, &a[6], &a[8]);

    cmn.compare_swap(T, &a[2], &a[3]);
    cmn.compare_swap(T, &a[6], &a[7]);

    a[5] = @max(a[1], a[5]); // compare_swap(a[1], a[5]);
    cmn.compare_swap(T, &a[2], &a[6]);
    cmn.compare_swap(T, &a[3], &a[7]);
    a[4] = @min(a[4], a[8]); // compare_swap(a[4], a[8]);

    a[3] = @min(a[3], a[5]); // compare_swap(a[3], a[5]);
    a[6] = @max(a[4], a[6]); // compare_swap(a[4], a[6]);

    a[2] = @min(a[2], a[3]); // compare_swap(a[2], a[3]);
    a[7] = @max(a[6], a[7]); // compare_swap(a[6], a[7]);

    return std.math.clamp(c, a[2], a[7]);
}

fn process_plane_scalar(comptime T: type, srcp: [*]const T, dstp: [*]T, width: usize, height: usize, mode: u5) void {
    // Copy the first line.
    @memcpy(dstp, srcp[0..width]);

    for (1..height - 1) |h| {
        //TODO: This will need to change for skipline/interlaced support.

        // Copy the pixel at the beginning of the line.
        dstp[(h * width)] = srcp[(h * width)];
        for (1..width - 1) |w| {
            // Retrieve pixels from the 3x3 grid surrounding the current pixel
            //
            // a1 a2 a3
            // a4  c a5
            // a6 a7 a8

            // Build c and a1-a8 pixels.
            const rowPrev = ((h - 1) * width);
            const rowCurr = ((h) * width);
            const rowNext = ((h + 1) * width);

            const a1 = srcp[rowPrev + w - 1];
            const a2 = srcp[rowPrev + w];
            const a3 = srcp[rowPrev + w + 1];

            const a4 = srcp[rowCurr + w - 1];
            const c = srcp[rowCurr + w];
            const a5 = srcp[rowCurr + w + 1];

            const a6 = srcp[rowNext + w - 1];
            const a7 = srcp[rowNext + w];
            const a8 = srcp[rowNext + w + 1];

            dstp[rowCurr + w] = switch (mode) {
                1 => rgMode1(T, c, a1, a2, a3, a4, a5, a6, a7, a8),
                2 => rgMode2(T, c, a1, a2, a3, a4, a5, a6, a7, a8),
                else => unreachable,
            };
        }
        // Copy the pixel at the end of the line.
        dstp[(h * width) + (width - 1)] = srcp[(h * width) + (width - 1)];
    }

    // Copy the last line.
    const lastLine = ((height - 1) * width);
    @memcpy(dstp[lastLine..], srcp[lastLine..(lastLine + width)]);
}

fn process_plane_vec(comptime T: type, srcp: [*]const T, dstp: [*]T, width: usize, height: usize, mode: u5) void {
    const vec_size = cmn.GetVecSize(T);
    const width_simd = width / vec_size * vec_size;

    // Copy the first line.
    @memcpy(dstp, srcp[0..width]);

    for (1..height - 1) |h| {
        //TODO: This will need to change for skipline/interlaced support.

        // Copy the pixel at the beginning of the line.
        dstp[(h * width)] = srcp[(h * width)];

        // TODO: Should this just be aligned, including the first pixel?
        // Might lead to better performance, and we're manually overwriting the first pixel anyway.
        var w: usize = 0;
        while (w < width_simd) : (w += vec_size) {
            // Retrieve pixels from the 3x3 grid surrounding the current pixel
            //
            // a1 a2 a3
            // a4  c a5
            // a6 a7 a8

            // Build c and a1-a8 pixels.
            const rowPrev = ((h - 1) * width);
            const rowCurr = ((h) * width);
            const rowNext = ((h + 1) * width);

            // const a1: T = srcp[rowPrev + w - 1];
            const VecType = @Vector(vec_size, T);
            const a1 = cmn.loadVec(VecType, srcp, rowPrev + w - 1);
            const a2 = cmn.loadVec(VecType, srcp, rowPrev + w);
            const a3 = cmn.loadVec(VecType, srcp, rowPrev + w + 1);

            const a4 = cmn.loadVec(VecType, srcp, rowCurr + w - 1);
            const c = cmn.loadVec(VecType, srcp, rowCurr + w);
            const a5 = cmn.loadVec(VecType, srcp, rowCurr + w + 1);

            const a6 = cmn.loadVec(VecType, srcp, rowNext + w - 1);
            const a7 = cmn.loadVec(VecType, srcp, rowNext + w);
            const a8 = cmn.loadVec(VecType, srcp, rowNext + w + 1);

            const result = switch (mode) {
                1 => rgMode1(VecType, c, a1, a2, a3, a4, a5, a6, a7, a8),
                else => unreachable,
            };

            cmn.storeVec(VecType, dstp, rowCurr + w, result);
        }

        // TODO: Handle non SIMD size widths.
        // if (width_simd < width) {}

        // Copy the last pixel
        dstp[(h * width) + (width - 1)] = srcp[(h * width) + (width - 1)];
    }

    // Copy the last line.
    const lastLine = ((height - 1) * width);
    @memcpy(dstp[lastLine..], srcp[lastLine..(lastLine + width)]);
}

// fn process_plane_vec(comptime T: type, srcp: [*]const T, dstp: [*]T, width: usize, height: usize, mode: u5) void {
//     _ = srcp;
//     _ = dstp;
//     _ = width;
//     _ = height;
//     _ = mode;
// }

// test "process_plane should find the average value" {
//     //Emulate a 2 x 64 (height x width) video.
//     const T = u8;
//     const height = 2;
//     const width = 64;
//     const size = width * height;
//
//     const radius = 2;
//     const diameter = radius * 2 + 1;
//     const threshold = 4;
//     const expectedAverage = ([_]T{3} ** size)[0..];
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
//     process_plane_scalar(T, src, dstp_scalar.ptr, width, height, diameter, threshold);
//     process_plane_vec(T, src, dstp_vec.ptr, width, height, diameter, threshold);
//
//     try testing.expectEqualDeep(expectedAverage, dstp_scalar);
//     try testing.expectEqualDeep(expectedAverage, dstp_vec);
// }

export fn removeGrainGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const d: *RemoveGrainData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        vsapi.?.requestFrameFilter.?(n, d.node, frame_ctx);
    } else if (activation_reason == ar.AllFramesReady) {
        const src_frame = vsapi.?.getFrameFilter.?(n, d.node, frame_ctx);
        defer vsapi.?.freeFrame.?(src_frame);

        // Prepare array of frame pointers, with null for planes we will process,
        // and pointers to the source frame for planes we won't process.
        var plane_src = [_]?*const vs.Frame{
            if (d.modes[0] > 0) null else src_frame,
            if (d.modes[1] > 0) null else src_frame,
            if (d.modes[2] > 0) null else src_frame,
        };
        const planes = [_]c_int{ 0, 1, 2 };

        const dst = vsapi.?.newVideoFrame2.?(&d.vi.format, d.vi.width, d.vi.height, @ptrCast(&plane_src), @ptrCast(&planes), src_frame, core);

        var plane: c_int = 0;
        while (plane < d.vi.format.numPlanes) : (plane += 1) {
            // Skip planes we aren't supposed to process
            if (d.modes[@intCast(plane)] == 0) {
                continue;
            }

            const srcp: [*]const u8 = vsapi.?.getReadPtr.?(src_frame, plane);
            const dstp: [*]u8 = vsapi.?.getWritePtr.?(dst, plane);
            const width: usize = @intCast(vsapi.?.getFrameWidth.?(dst, plane));
            const height: usize = @intCast(vsapi.?.getFrameHeight.?(dst, plane));

            switch (d.vi.format.bytesPerSample) {
                1 => {
                    // 8 bit content
                    process_plane_scalar(u8, srcp, dstp, width, height, d.modes[@intCast(plane)]);
                    // process_plane_vec(u8, srcp, dstp, width, height, d.modes[@intCast(plane)]);
                },
                2 => {
                    // 9-16 bit content
                    if (d.vi.format.sampleType == vs.SampleType.Integer) {
                        process_plane_scalar(u16, @ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height, d.modes[@intCast(plane)]);
                        // process_plane_vec(u16, @ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height, d.modes[@intCast(plane)]);
                    } else {
                        // Processing f16 as f16 is dog slow, in both scalar and vector.
                        // Likely faster if I process it in f32...
                        process_plane_scalar(f16, @ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height, d.modes[@intCast(plane)]);
                        // process_plane_vec(f16, @ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height, d.modes[@intCast(plane)]);
                    }
                },
                4 => {
                    // 32 bit float content
                    process_plane_scalar(f32, @ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height, d.modes[@intCast(plane)]);
                    // process_plane_vec(f32, @ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height, d.modes[@intCast(plane)]);
                },
                else => unreachable,
            }
        }

        return dst;
    }

    return null;
}

export fn removeGrainFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *RemoveGrainData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

pub export fn removeGrainCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    var d: RemoveGrainData = undefined;

    // TODO: Add error handling.
    var err: vs.MapPropertyError = undefined;

    d.node = vsapi.?.mapGetNode.?(in, "clip", 0, &err).?;
    d.vi = vsapi.?.getVideoInfo.?(d.node);

    // Check video format.
    // TODO: This doesn't actually matter does it? Since this is a strictly spatial filter
    // it shouldn't matter right?
    if (!vsh.isConstantVideoFormat(d.vi)) {
        vsapi.?.mapSetError.?(out, "RemoveGrain: only constant format video is supported");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    const numModes = vsapi.?.mapNumElements.?(in, "mode");
    if (numModes > d.vi.format.numPlanes) {
        vsapi.?.mapSetError.?(out, "RemoveGrain: Number of modes must be equal or fewer than the number of input planes.");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    for (0..3) |i| {
        if (i < numModes) {
            if (vsh.mapGetN(i32, in, "mode", @intCast(i), vsapi)) |mode| {
                if (mode < 0 or mode > 24) {
                    vsapi.?.mapSetError.?(out, "RemoveGrain: Invalid mode specified, only modes 0-24 supported.");
                    vsapi.?.freeNode.?(d.node);
                    return;
                }
                d.modes[i] = @intCast(mode);
            }
        } else {
            d.modes[i] = d.modes[i - 1];
        }
    }

    const data: *RemoveGrainData = allocator.create(RemoveGrainData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
    };

    vsapi.?.createVideoFilter.?(out, "RemoveGrain", d.vi, removeGrainGetFrame, removeGrainFree, fm.Parallel, &deps, deps.len, data, core);
}
