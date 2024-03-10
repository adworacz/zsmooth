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

/// Using a generic struct here as an optimization mechanism.
///
/// Essentially, when I first implemented things using just raw functions.
/// as soon as I supported 4 modes using a switch in the process_plane_scalar
/// function, performance dropped like a rock from 700+fps down to 40fps.
///
/// This meant that the Zig compiler couldn't optimize code properly.
///
/// With this implementation, I can generate perfect auto-vectorized code for each mode
/// at compile time (in which case the switch inside process_plane_scalar is optimized away).
///
/// It requires a "double switch" to in the GetFrame method in order to jump from runtime-land to compiletime-land
/// but it produces well optimized code at the expensive of a little visual repetition.
///
/// I techinically don't need the generic struct, and can get by with just a comptime mode param to process_plane_scalar,
/// but using a struct means I only need to specify a type param once instead of for each function, so it's slightly cleaner.
fn RemoveGrain(comptime T: type, mode: comptime_int) type {
    return struct {
        fn removeGrainGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
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

                    // Yes, there's a bunch of switches here, but it is for optimization purposes
                    // so that Zig can generate optimized RG functions for each type and mode and pick them at runtime.
                    switch (d.vi.format.bytesPerSample) {
                        1 => {
                            // 8 bit content
                            switch (d.modes[@intCast(plane)]) {
                                1 => RemoveGrain(u8, 1).process_plane_scalar(srcp, dstp, width, height),
                                2 => RemoveGrain(u8, 2).process_plane_scalar(srcp, dstp, width, height),
                                3 => RemoveGrain(u8, 3).process_plane_scalar(srcp, dstp, width, height),
                                4 => RemoveGrain(u8, 4).process_plane_scalar(srcp, dstp, width, height),
                                else => unreachable,
                            }
                        },
                        2 => {
                            // 9-16 bit content
                            if (d.vi.format.sampleType == vs.SampleType.Integer) {
                                switch (d.modes[@intCast(plane)]) {
                                    1 => RemoveGrain(u16, 1).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
                                    2 => RemoveGrain(u16, 2).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
                                    3 => RemoveGrain(u16, 3).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
                                    4 => RemoveGrain(u16, 4).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
                                    else => unreachable,
                                }
                            } else {
                                // Processing f16 as f16 is dog slow, in both scalar and vector.
                                // Likely faster if I process it in f32...
                                switch (d.modes[@intCast(plane)]) {
                                    1 => RemoveGrain(f16, 1).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
                                    2 => RemoveGrain(f16, 2).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
                                    3 => RemoveGrain(f16, 3).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
                                    4 => RemoveGrain(f16, 4).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
                                    else => unreachable,
                                }
                            }
                        },
                        4 => {
                            // 32 bit float content
                            switch (d.modes[@intCast(plane)]) {
                                1 => RemoveGrain(f32, 1).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
                                2 => RemoveGrain(f32, 2).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
                                3 => RemoveGrain(f32, 3).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
                                4 => RemoveGrain(f32, 4).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
                                else => unreachable,
                            }
                        },
                        else => unreachable,
                    }
                }

                return dst;
            }

            return null;
        }

        pub fn process_plane_scalar(srcp: [*]const T, dstp: [*]T, width: usize, height: usize) void {
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

                    // dstp[rowCurr + w] = rg(c, a1, a2, a3, a4, a5, a6, a7, a8);
                    dstp[rowCurr + w] = switch (mode) {
                        1 => rgMode1(c, a1, a2, a3, a4, a5, a6, a7, a8),
                        2 => rgMode2(c, a1, a2, a3, a4, a5, a6, a7, a8),
                        3 => rgMode3(c, a1, a2, a3, a4, a5, a6, a7, a8),
                        4 => rgMode4(c, a1, a2, a3, a4, a5, a6, a7, a8),
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

        /// Every pixel is clamped to the lowest and highest values in the pixel's
        /// 3x3 neighborhood, center pixel not included.
        pub fn rgMode1(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            return @max(@min(a1, a2, a3, a4, a5, a6, a7, a8), @min(c, @max(a1, a2, a3, a4, a5, a6, a7, a8)));
        }

        pub fn rgMode2(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) @TypeOf(c) {
            var a = [_]T{ c, a1, a2, a3, a4, a5, a6, a7, a8 };
            // "normal" implementation, but stupid slow due to the sorting algorithm.
            // std.mem.sortUnstable(T, &a, {}, comptime std.sort.asc(T));
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

            // compare pivots
            cmn.compare_swap(T, &a[2], &a[3]);
            cmn.compare_swap(T, &a[6], &a[7]);

            // Sort pixels pairs 4 pixels away
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

        /// Same as mode 1, except the third-lowest and third-highest values are used.
        // fn rgMode3(comptime T: type, c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
        pub fn rgMode3(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            var a = [_]T{ c, a1, a2, a3, a4, a5, a6, a7, a8 };
            // "normal" implementation, but stupid slow due to the sorting algorithm.
            // std.mem.sortUnstable(T, &a, {}, comptime std.sort.asc(T));
            // return std.math.clamp(c, a[3 - 1], a[6 - 1]);

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

            // compare pivots
            cmn.compare_swap(T, &a[2], &a[3]);
            cmn.compare_swap(T, &a[6], &a[7]);

            // Sort pixels pairs 4 pixels away
            a[5] = @max(a[1], a[5]); // compare_swap(a[1], a[5]);
            cmn.compare_swap(T, &a[2], &a[6]);
            cmn.compare_swap(T, &a[3], &a[7]);
            a[4] = @min(a[4], a[8]); // compare_swap(a[4], a[8]);

            a[3] = @min(a[3], a[5]); // compare_swap(a[3], a[5]);
            a[6] = @max(a[4], a[6]); // compare_swap(a[4], a[6]);

            //everything above this line is identical to Mode 2.

            a[3] = @max(a[2], a[3]); // compare_swap(a[2], a[3]);
            a[6] = @min(a[6], a[7]); // compare_swap(a[6], a[7]);

            return std.math.clamp(c, a[3], a[6]);
        }

        /// Same as mode 1, except the fourth-lowest and fourth-highest values are used.
        /// This is identical to std.Median.
        // fn rgMode4(comptime T: type, c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
        pub fn rgMode4(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            var a = [_]T{ c, a1, a2, a3, a4, a5, a6, a7, a8 };
            // "normal" implementation, but stupid slow due to the sorting algorithm.
            // std.mem.sortUnstable(T, &a, {}, comptime std.sort.asc(T));
            // return std.math.clamp(c, a[3 - 1], a[6 - 1]);

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

            // compare pivots
            cmn.compare_swap(T, &a[2], &a[3]);
            cmn.compare_swap(T, &a[6], &a[7]);

            // Everything above this is identical to mode 1.

            // Sort pixels pairs 4 pixels away
            a[5] = @max(a[1], a[5]); // compare_swap(a[1], a[5]);
            a[6] = @max(a[2], a[6]); // compare_swap(a[2], a[6]);
            a[3] = @min(a[3], a[7]); // compare_swap(a[3], a[7]);
            a[4] = @min(a[4], a[8]); // compare_swap(a[4], a[8]);

            a[5] = @max(a[3], a[5]); // compare_swap(a[3], a[5]);
            a[4] = @min(a[4], a[6]); // compare_swap(a[4], a[6]);

            cmn.compare_swap(T, &a[4], &a[5]);

            return std.math.clamp(c, a[4], a[5]);
        }

        test "RG Mode 1-4" {
            // In range
            try std.testing.expectEqual(5, rgMode1(5, 1, 2, 3, 4, 6, 7, 8, 9));
            try std.testing.expectEqual(5, rgMode2(5, 1, 2, 3, 4, 6, 7, 8, 9));
            try std.testing.expectEqual(5, rgMode3(5, 1, 2, 3, 4, 6, 7, 8, 9));
            try std.testing.expectEqual(5, rgMode4(5, 1, 2, 3, 4, 6, 7, 8, 9));

            // Out of range - high
            try std.testing.expectEqual(9, rgMode1(10, 1, 2, 3, 4, 6, 7, 8, 9));
            try std.testing.expectEqual(8, rgMode2(10, 1, 2, 3, 4, 6, 7, 8, 9));
            try std.testing.expectEqual(7, rgMode3(10, 1, 2, 3, 4, 6, 7, 8, 9));
            try std.testing.expectEqual(6, rgMode4(10, 1, 2, 3, 4, 6, 7, 8, 9));

            // Out of range - low
            try std.testing.expectEqual(1, rgMode1(0, 1, 2, 3, 4, 6, 7, 8, 9));
            try std.testing.expectEqual(2, rgMode2(0, 1, 2, 3, 4, 6, 7, 8, 9));
            try std.testing.expectEqual(3, rgMode3(0, 1, 2, 3, 4, 6, 7, 8, 9));
            try std.testing.expectEqual(4, rgMode4(0, 1, 2, 3, 4, 6, 7, 8, 9));
        }
    };
}

// fn process_plane_vec(comptime T: type, srcp: [*]const T, dstp: [*]T, width: usize, height: usize, mode: u5) void {
//     const vec_size = cmn.GetVecSize(T);
//     const width_simd = width / vec_size * vec_size;
//
//     // Copy the first line.
//     @memcpy(dstp, srcp[0..width]);
//
//     for (1..height - 1) |h| {
//         //TODO: This will need to change for skipline/interlaced support.
//
//         // Copy the pixel at the beginning of the line.
//         dstp[(h * width)] = srcp[(h * width)];
//
//         // TODO: Should this just be aligned, including the first pixel?
//         // Might lead to better performance, and we're manually overwriting the first pixel anyway.
//         var w: usize = 0;
//         while (w < width_simd) : (w += vec_size) {
//             // Retrieve pixels from the 3x3 grid surrounding the current pixel
//             //
//             // a1 a2 a3
//             // a4  c a5
//             // a6 a7 a8
//
//             // Build c and a1-a8 pixels.
//             const rowPrev = ((h - 1) * width);
//             const rowCurr = ((h) * width);
//             const rowNext = ((h + 1) * width);
//
//             // const a1: T = srcp[rowPrev + w - 1];
//             const VecType = @Vector(vec_size, T);
//             const a1 = cmn.loadVec(VecType, srcp, rowPrev + w - 1);
//             const a2 = cmn.loadVec(VecType, srcp, rowPrev + w);
//             const a3 = cmn.loadVec(VecType, srcp, rowPrev + w + 1);
//
//             const a4 = cmn.loadVec(VecType, srcp, rowCurr + w - 1);
//             const c = cmn.loadVec(VecType, srcp, rowCurr + w);
//             const a5 = cmn.loadVec(VecType, srcp, rowCurr + w + 1);
//
//             const a6 = cmn.loadVec(VecType, srcp, rowNext + w - 1);
//             const a7 = cmn.loadVec(VecType, srcp, rowNext + w);
//             const a8 = cmn.loadVec(VecType, srcp, rowNext + w + 1);
//
//             const result = switch (mode) {
//                 1 => rgMode1(VecType, c, a1, a2, a3, a4, a5, a6, a7, a8),
//                 else => unreachable,
//             };
//
//             cmn.storeVec(VecType, dstp, rowCurr + w, result);
//         }
//
//         // TODO: Handle non SIMD size widths.
//         // if (width_simd < width) {}
//
//         // Copy the last pixel
//         dstp[(h * width) + (width - 1)] = srcp[(h * width) + (width - 1)];
//     }
//
//     // Copy the last line.
//     const lastLine = ((height - 1) * width);
//     @memcpy(dstp[lastLine..], srcp[lastLine..(lastLine + width)]);
// }
//
// export fn removeGrainGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
//     // Assign frame_data to nothing to stop compiler complaints
//     _ = frame_data;
//
//     const d: *RemoveGrainData = @ptrCast(@alignCast(instance_data));
//
//     if (activation_reason == ar.Initial) {
//         vsapi.?.requestFrameFilter.?(n, d.node, frame_ctx);
//     } else if (activation_reason == ar.AllFramesReady) {
//         const src_frame = vsapi.?.getFrameFilter.?(n, d.node, frame_ctx);
//         defer vsapi.?.freeFrame.?(src_frame);
//
//         // Prepare array of frame pointers, with null for planes we will process,
//         // and pointers to the source frame for planes we won't process.
//         var plane_src = [_]?*const vs.Frame{
//             if (d.modes[0] > 0) null else src_frame,
//             if (d.modes[1] > 0) null else src_frame,
//             if (d.modes[2] > 0) null else src_frame,
//         };
//         const planes = [_]c_int{ 0, 1, 2 };
//
//         const dst = vsapi.?.newVideoFrame2.?(&d.vi.format, d.vi.width, d.vi.height, @ptrCast(&plane_src), @ptrCast(&planes), src_frame, core);
//
//         var plane: c_int = 0;
//         while (plane < d.vi.format.numPlanes) : (plane += 1) {
//             // Skip planes we aren't supposed to process
//             if (d.modes[@intCast(plane)] == 0) {
//                 continue;
//             }
//
//             const srcp: [*]const u8 = vsapi.?.getReadPtr.?(src_frame, plane);
//             const dstp: [*]u8 = vsapi.?.getWritePtr.?(dst, plane);
//             const width: usize = @intCast(vsapi.?.getFrameWidth.?(dst, plane));
//             const height: usize = @intCast(vsapi.?.getFrameHeight.?(dst, plane));
//
//             // Yes, there's a bunch of switches here, but it is for optimization purposes
//             // so that Zig can generate optimized RG functions for each type and mode and pick them at runtime.
//             switch (d.vi.format.bytesPerSample) {
//                 1 => {
//                     // 8 bit content
//                     switch (d.modes[@intCast(plane)]) {
//                         1 => RemoveGrain(u8, 1).process_plane_scalar(srcp, dstp, width, height),
//                         2 => RemoveGrain(u8, 2).process_plane_scalar(srcp, dstp, width, height),
//                         3 => RemoveGrain(u8, 3).process_plane_scalar(srcp, dstp, width, height),
//                         4 => RemoveGrain(u8, 4).process_plane_scalar(srcp, dstp, width, height),
//                         else => unreachable,
//                     }
//                 },
//                 // 2 => {
//                 //     // 9-16 bit content
//                 //     if (d.vi.format.sampleType == vs.SampleType.Integer) {
//                 //         switch (d.modes[@intCast(plane)]) {
//                 //             1 => RemoveGrain(u16, 1).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
//                 //             2 => RemoveGrain(u16, 2).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
//                 //             3 => RemoveGrain(u16, 3).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
//                 //             4 => RemoveGrain(u16, 4).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
//                 //             else => unreachable,
//                 //         }
//                 //     } else {
//                 //         // Processing f16 as f16 is dog slow, in both scalar and vector.
//                 //         // Likely faster if I process it in f32...
//                 //         switch (d.modes[@intCast(plane)]) {
//                 //             1 => RemoveGrain(f16, 1).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
//                 //             2 => RemoveGrain(f16, 2).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
//                 //             3 => RemoveGrain(f16, 3).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
//                 //             4 => RemoveGrain(f16, 4).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
//                 //             else => unreachable,
//                 //         }
//                 //     }
//                 // },
//                 // 4 => {
//                 //     // 32 bit float content
//                 //     switch (d.modes[@intCast(plane)]) {
//                 //         1 => RemoveGrain(f32, 1).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
//                 //         2 => RemoveGrain(f32, 2).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
//                 //         3 => RemoveGrain(f32, 3).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
//                 //         4 => RemoveGrain(f32, 4).process_plane_scalar(@ptrCast(@alignCast(srcp)), @ptrCast(@alignCast(dstp)), width, height),
//                 //         else => unreachable,
//                 //     }
//                 // },
//                 else => unreachable,
//             }
//         }
//
//         return dst;
//     }
//
//     return null;
// }

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

    // TODO: It looks like I have a potenial way of generating generic GetFrame functions!
    // const getFrame = switch (d.vi.format.bytesPerSample) {
    //     1 => &RemoveGrain(u8, 1).removeGrainGetFrame,
    //     2 => &RemoveGrain(u8, 1).removeGrainGetFrame,
    //     4 => &RemoveGrain(u8, 1).removeGrainGetFrame,
    //     else => unreachable,
    // };

    // vsapi.?.createVideoFilter.?(out, "RemoveGrain", d.vi, removeGrainGetFrame, removeGrainFree, fm.Parallel, &deps, deps.len, data, core);
    vsapi.?.createVideoFilter.?(out, "RemoveGrain", d.vi, RemoveGrain(u8, 1).removeGrainGetFrame, removeGrainFree, fm.Parallel, &deps, deps.len, data, core);
    // vsapi.?.createVideoFilter.?(out, "RemoveGrain", d.vi, getFrame, removeGrainFree, fm.Parallel, &deps, deps.len, data, core);
}
