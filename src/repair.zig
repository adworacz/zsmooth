const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;

const types = @import("common/type.zig");
const math = @import("common/math.zig");
const vscmn = @import("common/vapoursynth.zig");
const sort = @import("common/sorting_networks.zig");
const gridcmn = @import("common/grid.zig");

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

const RepairData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    repair_node: ?*vs.Node,

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
fn Repair(comptime T: type) type {
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

        const Grid = gridcmn.Grid(T);

        // Clamp the source pixel to the min/max of the repair pixels.
        fn repairMode1(src: T, grid: Grid) T {
            const min = grid.minWithCenter();
            const max = grid.maxWithCenter();

            return math.clamp(src, min, max);
        }

        fn repairMode2(src: T, grid: Grid) T {
            const a = grid.sortWithCenter();

            return math.clamp(src, a[1], a[7]);
        }

        fn repairMode3(src: T, grid: Grid) T {
            const a = grid.sortWithCenter();

            return math.clamp(src, a[2], a[6]);
        }

        fn repairMode4(src: T, grid: Grid) T {
            const a = grid.sortWithCenter();

            return math.clamp(src, a[3], a[5]);
        }

        test "Repair Mode 1-4" {
            // In range
            try std.testing.expectEqual(5, repairMode1(5, Grid.init(T, &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(5, repairMode2(5, Grid.init(T, &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(5, repairMode3(5, Grid.init(T, &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(5, repairMode4(5, Grid.init(T, &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 3)));

            // Out of range - high
            try std.testing.expectEqual(9, repairMode1(10, Grid.init(T, &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(8, repairMode2(10, Grid.init(T, &.{ 9, 8, 7, 6, 5, 4, 3, 2, 1 }, 3)));
            try std.testing.expectEqual(7, repairMode3(10, Grid.init(T, &.{ 9, 8, 7, 6, 5, 4, 3, 2, 1 }, 3)));
            try std.testing.expectEqual(6, repairMode4(10, Grid.init(T, &.{ 9, 8, 7, 6, 5, 4, 3, 2, 1 }, 3)));

            // Out of range - low
            try std.testing.expectEqual(1, repairMode1(0, Grid.init(T, &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(2, repairMode2(0, Grid.init(T, &.{ 9, 8, 7, 6, 5, 4, 3, 2, 1 }, 3)));
            try std.testing.expectEqual(3, repairMode3(0, Grid.init(T, &.{ 9, 8, 7, 6, 5, 4, 3, 2, 1 }, 3)));
            try std.testing.expectEqual(4, repairMode4(0, Grid.init(T, &.{ 9, 8, 7, 6, 5, 4, 3, 2, 1 }, 3)));
        }

        /// Line-sensitive clipping giving the minimal change.
        ///
        /// Specifically, it clips the center pixel with four pairs
        /// of opposing pixels respectively, and the pair that results
        /// in the smallest change to the center pixel is used.
        fn repairMode5(src: T, grid: Grid) T {
            const sorted = grid.minMaxOppositesWithCenter();

            const srcT = @as(SAT, src);

            const clamp1 = std.math.clamp(src, sorted.min1, sorted.max1);
            const clamp2 = std.math.clamp(src, sorted.min2, sorted.max2);
            const clamp3 = std.math.clamp(src, sorted.min3, sorted.max3);
            const clamp4 = std.math.clamp(src, sorted.min4, sorted.max4);

            const c1 = @abs(srcT - clamp1);
            const c2 = @abs(srcT - clamp2);
            const c3 = @abs(srcT - clamp3);
            const c4 = @abs(srcT - clamp4);

            const mindiff = @min(c1, c2, c3, c4);

            // This order matters to match RGVS output.
            if (mindiff == c4) {
                return clamp4;
            } else if (mindiff == c2) {
                return clamp2;
            } else if (mindiff == c3) {
                return clamp3;
            }
            return clamp1;
        }

        test "Repair Mode 5" {
            // a1 and a8 clipping.
            try std.testing.expectEqual(2, repairMode5(1, Grid.init(T, &.{ 2, 6, 6, 6, 2, 7, 7, 7, 3 }, 3)));
            try std.testing.expectEqual(3, repairMode5(3, Grid.init(T, &.{ 2, 6, 6, 6, 2, 7, 7, 7, 3 }, 3)));
            // ^ The obove test is not ideal, since it doesn't properly test clamping behavior.
            // But this is harder to test than RG Mode 5, since the Repair implementation incorporates
            // the center pixel value into the min/max calculations of *all* pixel pairs. This means that the
            // center pixel can influence the corresponding min or max for any given pair, meaning it's trivial
            // to produce a "zero difference" clip value...
            // I'm sure there's a better way to test this, but my brain is fried after staring at this problem
            // for 30 minutes...

            // a2 and a7 clipping.
            try std.testing.expectEqual(2, repairMode5(1, Grid.init(T, &.{ 6, 2, 6, 6, 2, 7, 7, 3, 7 }, 3)));
            try std.testing.expectEqual(3, repairMode5(3, Grid.init(T, &.{ 6, 2, 6, 6, 2, 7, 7, 3, 7 }, 3)));

            // a3 and a6 clipping.
            try std.testing.expectEqual(2, repairMode5(1, Grid.init(T, &.{ 6, 6, 2, 6, 2, 7, 3, 7, 7 }, 3)));
            try std.testing.expectEqual(3, repairMode5(3, Grid.init(T, &.{ 6, 6, 2, 6, 2, 7, 3, 7, 7 }, 3)));

            // a4 and a5 clipping.
            try std.testing.expectEqual(2, repairMode5(1, Grid.init(T, &.{ 6, 6, 6, 2, 2, 3, 7, 7, 7 }, 3)));
            try std.testing.expectEqual(3, repairMode5(3, Grid.init(T, &.{ 6, 6, 6, 2, 2, 3, 7, 7, 7 }, 3)));
        }

        /// Line-sensitive clipping, intermediate.
        ///
        /// It considers the range of the clipping operation
        /// (the difference between the two opposing pixels)
        /// as well as the change applied to the center pixel.
        ///
        /// The change applied to the center pixel is prioritized
        /// (ratio 2:1) in this mode.
        fn repairMode6(src: T, grid: Grid, chroma: bool) T {
            const sorted = grid.minMaxOppositesWithCenter();

            const d1 = sorted.max1 - sorted.min1;
            const d2 = sorted.max2 - sorted.min2;
            const d3 = sorted.max3 - sorted.min3;
            const d4 = sorted.max4 - sorted.min4;

            const clamp1 = std.math.clamp(src, sorted.min1, sorted.max1);
            const clamp2 = std.math.clamp(src, sorted.min2, sorted.max2);
            const clamp3 = std.math.clamp(src, sorted.min3, sorted.max3);
            const clamp4 = std.math.clamp(src, sorted.min4, sorted.max4);

            // Max / min Zig comptime + runtime shenanigans.
            // TODO: Pretty sure there's a bug here.
            // This maximum should likely be the maximum of the video bit depth,
            // not the processing bit depth.
            // Avisynth uses a max of the video bit depth, but RGVS uses a max of 0xFFFF.
            // Maybe it doesn't matter...
            // In theory it would only be an issue if every pixel around this
            // pixel was white and this one was black
            const maxChroma = types.getTypeMaximum(T, true);
            const maxNoChroma = types.getTypeMaximum(T, false);

            const maximum = if (chroma) maxChroma else maxNoChroma;

            const srcT = @as(SAT, src);

            const c1 = @min((@abs(srcT - clamp1) * 2) + d1, maximum);
            const c2 = @min((@abs(srcT - clamp2) * 2) + d2, maximum);
            const c3 = @min((@abs(srcT - clamp3) * 2) + d3, maximum);
            const c4 = @min((@abs(srcT - clamp4) * 2) + d4, maximum);

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

        /// Same as mode 6, except the ratio is 1:1 in this mode.
        fn repairMode7(src: T, grid: Grid) T {
            const sorted = grid.minMaxOppositesWithCenter();

            const d1 = sorted.max1 - sorted.min1;
            const d2 = sorted.max2 - sorted.min2;
            const d3 = sorted.max3 - sorted.min3;
            const d4 = sorted.max4 - sorted.min4;

            const clamp1 = std.math.clamp(src, sorted.min1, sorted.max1);
            const clamp2 = std.math.clamp(src, sorted.min2, sorted.max2);
            const clamp3 = std.math.clamp(src, sorted.min3, sorted.max3);
            const clamp4 = std.math.clamp(src, sorted.min4, sorted.max4);

            const srcT = @as(SAT, src);

            const c1 = @abs(srcT - clamp1) + d1;
            const c2 = @abs(srcT - clamp2) + d2;
            const c3 = @abs(srcT - clamp3) + d3;
            const c4 = @abs(srcT - clamp4) + d4;

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
        fn repairMode8(src: T, grid: Grid, chroma: bool) T {
            const sorted = grid.minMaxOppositesWithCenter();

            const d1: UAT = sorted.max1 - sorted.min1;
            const d2: UAT = sorted.max2 - sorted.min2;
            const d3: UAT = sorted.max3 - sorted.min3;
            const d4: UAT = sorted.max4 - sorted.min4;

            const clamp1 = std.math.clamp(src, sorted.min1, sorted.max1);
            const clamp2 = std.math.clamp(src, sorted.min2, sorted.max2);
            const clamp3 = std.math.clamp(src, sorted.min3, sorted.max3);
            const clamp4 = std.math.clamp(src, sorted.min4, sorted.max4);

            // Max / min Zig comptime + runtime shenanigans.
            const maxChroma = types.getTypeMaximum(T, true);
            const maxNoChroma = types.getTypeMaximum(T, false);
            const minChroma = types.getTypeMinimum(T, true);
            const minNoChroma = types.getTypeMinimum(T, false);

            const maximum = if (chroma) maxChroma else maxNoChroma;
            const minimum = if (chroma) minChroma else minNoChroma;

            const srcT = @as(SAT, src);

            const c1 = std.math.clamp(@abs(srcT - clamp1) + (d1 * 2), minimum, maximum);
            const c2 = std.math.clamp(@abs(srcT - clamp2) + (d2 * 2), minimum, maximum);
            const c3 = std.math.clamp(@abs(srcT - clamp3) + (d3 * 2), minimum, maximum);
            const c4 = std.math.clamp(@abs(srcT - clamp4) + (d4 * 2), minimum, maximum);

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

        /// Line-sensitive clipping on a line where the neighbor pixels are the closest.
        fn repairMode9(src: T, grid: Grid) T {
            const sorted = grid.minMaxOppositesWithCenter();

            const d1 = sorted.max1 - sorted.min1;
            const d2 = sorted.max2 - sorted.min2;
            const d3 = sorted.max3 - sorted.min3;
            const d4 = sorted.max4 - sorted.min4;

            const mindiff = @min(d1, d2, d3, d4);

            // This order matters in order to match the exact
            // same output of RGVS
            if (mindiff == d4) {
                return std.math.clamp(src, sorted.min4, sorted.max4);
            } else if (mindiff == d2) {
                return std.math.clamp(src, sorted.min2, sorted.max2);
            } else if (mindiff == d3) {
                return std.math.clamp(src, sorted.min3, sorted.max3);
            }
            return std.math.clamp(src, sorted.min1, sorted.max1);
        }

        test "Repair Mode 9" {
            // TODO: Add testing based on the difference directions (d4, d2, d3, d1) to ensure that the proper order is followed.

            // a1 and a8 clipping.
            try std.testing.expectEqual(2, repairMode9(1, Grid.init(T, &.{ 2, 0, 0, 0, 2, 100, 100, 100, 3 }, 3)));
            try std.testing.expectEqual(3, repairMode9(4, Grid.init(T, &.{ 2, 0, 0, 0, 2, 100, 100, 100, 3 }, 3)));

            // a2 and a7 clipping.
            try std.testing.expectEqual(2, repairMode9(1, Grid.init(T, &.{ 0, 2, 0, 0, 2, 100, 100, 3, 100 }, 3)));
            try std.testing.expectEqual(3, repairMode9(4, Grid.init(T, &.{ 0, 2, 0, 0, 2, 100, 100, 3, 100 }, 3)));

            // a3 and a6 clipping.
            try std.testing.expectEqual(2, repairMode9(1, Grid.init(T, &.{ 0, 0, 2, 0, 2, 100, 3, 100, 100 }, 3)));
            try std.testing.expectEqual(3, repairMode9(4, Grid.init(T, &.{ 0, 0, 2, 0, 2, 100, 3, 100, 100 }, 3)));

            // a4 and a5 clipping.
            try std.testing.expectEqual(2, repairMode9(1, Grid.init(T, &.{ 0, 0, 0, 2, 2, 3, 100, 100, 100 }, 3)));
            try std.testing.expectEqual(3, repairMode9(4, Grid.init(T, &.{ 0, 0, 0, 2, 2, 3, 100, 100, 100 }, 3)));
        }

        /// Replaces the target pixel with the closest pixel from the 3×3-pixel reference square.
        fn repairMode10(src: T, grid: Grid) T {
            const srcT: SAT = src;

            const d1 = @abs(srcT - grid.top_left);
            const d2 = @abs(srcT - grid.top_center);
            const d3 = @abs(srcT - grid.top_right);
            const d4 = @abs(srcT - grid.center_left);
            const d5 = @abs(srcT - grid.center_right);
            const d6 = @abs(srcT - grid.bottom_left);
            const d7 = @abs(srcT - grid.bottom_center);
            const d8 = @abs(srcT - grid.bottom_right);
            const dc = @abs(srcT - grid.center_center);

            const mindiff = @min(d1, d2, d3, d4, d5, d6, d7, d8, dc);

            // This order matters in order to match the exact
            // same output of RGVS

            return if (mindiff == d7)
                grid.bottom_center
            else if (mindiff == d8)
                grid.bottom_right
            else if (mindiff == d6)
                grid.bottom_left
            else if (mindiff == d2)
                grid.top_center
            else if (mindiff == d3)
                grid.top_right
            else if (mindiff == d1)
                grid.top_left
            else if (mindiff == d5)
                grid.center_right
            else if (mindiff == dc)
                grid.center_center
            else
                grid.center_left;
        }

        test "Repair Mode 10" {
            // TODO: Add testing to ensure that order is respected (d7, d8, d6, ...)
            try std.testing.expectEqual(2, repairMode10(1, Grid.init(T, &.{ 2, 3, 4, 5, 10, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(2, repairMode10(1, Grid.init(T, &.{ 2, 3, 4, 5, 10, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(2, repairMode10(1, Grid.init(T, &.{ 9, 2, 3, 4, 10, 5, 6, 7, 8 }, 3)));
            try std.testing.expectEqual(2, repairMode10(1, Grid.init(T, &.{ 8, 9, 2, 3, 10, 4, 5, 6, 7 }, 3)));
            try std.testing.expectEqual(2, repairMode10(1, Grid.init(T, &.{ 7, 8, 9, 2, 10, 3, 4, 5, 6 }, 3)));
            try std.testing.expectEqual(2, repairMode10(1, Grid.init(T, &.{ 6, 7, 8, 9, 10, 2, 3, 4, 5 }, 3)));
            try std.testing.expectEqual(2, repairMode10(1, Grid.init(T, &.{ 5, 6, 7, 8, 10, 9, 2, 3, 4 }, 3)));
            try std.testing.expectEqual(2, repairMode10(1, Grid.init(T, &.{ 4, 5, 6, 7, 10, 8, 9, 2, 3 }, 3)));
            try std.testing.expectEqual(2, repairMode10(1, Grid.init(T, &.{ 3, 4, 5, 6, 10, 7, 8, 9, 2 }, 3)));
        }

        /// Repair Modes 11-14
        /// Same as modes 1–4 but uses min(Nth_min, c) and max(Nth_max, c) for the clipping,
        /// where c is the value of the center pixel of the reference clip.
        pub fn repairMode12(src: T, grid: Grid) T {
            const sorted = grid.sortWithoutCenter();

            const min = @min(sorted[1], grid.center_center);
            const max = @max(sorted[6], grid.center_center);

            return std.math.clamp(src, min, max);
        }

        pub fn repairMode13(src: T, grid: Grid) T {
            const sorted = grid.sortWithoutCenter();

            const min = @min(sorted[2], grid.center_center);
            const max = @max(sorted[5], grid.center_center);

            return std.math.clamp(src, min, max);
        }

        pub fn repairMode14(src: T, grid: Grid) T {
            const sorted = grid.sortWithoutCenter();

            const min = @min(sorted[3], grid.center_center);
            const max = @max(sorted[4], grid.center_center);

            return std.math.clamp(src, min, max);
        }

        test "Repair Mode 12-14" {
            // In range
            try std.testing.expectEqual(5, repairMode12(5, Grid.init(T, &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(5, repairMode13(5, Grid.init(T, &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(5, repairMode14(5, Grid.init(T, &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 3)));

            // Out of range - high
            try std.testing.expectEqual(8, repairMode12(10, Grid.init(T, &.{ 9, 8, 7, 6, 5, 4, 3, 2, 1 }, 3)));
            try std.testing.expectEqual(7, repairMode13(10, Grid.init(T, &.{ 9, 8, 7, 6, 5, 4, 3, 2, 1 }, 3)));
            try std.testing.expectEqual(6, repairMode14(10, Grid.init(T, &.{ 9, 8, 7, 6, 5, 4, 3, 2, 1 }, 3)));

            // Out of range - low
            try std.testing.expectEqual(2, repairMode12(0, Grid.init(T, &.{ 9, 8, 7, 6, 5, 4, 3, 2, 1 }, 3)));
            try std.testing.expectEqual(3, repairMode13(0, Grid.init(T, &.{ 9, 8, 7, 6, 5, 4, 3, 2, 1 }, 3)));
            try std.testing.expectEqual(4, repairMode14(0, Grid.init(T, &.{ 9, 8, 7, 6, 5, 4, 3, 2, 1 }, 3)));
        }

        /// Clips the source pixels using a clipping pair from the RemoveGrain modes 5
        pub fn repairMode15(src: T, grid: Grid) T {
            const sorted = grid.minMaxOppositesWithoutCenter();

            const c: SAT = grid.center_center;

            const c1 = @abs(c - std.math.clamp(c, sorted.min1, sorted.max1));
            const c2 = @abs(c - std.math.clamp(c, sorted.min2, sorted.max2));
            const c3 = @abs(c - std.math.clamp(c, sorted.min3, sorted.max3));
            const c4 = @abs(c - std.math.clamp(c, sorted.min4, sorted.max4));

            const mindiff = @min(c1, c2, c3, c4);

            var min: T = 0;
            var max: T = 0;
            if (mindiff == c4) {
                min = sorted.min4;
                max = sorted.max4;
            } else if (mindiff == c2) {
                min = sorted.min2;
                max = sorted.max2;
            } else if (mindiff == c3) {
                min = sorted.min3;
                max = sorted.max3;
            } else {
                min = sorted.min1;
                max = sorted.max1;
            }

            min = @min(min, grid.center_center);
            max = @max(max, grid.center_center);

            return std.math.clamp(src, min, max);
        }

        /// Clips the source pixels using a clipping pair from the RemoveGrain modes 6
        pub fn repairMode16(src: T, grid: Grid, chroma: bool) T {
            const sorted = grid.minMaxOppositesWithoutCenter();

            const maximum = if (chroma) types.getTypeMaximum(T, true) else types.getTypeMaximum(T, false);
            const minimum = if (chroma) types.getTypeMinimum(T, true) else types.getTypeMinimum(T, false);

            const d1 = sorted.max1 - sorted.min1;
            const d2 = sorted.max2 - sorted.min2;
            const d3 = sorted.max3 - sorted.min3;
            const d4 = sorted.max4 - sorted.min4;

            const c: SAT = grid.center_center;

            const c1 = std.math.clamp((@abs(c - std.math.clamp(c, sorted.min1, sorted.max1)) * 2) + d1, minimum, maximum);
            const c2 = std.math.clamp((@abs(c - std.math.clamp(c, sorted.min2, sorted.max2)) * 2) + d2, minimum, maximum);
            const c3 = std.math.clamp((@abs(c - std.math.clamp(c, sorted.min3, sorted.max3)) * 2) + d3, minimum, maximum);
            const c4 = std.math.clamp((@abs(c - std.math.clamp(c, sorted.min4, sorted.max4)) * 2) + d4, minimum, maximum);

            const mindiff = @min(c1, c2, c3, c4);

            var min: T = 0;
            var max: T = 0;
            if (mindiff == c4) {
                min = sorted.min4;
                max = sorted.max4;
            } else if (mindiff == c2) {
                min = sorted.min2;
                max = sorted.max2;
            } else if (mindiff == c3) {
                min = sorted.min3;
                max = sorted.max3;
            } else {
                min = sorted.min1;
                max = sorted.max1;
            }

            min = @min(min, grid.center_center);
            max = @max(max, grid.center_center);

            return std.math.clamp(src, min, max);
        }

        /// Clips the pixel with the minimum and maximum of respectively the maximum and minimum of each pair of opposite neighbour pixels.
        fn repairMode17(src: T, grid: Grid) T {
            const sorted = grid.minMaxOppositesWithoutCenter();

            const l = @max(sorted.min1, sorted.min2, sorted.min3, sorted.min4);
            const u = @min(sorted.max1, sorted.max2, sorted.max3, sorted.max4);

            return std.math.clamp(src, @min(l, u, grid.center_center), @max(l, u, grid.center_center));
        }

        test "Repair Mode 17" {
            // Clip to the lowest maximum
            try std.testing.expectEqual(10, repairMode17(11, Grid.init(T, &.{ 1, 1, 1, 1, 10, 5, 6, 7, 8 }, 3)));
            try std.testing.expectEqual(5, repairMode17(11, Grid.init(T, &.{ 1, 1, 1, 1, 4, 5, 6, 7, 8 }, 3)));

            // Clip to the highest minimum
            try std.testing.expectEqual(1, repairMode17(0, Grid.init(T, &.{ 1, 2, 3, 4, 1, 5, 5, 5, 5 }, 3)));
            try std.testing.expectEqual(4, repairMode17(0, Grid.init(T, &.{ 1, 2, 3, 4, 5, 5, 5, 5, 5 }, 3)));
        }

        /// Line-sensitive clipping using opposite neighbours whose greatest distance from the current pixel is minimal.
        fn repairMode18(src: T, grid: Grid) T {
            const cT = @as(SAT, grid.center_center);
            const d1 = @max(@abs(cT - grid.top_left), @abs(cT - grid.bottom_right));
            const d2 = @max(@abs(cT - grid.top_center), @abs(cT - grid.bottom_center));
            const d3 = @max(@abs(cT - grid.top_right), @abs(cT - grid.bottom_left));
            const d4 = @max(@abs(cT - grid.center_left), @abs(cT - grid.center_right));

            const mindiff = @min(d1, d2, d3, d4);

            var min: T = 0;
            var max: T = 0;
            if (mindiff == d4) {
                min = @min(grid.center_left, grid.center_right);
                max = @max(grid.center_left, grid.center_right);
            } else if (mindiff == d2) {
                min = @min(grid.top_center, grid.bottom_center);
                max = @max(grid.top_center, grid.bottom_center);
            } else if (mindiff == d3) {
                min = @min(grid.top_right, grid.bottom_left);
                max = @max(grid.top_right, grid.bottom_left);
            } else {
                min = @min(grid.top_left, grid.bottom_right);
                max = @max(grid.top_left, grid.bottom_right);
            }

            min = @min(min, grid.center_center);
            max = @max(max, grid.center_center);

            return std.math.clamp(src, min, max);
        }

        fn repairMode19(src: T, grid: Grid, chroma: bool) T {
            const cT = @as(SAT, grid.center_center);

            const d1 = math.lossyCast(T, @abs(cT - grid.top_left));
            const d2 = math.lossyCast(T, @abs(cT - grid.top_center));
            const d3 = math.lossyCast(T, @abs(cT - grid.top_right));
            const d4 = math.lossyCast(T, @abs(cT - grid.center_left));
            const d5 = math.lossyCast(T, @abs(cT - grid.center_right));
            const d6 = math.lossyCast(T, @abs(cT - grid.bottom_left));
            const d7 = math.lossyCast(T, @abs(cT - grid.bottom_center));
            const d8 = math.lossyCast(T, @abs(cT - grid.bottom_right));

            const mindiff = @min(d1, d2, d3, d4, d5, d6, d7, d8);

            const maximum = if (chroma) types.getTypeMaximum(T, true) else types.getTypeMaximum(T, false);
            const minimum = if (chroma) types.getTypeMinimum(T, true) else types.getTypeMinimum(T, false);

            return math.lossyCast(T, std.math.clamp(src, std.math.clamp(cT - mindiff, minimum, maximum), std.math.clamp(cT + mindiff, minimum, maximum)));
        }

        // Produces output identical to RGVS, but differs in RGSF, sometimes significantly.
        // However, I think this is a bug in RGSF, because when I process a clip in 8 bit and 32 bit
        // with Zsmooth, the resulting output looks visually identical to me. So Zsmooth produces the same
        // visual output as RGVS always, for all bit depths. RGSF is just weird...
        fn repairMode20(src: T, grid: Grid, chroma: bool) T {
            const cT = @as(SAT, grid.center_center);

            const d1 = math.lossyCast(T, @abs(cT - grid.top_left));
            const d2 = math.lossyCast(T, @abs(cT - grid.top_center));
            const d3 = math.lossyCast(T, @abs(cT - grid.top_right));
            const d4 = math.lossyCast(T, @abs(cT - grid.center_left));
            const d5 = math.lossyCast(T, @abs(cT - grid.center_right));
            const d6 = math.lossyCast(T, @abs(cT - grid.bottom_left));
            const d7 = math.lossyCast(T, @abs(cT - grid.bottom_center));
            const d8 = math.lossyCast(T, @abs(cT - grid.bottom_right));

            var maxdiff = @max(d1, d2);
            var mindiff = @min(d1, d2);

            // This code differs slightly from RGVS/RGSF (and yet strangely
            // produces identical output for RGVS) but is actually correct. We
            // forceably use @min(mindiff, d3) and @max(mindiff, d3) to get the
            // order of the arguments to std.math.clamp correct. Without these,
            // the debug build (properly) catches cases where we feed values in
            // the wrong order. We see a pretty small performance hit due to
            // the extra @min/@maxes, but I'm leaning into proper code first
            // and foremost.
            maxdiff = std.math.clamp(maxdiff, @min(mindiff, d3), @max(mindiff, d3));
            mindiff = @min(mindiff, d3);

            maxdiff = std.math.clamp(maxdiff, @min(mindiff, d4), @max(mindiff, d4));
            mindiff = @min(mindiff, d4);

            maxdiff = std.math.clamp(maxdiff, @min(mindiff, d5), @max(mindiff, d5));
            mindiff = @min(mindiff, d5);

            maxdiff = std.math.clamp(maxdiff, @min(mindiff, d6), @max(mindiff, d6));
            mindiff = @min(mindiff, d6);

            maxdiff = std.math.clamp(maxdiff, @min(mindiff, d7), @max(mindiff, d7));
            mindiff = @min(mindiff, d7);

            maxdiff = std.math.clamp(maxdiff, @min(mindiff, d8), @max(mindiff, d8));

            const maximum = if (chroma) types.getTypeMaximum(T, true) else types.getTypeMaximum(T, false);
            const minimum = if (chroma) types.getTypeMinimum(T, true) else types.getTypeMinimum(T, false);

            return math.lossyCast(T, std.math.clamp(src, std.math.clamp(cT - maxdiff, minimum, maximum), std.math.clamp(cT + maxdiff, minimum, maximum)));
        }

        fn repairMode21(src: T, grid: Grid, chroma: bool) T {
            const cT = @as(SAT, grid.center_center);

            const maximum = if (chroma) types.getTypeMaximum(T, true) else types.getTypeMaximum(T, false);
            const minimum = if (chroma) types.getTypeMinimum(T, true) else types.getTypeMinimum(T, false);

            const sorted = grid.minMaxOppositesWithoutCenter();

            const d1 = std.math.clamp(sorted.max1 - cT, minimum, maximum);
            const d2 = std.math.clamp(sorted.max2 - cT, minimum, maximum);
            const d3 = std.math.clamp(sorted.max3 - cT, minimum, maximum);
            const d4 = std.math.clamp(sorted.max4 - cT, minimum, maximum);

            const rd1 = std.math.clamp(cT - sorted.min1, minimum, maximum);
            const rd2 = std.math.clamp(cT - sorted.min2, minimum, maximum);
            const rd3 = std.math.clamp(cT - sorted.min3, minimum, maximum);
            const rd4 = std.math.clamp(cT - sorted.min4, minimum, maximum);

            const @"u1" = @max(d1, rd1);
            const @"u2" = @max(d2, rd2);
            const @"u3" = @max(d3, rd3);
            const @"u4" = @max(d4, rd4);

            const u = @min(@"u1", @"u2", @"u3", @"u4");

            return math.lossyCast(T, std.math.clamp(src, std.math.clamp(cT - u, minimum, maximum), std.math.clamp(cT + u, minimum, maximum)));
        }

        fn repairMode22(src: T, grid: Grid, chroma: bool) T {
            const srcT = @as(SAT, src);

            const d1 = math.lossyCast(T, @abs(srcT - grid.top_left));
            const d2 = math.lossyCast(T, @abs(srcT - grid.top_center));
            const d3 = math.lossyCast(T, @abs(srcT - grid.top_right));
            const d4 = math.lossyCast(T, @abs(srcT - grid.center_left));
            const d5 = math.lossyCast(T, @abs(srcT - grid.center_right));
            const d6 = math.lossyCast(T, @abs(srcT - grid.bottom_left));
            const d7 = math.lossyCast(T, @abs(srcT - grid.bottom_center));
            const d8 = math.lossyCast(T, @abs(srcT - grid.bottom_right));

            const mindiff = @min(d1, d2, d3, d4, d5, d6, d7, d8);

            const maximum = if (chroma) types.getTypeMaximum(T, true) else types.getTypeMaximum(T, false);
            const minimum = if (chroma) types.getTypeMinimum(T, true) else types.getTypeMinimum(T, false);

            return math.lossyCast(T, std.math.clamp(grid.center_center, std.math.clamp(srcT - mindiff, minimum, maximum), std.math.clamp(srcT + mindiff, minimum, maximum)));
        }

        fn repair(mode: comptime_int, src: T, grid: Grid, chroma: bool) T {
            return switch (mode) {
                1 => repairMode1(src, grid),
                2 => repairMode2(src, grid),
                3 => repairMode3(src, grid),
                4 => repairMode4(src, grid),
                5 => repairMode5(src, grid),
                6 => repairMode6(src, grid, chroma),
                7 => repairMode7(src, grid),
                8 => repairMode8(src, grid, chroma),
                9 => repairMode9(src, grid),
                10 => repairMode10(src, grid),
                11 => repairMode1(src, grid), // Same as mode 1
                12 => repairMode12(src, grid),
                13 => repairMode13(src, grid),
                14 => repairMode14(src, grid),
                15 => repairMode15(src, grid),
                16 => repairMode16(src, grid, chroma),
                17 => repairMode17(src, grid),
                18 => repairMode18(src, grid),
                19 => repairMode19(src, grid, chroma),
                20 => repairMode20(src, grid, chroma),
                21 => repairMode21(src, grid, chroma),
                22 => repairMode22(src, grid, chroma),
                else => unreachable,
            };
        }

        pub fn processPlaneScalar(mode: comptime_int, noalias srcp: []const T, noalias repairp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize, chroma: bool) void {
            // Process top row with mirrored grid.
            for (0..width) |column| {
                const src = srcp[(0 * stride) + column];
                const grid = Grid.initFromCenterMirrored(T, 0, column, width, height, repairp, stride);
                dstp[(0 * stride) + column] = repair(mode, src, grid, chroma);
            }

            for (1..height - 1) |row| {
                // Process first pixel of the row with mirrored grid.
                const srcFirst = srcp[(row * stride)];
                const gridFirst = Grid.initFromCenterMirrored(T, row, 0, width, height, repairp, stride);
                dstp[(row * stride)] = repair(mode, srcFirst, gridFirst, chroma);

                for (1..width - 1) |w| {
                    const rowCurr = ((row) * stride);
                    const top_left = ((row - 1) * stride) + w - 1;

                    const src = srcp[rowCurr + w];

                    // Use a non-mirrored grid everywhere else for maximum performance.
                    // We don't need the mirror effect anyways, as all pixels contain valid data.
                    const grid = Grid.init(T, repairp[top_left..], stride);

                    dstp[rowCurr + w] = repair(mode, src, grid, chroma);
                }

                // Process last pixel of the row with mirrored grid.
                const srcLast = srcp[(row * stride) + (width - 1)];
                const gridLast = Grid.initFromCenterMirrored(T, row, width - 1, width, height, repairp, stride);
                dstp[(row * stride) + (width - 1)] = repair(mode, srcLast, gridLast, chroma);
            }

            // Process bottom row with mirrored grid.
            for (0..width) |column| {
                const src = srcp[((height - 1) * stride) + column];
                const grid = Grid.initFromCenterMirrored(T, height - 1, column, width, height, repairp, stride);
                dstp[((height - 1) * stride) + column] = repair(mode, src, grid, chroma);
            }
        }

        fn getFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
            // Assign frame_data to nothing to stop compiler complaints
            _ = frame_data;

            const d: *RepairData = @ptrCast(@alignCast(instance_data));

            if (activation_reason == ar.Initial) {
                vsapi.?.requestFrameFilter.?(n, d.node, frame_ctx);
                vsapi.?.requestFrameFilter.?(n, d.repair_node, frame_ctx);
            } else if (activation_reason == ar.AllFramesReady) {
                const src_frame = vsapi.?.getFrameFilter.?(n, d.node, frame_ctx);
                const repair_frame = vsapi.?.getFrameFilter.?(n, d.repair_node, frame_ctx);

                defer vsapi.?.freeFrame.?(src_frame);
                defer vsapi.?.freeFrame.?(repair_frame);

                const process = [_]bool{
                    d.modes[0] > 0,
                    d.modes[1] > 0,
                    d.modes[2] > 0,
                };

                const dst = vscmn.newVideoFrame(&process, src_frame, d.vi, core, vsapi);

                for (0..@intCast(d.vi.format.numPlanes)) |_plane| {
                    const plane: c_int = @intCast(_plane);
                    // Skip planes we aren't supposed to process
                    if (d.modes[_plane] == 0) {
                        continue;
                    }

                    const width: usize = @intCast(vsapi.?.getFrameWidth.?(dst, plane));
                    const height: usize = @intCast(vsapi.?.getFrameHeight.?(dst, plane));
                    const stride: usize = @as(usize, @intCast(vsapi.?.getStride.?(dst, plane))) / @sizeOf(T);
                    const srcp: []const T = @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frame, plane))))[0..(height * stride)];
                    const repairp: []const T = @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(repair_frame, plane))))[0..(height * stride)];
                    const dstp: []T = @as([*]T, @ptrCast(@alignCast(vsapi.?.getWritePtr.?(dst, plane))))[0..(height * stride)];
                    const chroma = d.vi.format.colorFamily == vs.ColorFamily.YUV and plane > 0;

                    // See note in remove_grain about the use of "double switch" optimization.
                    switch (d.modes[_plane]) {
                        inline 1...24 => |mode| processPlaneScalar(mode, srcp, repairp, dstp, width, height, stride, chroma),
                        else => unreachable,
                    }
                }

                return dst;
            }

            return null;
        }
    };
}

export fn repairFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *RepairData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    vsapi.?.freeNode.?(d.repair_node);
    allocator.destroy(d);
}

export fn repairCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    var d: RepairData = undefined;

    // TODO: Add error handling.
    var err: vs.MapPropertyError = undefined;

    d.node = vsapi.?.mapGetNode.?(in, "clip", 0, &err).?;
    d.repair_node = vsapi.?.mapGetNode.?(in, "repairclip", 0, &err).?;

    d.vi = vsapi.?.getVideoInfo.?(d.node);

    if (!vsh.isSameVideoInfo(d.vi, vsapi.?.getVideoInfo.?(d.repair_node))) {
        vsapi.?.mapSetError.?(out, "Repair: Input clips must have the same format.");
        vsapi.?.freeNode.?(d.node);
        vsapi.?.freeNode.?(d.repair_node);
        return;
    }

    const numModes = vsapi.?.mapNumElements.?(in, "mode");
    if (numModes > d.vi.format.numPlanes) {
        vsapi.?.mapSetError.?(out, "Repair: Number of modes must be equal or fewer than the number of input planes.");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    for (0..3) |i| {
        if (i < numModes) {
            if (vsh.mapGetN(i32, in, "mode", @intCast(i), vsapi)) |mode| {
                if (mode < 0 or mode > 24) {
                    vsapi.?.mapSetError.?(out, "Repair: Invalid mode specified, only modes 0-24 supported.");
                    vsapi.?.freeNode.?(d.node);
                    return;
                }
                d.modes[i] = @intCast(mode);
            }
        } else {
            d.modes[i] = d.modes[i - 1];
        }
    }

    const data: *RepairData = allocator.create(RepairData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
        vs.FilterDependency{
            .source = d.repair_node,
            .requestPattern = rp.StrictSpatial,
        },
    };

    const getFrame = switch (d.vi.format.bytesPerSample) {
        1 => &Repair(u8).getFrame,
        2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &Repair(u16).getFrame else &Repair(f16).getFrame,
        4 => &Repair(f32).getFrame,
        else => unreachable,
    };

    vsapi.?.createVideoFilter.?(out, "Repair", d.vi, getFrame, repairFree, fm.Parallel, &deps, deps.len, data, core);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("Repair", "clip:vnode;repairclip:vnode;mode:int[]", "clip:vnode;", repairCreate, null, plugin);
}
