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
fn RemoveGrain(comptime T: type) type {
    return struct {
        /// Signed Arithmetic Type - used in signed arithmetic to safely hold
        /// the values (particularly integers) without overflowing when doing
        /// signed arithmetic.
        const SAT = switch (T) {
            u8 => i16,
            u16 => i32,
            // RGSF uses double values for its computations,
            // while Avisynth uses single precision float for its computations.
            // I'm using single (and half) precision just like Avisynth since
            // double is unnecessary in most cases and twice as slow than single precision.
            // And I mean literally unnecessary - RGSF uses double on operations that are completely
            // safe for f32 calculations without any loss in precision, so it's *unnecessarily* slow.
            f16 => f16, //TODO: This might be more performant as f32 on some systems.
            f32 => f32,
            else => unreachable,
        };

        /// Unsigned Arithmetic Type - used in unsigned arithmetic to safely
        /// hold values (particularly integers) without overflowing when doing
        /// unsigned arithmetic.
        const UAT = switch (T) {
            u8 => u16,
            u16 => u32,
            // See note on floating point precision above.
            f16 => f16, //TODO: This might be more performant as f32 on some systems.
            f32 => f32,
            else => unreachable,
        };

        /// Every pixel is clamped to the lowest and highest values in the pixel's
        /// 3x3 neighborhood, center pixel not included.
        fn rgMode1(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            return @max(@min(a1, a2, a3, a4, a5, a6, a7, a8), @min(c, @max(a1, a2, a3, a4, a5, a6, a7, a8)));
        }

        /// Same as mode 1, except the second-lowest and second-highest values are used.
        fn rgMode2(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) @TypeOf(c) {
            var a = [_]T{ c, a1, a2, a3, a4, a5, a6, a7, a8 };
            // "normal" implementation, but stupid slow due to the sorting algorithm.
            // std.mem.sortUnstable(T, &a, {}, comptime std.sort.asc(T));
            // return std.math.clamp(c, a[2 - 1], a[7 - 1]);

            // min-max sorting algorithm.

            // Sort pixel pairs 1 pixel away
            cmn.compareSwap(T, &a[1], &a[2]);
            cmn.compareSwap(T, &a[3], &a[4]);
            cmn.compareSwap(T, &a[5], &a[6]);
            cmn.compareSwap(T, &a[7], &a[8]);

            // Sort pixel pairs 2 pixels away
            cmn.compareSwap(T, &a[1], &a[3]);
            cmn.compareSwap(T, &a[2], &a[4]);
            cmn.compareSwap(T, &a[5], &a[7]);
            cmn.compareSwap(T, &a[6], &a[8]);

            // Sort pivots
            cmn.compareSwap(T, &a[2], &a[3]);
            cmn.compareSwap(T, &a[6], &a[7]);

            // Sort pixels pairs 4 pixels away
            a[5] = @max(a[1], a[5]); // compareSwap(a[1], a[5]);
            cmn.compareSwap(T, &a[2], &a[6]);
            cmn.compareSwap(T, &a[3], &a[7]);
            a[4] = @min(a[4], a[8]); // compareSwap(a[4], a[8]);

            a[3] = @min(a[3], a[5]); // compareSwap(a[3], a[5]);
            a[6] = @max(a[4], a[6]); // compareSwap(a[4], a[6]);

            a[2] = @min(a[2], a[3]); // compareSwap(a[2], a[3]);
            a[7] = @max(a[6], a[7]); // compareSwap(a[6], a[7]);

            return std.math.clamp(c, a[2], a[7]);
        }

        /// Same as mode 1, except the third-lowest and third-highest values are used.
        fn rgMode3(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            var a = [_]T{ c, a1, a2, a3, a4, a5, a6, a7, a8 };
            // "normal" implementation, but stupid slow due to the sorting algorithm.
            // std.mem.sortUnstable(T, &a, {}, comptime std.sort.asc(T));
            // return std.math.clamp(c, a[3 - 1], a[6 - 1]);

            // min-max sorting algorithm.

            // Sort pixel pairs 1 pixel away
            cmn.compareSwap(T, &a[1], &a[2]);
            cmn.compareSwap(T, &a[3], &a[4]);
            cmn.compareSwap(T, &a[5], &a[6]);
            cmn.compareSwap(T, &a[7], &a[8]);

            // Sort pixel pairs 2 pixels away
            cmn.compareSwap(T, &a[1], &a[3]);
            cmn.compareSwap(T, &a[2], &a[4]);
            cmn.compareSwap(T, &a[5], &a[7]);
            cmn.compareSwap(T, &a[6], &a[8]);

            // Sort pivots
            cmn.compareSwap(T, &a[2], &a[3]);
            cmn.compareSwap(T, &a[6], &a[7]);

            // Sort pixels pairs 4 pixels away
            a[5] = @max(a[1], a[5]); // compareSwap(a[1], a[5]);
            cmn.compareSwap(T, &a[2], &a[6]);
            cmn.compareSwap(T, &a[3], &a[7]);
            a[4] = @min(a[4], a[8]); // compareSwap(a[4], a[8]);

            a[3] = @min(a[3], a[5]); // compareSwap(a[3], a[5]);
            a[6] = @max(a[4], a[6]); // compareSwap(a[4], a[6]);

            //everything above this line is identical to Mode 2.

            a[3] = @max(a[2], a[3]); // compareSwap(a[2], a[3]);
            a[6] = @min(a[6], a[7]); // compareSwap(a[6], a[7]);

            return std.math.clamp(c, a[3], a[6]);
        }

        /// Same as mode 1, except the fourth-lowest and fourth-highest values are used.
        /// This is identical to std.Median.
        fn rgMode4(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            var a = [_]T{ c, a1, a2, a3, a4, a5, a6, a7, a8 };
            // "normal" implementation, but stupid slow due to the sorting algorithm.
            // std.mem.sortUnstable(T, &a, {}, comptime std.sort.asc(T));
            // return std.math.clamp(c, a[3 - 1], a[6 - 1]);

            // min-max sorting algorithm.

            // Sort pixel pairs 1 pixel away
            cmn.compareSwap(T, &a[1], &a[2]);
            cmn.compareSwap(T, &a[3], &a[4]);
            cmn.compareSwap(T, &a[5], &a[6]);
            cmn.compareSwap(T, &a[7], &a[8]);

            // Sort pixel pairs 2 pixels away
            cmn.compareSwap(T, &a[1], &a[3]);
            cmn.compareSwap(T, &a[2], &a[4]);
            cmn.compareSwap(T, &a[5], &a[7]);
            cmn.compareSwap(T, &a[6], &a[8]);

            // compare pivots
            cmn.compareSwap(T, &a[2], &a[3]);
            cmn.compareSwap(T, &a[6], &a[7]);

            // Everything above this is identical to mode 1.

            // Sort pixels pairs 4 pixels away
            a[5] = @max(a[1], a[5]); // compareSwap(a[1], a[5]);
            a[6] = @max(a[2], a[6]); // compareSwap(a[2], a[6]);
            a[3] = @min(a[3], a[7]); // compareSwap(a[3], a[7]);
            a[4] = @min(a[4], a[8]); // compareSwap(a[4], a[8]);

            a[5] = @max(a[3], a[5]); // compareSwap(a[3], a[5]);
            a[4] = @min(a[4], a[6]); // compareSwap(a[4], a[6]);

            cmn.compareSwap(T, &a[4], &a[5]);

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

        fn sortPixels(a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) struct { max1: T, min1: T, max2: T, min2: T, max3: T, min3: T, max4: T, min4: T } {
            return .{
                .max1 = @max(a1, a8),
                .min1 = @min(a1, a8),
                .max2 = @max(a2, a7),
                .min2 = @min(a2, a7),
                .max3 = @max(a3, a6),
                .min3 = @min(a3, a6),
                .max4 = @max(a4, a5),
                .min4 = @min(a4, a5),
            };
        }

        test sortPixels {
            const sorted = sortPixels(2, 4, 6, 8, 7, 5, 3, 1);

            try std.testing.expectEqual(2, sorted.max1);
            try std.testing.expectEqual(1, sorted.min1);
            try std.testing.expectEqual(4, sorted.max2);
            try std.testing.expectEqual(3, sorted.min2);
            try std.testing.expectEqual(6, sorted.max3);
            try std.testing.expectEqual(5, sorted.min3);
            try std.testing.expectEqual(8, sorted.max4);
            try std.testing.expectEqual(7, sorted.min4);
        }

        /// Line-sensitive clipping giving the minimal change.
        ///
        /// Specifically, it clips the center pixel with four pairs
        /// of opposing pixels respectively, and the pair that results
        /// in the smallest change to the center pixel is used.
        fn rgMode5(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            const sorted = sortPixels(a1, a2, a3, a4, a5, a6, a7, a8);

            // TODO: RGSF uses double (f64) for it's math.
            // Consider whether this is necessary or not.
            // https://github.com/IFeelBloated/RGSF/blob/master/RemoveGrain.cpp#L97-L100

            // Casting u8 to i16 instead of i32 is substantially faster on my laptop.
            // 613 fps vs 470 fps
            const cT = @as(SAT, c);

            const c1 = @abs(cT - std.math.clamp(c, sorted.min1, sorted.max1));
            const c2 = @abs(cT - std.math.clamp(c, sorted.min2, sorted.max2));
            const c3 = @abs(cT - std.math.clamp(c, sorted.min3, sorted.max3));
            const c4 = @abs(cT - std.math.clamp(c, sorted.min4, sorted.max4));

            const mindiff = @min(c1, c2, c3, c4);

            // This order matters to match RGVS output.
            if (mindiff == c4) {
                return std.math.clamp(c, sorted.min4, sorted.max4);
            } else if (mindiff == c2) {
                return std.math.clamp(c, sorted.min2, sorted.max2);
            } else if (mindiff == c3) {
                return std.math.clamp(c, sorted.min3, sorted.max3);
            }
            return std.math.clamp(c, sorted.min1, sorted.max1);
        }

        test "RG Mode 5" {
            // a1 and a8 clipping.
            try std.testing.expectEqual(2, rgMode5(1, 2, 6, 6, 6, 7, 7, 7, 3));
            try std.testing.expectEqual(3, rgMode5(4, 2, 6, 6, 6, 7, 7, 7, 3));

            // a2 and a7 clipping.
            try std.testing.expectEqual(2, rgMode5(1, 6, 2, 6, 6, 7, 7, 3, 7));
            try std.testing.expectEqual(3, rgMode5(4, 6, 2, 6, 6, 7, 7, 3, 7));

            // a3 and a6 clipping.
            try std.testing.expectEqual(2, rgMode5(1, 6, 6, 2, 6, 7, 3, 7, 7));
            try std.testing.expectEqual(3, rgMode5(4, 6, 6, 2, 6, 7, 3, 7, 7));

            // a4 and a5 clipping.
            try std.testing.expectEqual(2, rgMode5(1, 6, 6, 6, 2, 3, 7, 7, 7));
            try std.testing.expectEqual(3, rgMode5(4, 6, 6, 6, 2, 3, 7, 7, 7));
        }

        /// Line-sensitive clipping, intermediate.
        ///
        /// It considers the range of the clipping operation
        /// (the difference between the two opposing pixels)
        /// as well as the change applied to the center pixel.
        ///
        /// The change applied to the center pixel is prioritized
        /// (ratio 2:1) in this mode.
        fn rgMode6(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T, chroma: bool) T {
            const sorted = sortPixels(a1, a2, a3, a4, a5, a6, a7, a8);

            const d1 = sorted.max1 - sorted.min1;
            const d2 = sorted.max2 - sorted.min2;
            const d3 = sorted.max3 - sorted.min3;
            const d4 = sorted.max4 - sorted.min4;

            const clamp1 = std.math.clamp(c, sorted.min1, sorted.max1);
            const clamp2 = std.math.clamp(c, sorted.min2, sorted.max2);
            const clamp3 = std.math.clamp(c, sorted.min3, sorted.max3);
            const clamp4 = std.math.clamp(c, sorted.min4, sorted.max4);

            // Max / min Zig comptime + runtime shenanigans.
            // TODO: Pretty sure there's a bug here.
            // This maximum should likely be the maximum of the video bit depth,
            // not the processing bit depth.
            // Avisynth uses a max of the video bit depth, but RGVS uses a max of 0xFFFF.
            // Maybe it doesn't matter...
            // In theory it would only be an issue if every pixel around this
            // pixel was white and this one was black
            const maxChroma = cmn.getTypeMaximum(T, true);
            const maxNoChroma = cmn.getTypeMaximum(T, false);

            const maximum = if (chroma) maxChroma else maxNoChroma;

            // TODO: RGSF uses double for it's math here. I'm not sure how much it matters
            // but it is a small difference and technically our plugins produce different output without casting to f64;
            const cT = @as(SAT, c);

            // The following produces output identical to RGSF
            // const SignedType = if (T == u8) i16 else if (T == u16) i32 else if (T == f16) f32 else f64;
            // const cT = if (cmn.isInt(T)) @as(SignedType, @intCast(c)) else @as(SignedType, @floatCast(c));

            const c1 = @min((@abs(cT - clamp1) * 2) + d1, maximum);
            const c2 = @min((@abs(cT - clamp2) * 2) + d2, maximum);
            const c3 = @min((@abs(cT - clamp3) * 2) + d3, maximum);
            const c4 = @min((@abs(cT - clamp4) * 2) + d4, maximum);

            const mindiff = @min(c1, c2, c3, c4);

            // This order matters in order to match the exact
            // same output of RGVS
            if (mindiff == c4) {
                return clamp4;
            } else if (mindiff == c2) {
                return clamp2;
            } else if (mindiff == c3) {
                return clamp3;
            }
            return clamp1;
        }

        // // TODO: Add tests for RG mode 6
        // test "RG Mode 6" {
        // }

        /// Same as mode 6, except the ratio is 1:1 in this mode.
        fn rgMode7(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            const sorted = sortPixels(a1, a2, a3, a4, a5, a6, a7, a8);

            const d1 = sorted.max1 - sorted.min1;
            const d2 = sorted.max2 - sorted.min2;
            const d3 = sorted.max3 - sorted.min3;
            const d4 = sorted.max4 - sorted.min4;

            const clamp1 = std.math.clamp(c, sorted.min1, sorted.max1);
            const clamp2 = std.math.clamp(c, sorted.min2, sorted.max2);
            const clamp3 = std.math.clamp(c, sorted.min3, sorted.max3);
            const clamp4 = std.math.clamp(c, sorted.min4, sorted.max4);

            const cT = @as(SAT, c);

            const c1 = @abs(cT - clamp1) + d1;
            const c2 = @abs(cT - clamp2) + d2;
            const c3 = @abs(cT - clamp3) + d3;
            const c4 = @abs(cT - clamp4) + d4;

            const mindiff = @min(c1, c2, c3, c4);

            // This order matters in order to match the exact
            // same output of RGVS
            if (mindiff == c4) {
                return clamp4;
            } else if (mindiff == c2) {
                return clamp2;
            } else if (mindiff == c3) {
                return clamp3;
            }
            return clamp1;
        }

        /// Same as mode 6, except the difference between the two opposing
        /// pixels is prioritized in this mode, again with a 2:1 ratio.
        fn rgMode8(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T, chroma: bool) T {
            const sorted = sortPixels(a1, a2, a3, a4, a5, a6, a7, a8);

            const d1: UAT = sorted.max1 - sorted.min1;
            const d2: UAT = sorted.max2 - sorted.min2;
            const d3: UAT = sorted.max3 - sorted.min3;
            const d4: UAT = sorted.max4 - sorted.min4;

            const clamp1 = std.math.clamp(c, sorted.min1, sorted.max1);
            const clamp2 = std.math.clamp(c, sorted.min2, sorted.max2);
            const clamp3 = std.math.clamp(c, sorted.min3, sorted.max3);
            const clamp4 = std.math.clamp(c, sorted.min4, sorted.max4);

            // Max / min Zig comptime + runtime shenanigans.
            const maxChroma = cmn.getTypeMaximum(T, true);
            const maxNoChroma = cmn.getTypeMaximum(T, false);
            const minChroma = cmn.getTypeMinimum(T, true);
            const minNoChroma = cmn.getTypeMinimum(T, false);

            const maximum = if (chroma) maxChroma else maxNoChroma;
            const minimum = if (chroma) minChroma else minNoChroma;

            // TODO: RGSF uses double for it's math here. I'm not sure how much it matters
            // but it is a small difference and technically our plugins produce different output without casting to f64;
            const cT = @as(SAT, c);

            const c1 = std.math.clamp(@abs(cT - clamp1) + (d1 * 2), minimum, maximum);
            const c2 = std.math.clamp(@abs(cT - clamp2) + (d2 * 2), minimum, maximum);
            const c3 = std.math.clamp(@abs(cT - clamp3) + (d3 * 2), minimum, maximum);
            const c4 = std.math.clamp(@abs(cT - clamp4) + (d4 * 2), minimum, maximum);

            const mindiff = @min(c1, c2, c3, c4);

            // This order matters in order to match the exact
            // same output of RGVS
            if (mindiff == c4) {
                return clamp4;
            } else if (mindiff == c2) {
                return clamp2;
            } else if (mindiff == c3) {
                return clamp3;
            }
            return clamp1;
        }

        /// Line-sensitive clipping on a line where the neighbours pixels are the closest.
        /// Only the difference between the two opposing pixels is considered in this mode,
        /// and the pair with the smallest difference is used for cliping the center pixel.
        /// This can be useful to fix interrupted lines, as long as the length of the gap never exceeds one pixel.
        fn rgMode9(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            const sorted = sortPixels(a1, a2, a3, a4, a5, a6, a7, a8);

            const d1 = sorted.max1 - sorted.min1;
            const d2 = sorted.max2 - sorted.min2;
            const d3 = sorted.max3 - sorted.min3;
            const d4 = sorted.max4 - sorted.min4;

            const mindiff = @min(d1, d2, d3, d4);

            // This order matters in order to match the exact
            // same output of RGVS
            if (mindiff == d4) {
                return std.math.clamp(c, sorted.min4, sorted.max4);
            } else if (mindiff == d2) {
                return std.math.clamp(c, sorted.min2, sorted.max2);
            } else if (mindiff == d3) {
                return std.math.clamp(c, sorted.min3, sorted.max3);
            }
            return std.math.clamp(c, sorted.min1, sorted.max1);
        }

        test "RG Mode 9" {
            // TODO: Add testing based on the difference directions (d4, d2, d3, d1) to ensure that the proper order is followed.

            // a1 and a8 clipping.
            try std.testing.expectEqual(2, rgMode9(1, 2, 0, 0, 0, 100, 100, 100, 3));
            try std.testing.expectEqual(3, rgMode9(4, 2, 0, 0, 0, 100, 100, 100, 3));

            // a2 and a7 clipping.
            try std.testing.expectEqual(2, rgMode9(1, 0, 2, 0, 0, 100, 100, 3, 100));
            try std.testing.expectEqual(3, rgMode9(4, 0, 2, 0, 0, 100, 100, 3, 100));

            // a3 and a6 clipping.
            try std.testing.expectEqual(2, rgMode9(1, 0, 0, 2, 0, 100, 3, 100, 100));
            try std.testing.expectEqual(3, rgMode9(4, 0, 0, 2, 0, 100, 3, 100, 100));

            // a4 and a5 clipping.
            try std.testing.expectEqual(2, rgMode9(1, 0, 0, 0, 2, 3, 100, 100, 100));
            try std.testing.expectEqual(3, rgMode9(4, 0, 0, 0, 2, 3, 100, 100, 100));
        }

        /// Replaces the center pixel with the closest neighbour. "Very poor denoise sharpener"
        fn rgMode10(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            const cT: SAT = c;

            const d1 = @abs(cT - a1);
            const d2 = @abs(cT - a2);
            const d3 = @abs(cT - a3);
            const d4 = @abs(cT - a4);
            const d5 = @abs(cT - a5);
            const d6 = @abs(cT - a6);
            const d7 = @abs(cT - a7);
            const d8 = @abs(cT - a8);

            const mindiff = @min(d1, d2, d3, d4, d5, d6, d7, d8);

            // This order matters in order to match the exact
            // same output of RGVS

            return if (mindiff == d7)
                a7
            else if (mindiff == d8)
                a8
            else if (mindiff == d6)
                a6
            else if (mindiff == d2)
                a2
            else if (mindiff == d3)
                a3
            else if (mindiff == d1)
                a1
            else if (mindiff == d5)
                a5
            else
                a4;
        }

        test "RG Mode 10" {
            // TODO: Add testing to ensure that order is respected (d7, d8, d6, ...)
            try std.testing.expectEqual(2, rgMode10(1, 2, 3, 4, 5, 6, 7, 8, 9));
            try std.testing.expectEqual(2, rgMode10(1, 9, 2, 3, 4, 5, 6, 7, 8));
            try std.testing.expectEqual(2, rgMode10(1, 8, 9, 2, 3, 4, 5, 6, 7));
            try std.testing.expectEqual(2, rgMode10(1, 7, 8, 9, 2, 3, 4, 5, 6));
            try std.testing.expectEqual(2, rgMode10(1, 6, 7, 8, 9, 2, 3, 4, 5));
            try std.testing.expectEqual(2, rgMode10(1, 5, 6, 7, 8, 9, 2, 3, 4));
            try std.testing.expectEqual(2, rgMode10(1, 4, 5, 6, 7, 8, 9, 2, 3));
            try std.testing.expectEqual(2, rgMode10(1, 3, 4, 5, 6, 7, 8, 9, 2));
        }

        /// Every pixel is replaced with a weighted arithmetic mean of its 3x3
        /// neighborhood.
        /// The center pixel has a weight of 4, the pixels above, below, to the
        /// left, and to the right of the center pixel each have a weight of 2,
        /// and the corner pixels each have a weight of 1.
        ///
        /// Identical to Convolution(matrix=[1, 2, 1, 2, 4, 2, 1, 2, 1])
        fn rgMode1112(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            const sum = 4 * @as(UAT, c) + 2 * (@as(UAT, a2) + a4 + a5 + a7) + a1 + a3 + a6 + a8;
            return if (cmn.isFloat(T))
                sum / 16
            else
                @intCast((sum + 8) / 16);
        }

        test "RG Mode 11-12" {
            if (cmn.isInt(T)) {
                try std.testing.expectEqual(5, rgMode1112(10, 1, 5, 1, 5, 5, 1, 5, 1));
            } else {
                try std.testing.expectEqual(5.25, rgMode1112(10, 1, 5, 1, 5, 5, 1, 5, 1));
            }
        }

        /// RG 13 - Bob mode, interpolates top field from the line where the neighbours pixels are the closest.
        /// RG 14 - Bob mode, interpolates bottom field from the line where the neighbours pixels are the closest.
        fn rgMode1314(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            // TODO: simply remove the function parameters for this function.
            _ = c;
            _ = a4;
            _ = a5;

            const d1 = @abs(@as(SAT, a1) - a8);
            const d2 = @abs(@as(SAT, a2) - a7);
            const d3 = @abs(@as(SAT, a3) - a6);

            const mindiff = @min(d1, d2, d3);

            if (mindiff == d2) {
                return if (cmn.isFloat(T))
                    (@as(UAT, a2) + a7) / 2
                else
                    @intCast((@as(UAT, a2) + a7 + 1) / 2);
            } else if (mindiff == d3) {
                return if (cmn.isFloat(T))
                    (@as(UAT, a3) + a6) / 2
                else
                    @intCast((@as(UAT, a3) + a6 + 1) / 2);
            }
            return if (cmn.isFloat(T))
                (@as(UAT, a1) + a8) / 2
            else
                @intCast((@as(UAT, a1) + a8 + 1) / 2);
        }

        test "RG Mode 13-14" {
            try std.testing.expectEqual(2, rgMode1314(0, 1, 1, 1, 0, 0, 100, 100, 3));
            try std.testing.expectEqual(2, rgMode1314(0, 1, 1, 1, 0, 0, 100, 3, 100));
            try std.testing.expectEqual(2, rgMode1314(0, 1, 1, 1, 0, 0, 3, 100, 100));
        }

        /// RG15 - Bob mode, interpolates top field. Same as mode 13 but with a more complicated interpolation formula.
        /// RG16 - Bob mode, interpolates bottom field. Same as mode 14 but with a more complicated interpolation formula.
        fn rgMode1516(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            // TODO: simply remove the function parameters for this function.
            _ = c;
            _ = a4;
            _ = a5;

            const d1 = @abs(@as(SAT, a1) - a8);
            const d2 = @abs(@as(SAT, a2) - a7);
            const d3 = @abs(@as(SAT, a3) - a6);

            const mindiff = @min(d1, d2, d3);

            const average = if (cmn.isFloat(T))
                (2 * (@as(UAT, a2) + a7) + a1 + a3 + a6 + a8) / 8
            else
                (2 * (@as(UAT, a2) + a7) + a1 + a3 + a6 + a8 + 4) / 8;

            if (mindiff == d2) {
                return cmn.lossyCast(T, std.math.clamp(average, @min(a2, a7), @max(a2, a7)));
            } else if (mindiff == d3) {
                return cmn.lossyCast(T, std.math.clamp(average, @min(a3, a6), @max(a3, a6)));
            }
            return cmn.lossyCast(T, std.math.clamp(average, @min(a1, a8), @max(a1, a8)));
        }

        test "RG Mode 15-16" {
            try std.testing.expectEqual(3, rgMode1516(0, 1, 1, 1, 0, 0, 100, 100, 3));
            try std.testing.expectEqual(3, rgMode1516(0, 1, 1, 1, 0, 0, 100, 3, 100));
            try std.testing.expectEqual(3, rgMode1516(0, 1, 1, 1, 0, 0, 3, 100, 100));
        }

        /// Clips the pixel with the minimum and maximum of respectively the maximum and minimum of each pair of opposite neighbour pixels.
        fn rgMode17(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            const sorted = sortPixels(a1, a2, a3, a4, a5, a6, a7, a8);
            const l = @max(sorted.min1, sorted.min2, sorted.min3, sorted.min4);
            const u = @min(sorted.max1, sorted.max2, sorted.max3, sorted.max4);

            return std.math.clamp(c, @min(l, u), @max(l, u));
        }

        test "RG Mode 17" {
            // Clip to the lowest maximum
            try std.testing.expectEqual(5, rgMode17(10, 1, 1, 1, 1, 5, 6, 7, 8));

            // Clip to the highest minimum
            try std.testing.expectEqual(4, rgMode17(0, 1, 2, 3, 4, 5, 5, 5, 5));
        }

        /// Line-sensitive clipping using opposite neighbours whose greatest distance from the current pixel is minimal.
        fn rgMode18(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            const cT = @as(SAT, c);
            const d1 = @max(@abs(cT - a1), @abs(cT - a8));
            const d2 = @max(@abs(cT - a2), @abs(cT - a7));
            const d3 = @max(@abs(cT - a3), @abs(cT - a6));
            const d4 = @max(@abs(cT - a4), @abs(cT - a5));

            const mindiff = @min(d1, d2, d3, d4);

            return if (mindiff == d4)
                std.math.clamp(c, @min(a4, a5), @max(a4, a5))
            else if (mindiff == d2)
                std.math.clamp(c, @min(a2, a7), @max(a2, a7))
            else if (mindiff == d3)
                std.math.clamp(c, @min(a3, a6), @max(a3, a6))
            else
                std.math.clamp(c, @min(a1, a8), @max(a1, a8));
        }

        test "RG Mode 18" {
            // a1 and a8 clipping.
            try std.testing.expectEqual(2, rgMode18(1, 2, 100, 100, 100, 100, 100, 100, 3));
            try std.testing.expectEqual(3, rgMode18(4, 2, 100, 100, 100, 100, 100, 100, 3));

            // a2 and a7 clipping.
            try std.testing.expectEqual(2, rgMode18(1, 100, 2, 100, 100, 100, 100, 3, 100));
            try std.testing.expectEqual(3, rgMode18(4, 100, 2, 100, 100, 100, 100, 3, 100));

            // a3 and a6 clipping
            try std.testing.expectEqual(2, rgMode18(1, 100, 100, 2, 100, 100, 3, 100, 100));
            try std.testing.expectEqual(3, rgMode18(4, 100, 100, 2, 100, 100, 3, 100, 100));

            // a4 and a5 clipping
            try std.testing.expectEqual(2, rgMode18(1, 100, 100, 100, 2, 3, 100, 100, 100));
            try std.testing.expectEqual(3, rgMode18(4, 100, 100, 100, 2, 3, 100, 100, 100));
        }

        /// Every pixel is replaced with the arithmetic mean of its 3x3 neighborhood,
        /// center pixel not included. In other words, the 8 neighbors are summed up
        /// and the sum is divided by 8.
        ///
        /// Identical to Convolution(matrix=[1, 1, 1, 1, 0, 1, 1, 1, 1])
        fn rgMode19(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            // TODO: remove c arg.
            _ = c;
            const sum = @as(UAT, a1) + a2 + a3 + a4 + a5 + a6 + a7 + a8;

            return if (cmn.isFloat(T))
                sum / 8
            else
                @intCast((sum + 4) / 8);
        }

        test "RG Mode 19" {
            if (cmn.isFloat(T)) {
                try std.testing.expectEqual(4.5, rgMode19(0, 1, 2, 3, 4, 5, 6, 7, 8));
            } else {
                try std.testing.expectEqual(5, rgMode19(0, 1, 2, 3, 4, 5, 6, 7, 8));
            }
        }

        /// Every pixel is replaced with the arithmetic mean of its 3x3 neighborhood.
        /// In other words, all 9 pixels are summed up and the sum is divided by 9.
        ///
        /// Identical to Convolution(matrix=[1, 1, 1, 1, 1, 1, 1, 1, 1])
        fn rgMode20(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            const sum = @as(UAT, a1) + a2 + a3 + c + a4 + a5 + a6 + a7 + a8;

            return if (cmn.isFloat(T))
                sum / 9
            else
                @intCast((sum + 4) / 9);
        }

        test "RG Mode 20" {
            try std.testing.expectEqual(5, rgMode20(9, 1, 2, 3, 4, 5, 6, 7, 8));
        }

        /// The center pixel is clipped to the smallest and the biggest average of the four surrounding pairs.
        fn rgMode21(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            const l1l = (@as(UAT, a1) + a8) / 2;
            const l2l = (@as(UAT, a2) + a7) / 2;
            const l3l = (@as(UAT, a3) + a6) / 2;
            const l4l = (@as(UAT, a4) + a5) / 2;

            // Unused for integer
            const l1h = (@as(UAT, a1) + a8 + 1) / 2;
            const l2h = (@as(UAT, a2) + a7 + 1) / 2;
            const l3h = (@as(UAT, a3) + a6 + 1) / 2;
            const l4h = (@as(UAT, a4) + a5 + 1) / 2;

            const min = @min(l1l, l2l, l3l, l4l);
            const max = if (cmn.isInt(T))
                @max(l1h, l2h, l3h, l4h)
            else
                @max(l1l, l2l, l3l, l4l);

            return cmn.lossyCast(T, std.math.clamp(c, min, max));
        }

        /// Same as mode 21 but simpler and faster. (rounding handled differently)
        /// Identical for floating point.
        fn rgMode22(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            if (cmn.isFloat(T)) {
                return rgMode21(c, a1, a2, a3, a4, a5, a6, a7, a8);
            }

            const l1 = (@as(UAT, a1) + a8 + 1) / 2;
            const l2 = (@as(UAT, a2) + a7 + 1) / 2;
            const l3 = (@as(UAT, a3) + a6 + 1) / 2;
            const l4 = (@as(UAT, a4) + a5 + 1) / 2;

            const min = @min(l1, l2, l3, l4);
            const max = @max(l1, l2, l3, l4);

            return cmn.lossyCast(T, std.math.clamp(c, min, max));
        }

        test "RG Mode 21-22" {
            try std.testing.expectEqual(1, rgMode21(0, 1, 2, 3, 4, 4, 3, 2, 1));
            try std.testing.expectEqual(4, rgMode21(5, 1, 2, 3, 4, 4, 3, 2, 1));

            try std.testing.expectEqual(1, rgMode22(0, 1, 2, 3, 4, 4, 3, 2, 1));
            try std.testing.expectEqual(4, rgMode22(5, 1, 2, 3, 4, 4, 3, 2, 1));
        }

        /// Small edge and halo removal, but reportedly useless.
        fn rgMode23(c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            const sorted = sortPixels(a1, a2, a3, a4, a5, a6, a7, a8);

            const linediff1 = sorted.max1 - sorted.min1;
            const linediff2 = sorted.max2 - sorted.min2;
            const linediff3 = sorted.max3 - sorted.min3;
            const linediff4 = sorted.max4 - sorted.min4;

            const cT = @as(SAT, c);

            const h1 = @min(cT - sorted.max1, linediff1);
            const h2 = @min(cT - sorted.max2, linediff2);
            const h3 = @min(cT - sorted.max3, linediff3);
            const h4 = @min(cT - sorted.max4, linediff4);

            // Note: For YUV chroma planes, Avisynth uses 0 here, and RGSF uses -0.5.
            // In my testing, 0 appears visually correct and to match integer output.
            // -0.5 seems to break the image, and is likely a bug in RGSF.
            //
            // Reference:
            // * https://github.com/pinterf/RgTools/blob/a9cff29cb228b8a6fb52148f334554f4c3823798/RgTools/rg_functions_c.h#L1296
            // * https://github.com/IFeelBloated/RGSF/blob/master/RemoveGrain.cpp#L475
            const h = @max(0, h1, h2, h3, h4);

            const l1 = @min(sorted.min1 - cT, linediff1);
            const l2 = @min(sorted.min2 - cT, linediff2);
            const l3 = @min(sorted.min3 - cT, linediff3);
            const l4 = @min(sorted.min4 - cT, linediff4);
            const l = @max(0, l1, l2, l3, l4);

            return cmn.lossyCast(T, c - h + l);
        }

        /// Based on the RG mode, we want to skip certain lines,
        /// like when processing interlaced fields (even or odd fields).
        fn shouldSkipLine(mode: comptime_int, line: usize) bool {
            if (mode == 13 or mode == 15) {
                // Even lines should be processed, so skip when line is an odd number.
                return (line & 1) != 0;
            } else if (mode == 14 or mode == 16) {
                // Odd lines should be processed, so skip when line is an even number.
                return (line & 1) == 0;
            }
            return false;
        }

        test shouldSkipLine {
            // Skip odd lines (process even lines) for mode 13 and 15
            try std.testing.expectEqual(false, shouldSkipLine(13, 2));
            try std.testing.expectEqual(false, shouldSkipLine(15, 2));
            try std.testing.expectEqual(true, shouldSkipLine(13, 3));
            try std.testing.expectEqual(true, shouldSkipLine(15, 3));

            // Skip even lines (process odd lines) for mode 14 and 16
            try std.testing.expectEqual(true, shouldSkipLine(14, 2));
            try std.testing.expectEqual(true, shouldSkipLine(16, 2));
            try std.testing.expectEqual(false, shouldSkipLine(14, 3));
            try std.testing.expectEqual(false, shouldSkipLine(16, 3));

            // Other modes should process all lines
            inline for (0..25) |mode| {
                if (mode == 13 or mode == 14 or mode == 15 or mode == 16) {
                    continue;
                }

                try std.testing.expectEqual(false, shouldSkipLine(mode, 2));
                try std.testing.expectEqual(false, shouldSkipLine(mode, 3));
            }
        }

        fn getFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
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

                for (0..@intCast(d.vi.format.numPlanes)) |plane| {
                    // Skip planes we aren't supposed to process
                    if (d.modes[plane] == 0) {
                        continue;
                    }

                    const srcp: [*]const T = @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frame, @intCast(plane))));
                    const dstp: [*]T = @ptrCast(@alignCast(vsapi.?.getWritePtr.?(dst, @intCast(plane))));
                    const width: usize = @intCast(vsapi.?.getFrameWidth.?(dst, @intCast(plane)));
                    const height: usize = @intCast(vsapi.?.getFrameHeight.?(dst, @intCast(plane)));
                    const chroma = d.vi.format.colorFamily == vs.ColorFamily.YUV and plane > 0;

                    switch (d.modes[plane]) {
                        1 => process_plane_scalar(1, srcp, dstp, width, height, chroma),
                        2 => process_plane_scalar(2, srcp, dstp, width, height, chroma),
                        3 => process_plane_scalar(3, srcp, dstp, width, height, chroma),
                        4 => process_plane_scalar(4, srcp, dstp, width, height, chroma),
                        5 => process_plane_scalar(5, srcp, dstp, width, height, chroma),
                        6 => process_plane_scalar(6, srcp, dstp, width, height, chroma),
                        7 => process_plane_scalar(7, srcp, dstp, width, height, chroma),
                        8 => process_plane_scalar(8, srcp, dstp, width, height, chroma),
                        9 => process_plane_scalar(9, srcp, dstp, width, height, chroma),
                        10 => process_plane_scalar(10, srcp, dstp, width, height, chroma),
                        11, 12 => process_plane_scalar(11, srcp, dstp, width, height, chroma),
                        13 => process_plane_scalar(13, srcp, dstp, width, height, chroma),
                        14 => process_plane_scalar(14, srcp, dstp, width, height, chroma),
                        15 => process_plane_scalar(15, srcp, dstp, width, height, chroma),
                        16 => process_plane_scalar(16, srcp, dstp, width, height, chroma),
                        17 => process_plane_scalar(17, srcp, dstp, width, height, chroma),
                        18 => process_plane_scalar(18, srcp, dstp, width, height, chroma),
                        19 => process_plane_scalar(19, srcp, dstp, width, height, chroma),
                        20 => process_plane_scalar(20, srcp, dstp, width, height, chroma),
                        21 => process_plane_scalar(21, srcp, dstp, width, height, chroma),
                        22 => process_plane_scalar(22, srcp, dstp, width, height, chroma),
                        23 => process_plane_scalar(23, srcp, dstp, width, height, chroma),
                        else => unreachable,
                    }
                }

                return dst;
            }

            return null;
        }

        pub fn process_plane_scalar(mode: comptime_int, srcp: [*]const T, dstp: [*]T, width: usize, height: usize, chroma: bool) void {
            // @setFloatMode(.Optimized);
            // Copy the first line.
            @memcpy(dstp, srcp[0..width]);

            for (1..height - 1) |h| {
                // Handle interlacing (top field/bottom field) modes
                if (shouldSkipLine(mode, h)) {
                    const currentLine = (h * width);
                    @memcpy(dstp[currentLine..], srcp[currentLine..(currentLine + width)]);
                    continue;
                }

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
                        5 => rgMode5(c, a1, a2, a3, a4, a5, a6, a7, a8),
                        6 => rgMode6(c, a1, a2, a3, a4, a5, a6, a7, a8, chroma),
                        7 => rgMode7(c, a1, a2, a3, a4, a5, a6, a7, a8),
                        8 => rgMode8(c, a1, a2, a3, a4, a5, a6, a7, a8, chroma),
                        9 => rgMode9(c, a1, a2, a3, a4, a5, a6, a7, a8),
                        10 => rgMode10(c, a1, a2, a3, a4, a5, a6, a7, a8),
                        11, 12 => rgMode1112(c, a1, a2, a3, a4, a5, a6, a7, a8),
                        13, 14 => rgMode1314(c, a1, a2, a3, a4, a5, a6, a7, a8),
                        15, 16 => rgMode1516(c, a1, a2, a3, a4, a5, a6, a7, a8),
                        17 => rgMode17(c, a1, a2, a3, a4, a5, a6, a7, a8),
                        18 => rgMode18(c, a1, a2, a3, a4, a5, a6, a7, a8),
                        19 => rgMode19(c, a1, a2, a3, a4, a5, a6, a7, a8),
                        20 => rgMode20(c, a1, a2, a3, a4, a5, a6, a7, a8),
                        21 => rgMode21(c, a1, a2, a3, a4, a5, a6, a7, a8),
                        22 => rgMode22(c, a1, a2, a3, a4, a5, a6, a7, a8),
                        23 => rgMode23(c, a1, a2, a3, a4, a5, a6, a7, a8),
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
    };
}

// fn process_plane_vec(comptime T: type, srcp: [*]const T, dstp: [*]T, width: usize, height: usize, mode: u5) void {
//     const vec_size = cmn.getVecSize(T);
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

    const getFrame = switch (d.vi.format.bytesPerSample) {
        1 => &RemoveGrain(u8).getFrame,
        2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &RemoveGrain(u16).getFrame else &RemoveGrain(f16).getFrame,
        4 => &RemoveGrain(f32).getFrame,
        else => unreachable,
    };

    vsapi.?.createVideoFilter.?(out, "RemoveGrain", d.vi, getFrame, removeGrainFree, fm.Parallel, &deps, deps.len, data, core);
}
