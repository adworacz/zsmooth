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

const RemoveGrainData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    vi: *const vs.VideoInfo,

    // The modes for each plane we will process.
    modes: [3]u5,
};

// TODO: Rewrite this plugin to use Grid implementation.

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

        const Grid = gridcmn.Grid(T);

        /// Every pixel is clamped to the lowest and highest values in the pixel's
        /// 3x3 neighborhood, center pixel not included.
        fn rgMode1(grid: Grid) T {
            const min = grid.minWithoutCenter();
            const max = grid.maxWithoutCenter();

            return @max(min, @min(grid.center_center, max));
        }

        /// Same as mode 1, except the second-lowest and second-highest values are used.
        fn rgMode2(grid: Grid) T {
            const a = grid.sortWithoutCenter();

            return math.clamp(grid.center_center, a[1], a[6]);
        }

        /// Same as mode 1, except the third-lowest and third-highest values are used.
        fn rgMode3(grid: Grid) T {
            const a = grid.sortWithoutCenter();

            return std.math.clamp(grid.center_center, a[2], a[5]);
        }

        /// Same as mode 1, except the fourth-lowest and fourth-highest values are used.
        /// This is identical to std.Median.
        fn rgMode4(grid: Grid) T {
            const a = grid.sortWithoutCenter();

            return std.math.clamp(grid.center_center, a[3], a[4]);
        }

        test "RG Mode 1-4" {
            // In range
            try std.testing.expectEqual(5, rgMode1(Grid.init(T, &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(5, rgMode2(Grid.init(T, &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(5, rgMode3(Grid.init(T, &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(5, rgMode4(Grid.init(T, &.{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, 3)));

            // Out of range - high
            try std.testing.expectEqual(9, rgMode1(Grid.init(T, &.{ 1, 2, 3, 4, 10, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(8, rgMode2(Grid.init(T, &.{ 1, 2, 3, 4, 10, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(7, rgMode3(Grid.init(T, &.{ 1, 2, 3, 4, 10, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(6, rgMode4(Grid.init(T, &.{ 1, 2, 3, 4, 10, 6, 7, 8, 9 }, 3)));

            // Out of range - low
            try std.testing.expectEqual(1, rgMode1(Grid.init(T, &.{ 1, 2, 3, 4, 0, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(2, rgMode2(Grid.init(T, &.{ 1, 2, 3, 4, 0, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(3, rgMode3(Grid.init(T, &.{ 1, 2, 3, 4, 0, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(4, rgMode4(Grid.init(T, &.{ 1, 2, 3, 4, 0, 6, 7, 8, 9 }, 3)));
        }

        /// Line-sensitive clipping giving the minimal change.
        ///
        /// Specifically, it clips the center pixel with four pairs
        /// of opposing pixels respectively, and the pair that results
        /// in the smallest change to the center pixel is used.
        fn rgMode5(grid: Grid) T {
            const sorted = grid.minMaxOppositesWithoutCenter();

            const cT = @as(SAT, grid.center_center);

            const clamp1 = std.math.clamp(grid.center_center, sorted.min1, sorted.max1);
            const clamp2 = std.math.clamp(grid.center_center, sorted.min2, sorted.max2);
            const clamp3 = std.math.clamp(grid.center_center, sorted.min3, sorted.max3);
            const clamp4 = std.math.clamp(grid.center_center, sorted.min4, sorted.max4);

            const c1 = @abs(cT - clamp1);
            const c2 = @abs(cT - clamp2);
            const c3 = @abs(cT - clamp3);
            const c4 = @abs(cT - clamp4);

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

        test "RG Mode 5" {
            // a1 and a8 clipping.
            try std.testing.expectEqual(2, rgMode5(Grid.init(T, &.{ 2, 6, 6, 6, 1, 7, 7, 7, 3 }, 3)));
            try std.testing.expectEqual(3, rgMode5(Grid.init(T, &.{ 2, 6, 6, 6, 4, 7, 7, 7, 3 }, 3)));

            // a2 and a7 clipping.
            try std.testing.expectEqual(2, rgMode5(Grid.init(T, &.{ 6, 2, 6, 6, 1, 7, 7, 3, 7 }, 3)));
            try std.testing.expectEqual(3, rgMode5(Grid.init(T, &.{ 6, 2, 6, 6, 4, 7, 7, 3, 7 }, 3)));

            // a3 and a6 clipping.
            try std.testing.expectEqual(2, rgMode5(Grid.init(T, &.{ 6, 6, 2, 6, 1, 7, 3, 7, 7 }, 3)));
            try std.testing.expectEqual(3, rgMode5(Grid.init(T, &.{ 6, 6, 2, 6, 4, 7, 3, 7, 7 }, 3)));

            // a4 and a5 clipping.
            try std.testing.expectEqual(2, rgMode5(Grid.init(T, &.{ 6, 6, 6, 2, 1, 3, 7, 7, 7 }, 3)));
            try std.testing.expectEqual(3, rgMode5(Grid.init(T, &.{ 6, 6, 6, 2, 4, 3, 7, 7, 7 }, 3)));
        }

        /// Line-sensitive clipping, intermediate.
        ///
        /// It considers the range of the clipping operation
        /// (the difference between the two opposing pixels)
        /// as well as the change applied to the center pixel.
        ///
        /// The change applied to the center pixel is prioritized
        /// (ratio 2:1) in this mode.
        fn rgMode6(grid: Grid, chroma: bool) T {
            const sorted = grid.minMaxOppositesWithoutCenter();

            const d1 = sorted.max1 - sorted.min1;
            const d2 = sorted.max2 - sorted.min2;
            const d3 = sorted.max3 - sorted.min3;
            const d4 = sorted.max4 - sorted.min4;

            const clamp1 = std.math.clamp(grid.center_center, sorted.min1, sorted.max1);
            const clamp2 = std.math.clamp(grid.center_center, sorted.min2, sorted.max2);
            const clamp3 = std.math.clamp(grid.center_center, sorted.min3, sorted.max3);
            const clamp4 = std.math.clamp(grid.center_center, sorted.min4, sorted.max4);

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

            const cT = @as(SAT, grid.center_center);

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

        // TODO: Add tests for RG mode 6

        /// Same as mode 6, except the ratio is 1:1 in this mode.
        fn rgMode7(grid: Grid) T {
            const sorted = grid.minMaxOppositesWithoutCenter();

            const d1 = sorted.max1 - sorted.min1;
            const d2 = sorted.max2 - sorted.min2;
            const d3 = sorted.max3 - sorted.min3;
            const d4 = sorted.max4 - sorted.min4;

            const clamp1 = std.math.clamp(grid.center_center, sorted.min1, sorted.max1);
            const clamp2 = std.math.clamp(grid.center_center, sorted.min2, sorted.max2);
            const clamp3 = std.math.clamp(grid.center_center, sorted.min3, sorted.max3);
            const clamp4 = std.math.clamp(grid.center_center, sorted.min4, sorted.max4);

            const cT = @as(SAT, grid.center_center);

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
        fn rgMode8(grid: Grid, chroma: bool) T {
            const sorted = grid.minMaxOppositesWithoutCenter();

            const d1: UAT = sorted.max1 - sorted.min1;
            const d2: UAT = sorted.max2 - sorted.min2;
            const d3: UAT = sorted.max3 - sorted.min3;
            const d4: UAT = sorted.max4 - sorted.min4;

            const clamp1 = std.math.clamp(grid.center_center, sorted.min1, sorted.max1);
            const clamp2 = std.math.clamp(grid.center_center, sorted.min2, sorted.max2);
            const clamp3 = std.math.clamp(grid.center_center, sorted.min3, sorted.max3);
            const clamp4 = std.math.clamp(grid.center_center, sorted.min4, sorted.max4);

            // Max / min Zig comptime + runtime shenanigans.
            const maxChroma = types.getTypeMaximum(T, true);
            const maxNoChroma = types.getTypeMaximum(T, false);
            const minChroma = types.getTypeMinimum(T, true);
            const minNoChroma = types.getTypeMinimum(T, false);

            const maximum = if (chroma) maxChroma else maxNoChroma;
            const minimum = if (chroma) minChroma else minNoChroma;

            const cT = @as(SAT, grid.center_center);

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
        fn rgMode9(grid: Grid) T {
            const sorted = grid.minMaxOppositesWithoutCenter();

            const d1 = sorted.max1 - sorted.min1;
            const d2 = sorted.max2 - sorted.min2;
            const d3 = sorted.max3 - sorted.min3;
            const d4 = sorted.max4 - sorted.min4;

            const mindiff = @min(d1, d2, d3, d4);

            // This order matters in order to match the exact
            // same output of RGVS
            if (mindiff == d4) {
                return std.math.clamp(grid.center_center, sorted.min4, sorted.max4);
            } else if (mindiff == d2) {
                return std.math.clamp(grid.center_center, sorted.min2, sorted.max2);
            } else if (mindiff == d3) {
                return std.math.clamp(grid.center_center, sorted.min3, sorted.max3);
            }
            return std.math.clamp(grid.center_center, sorted.min1, sorted.max1);
        }

        test "RG Mode 9" {
            // TODO: Add testing based on the difference directions (d4, d2, d3, d1) to ensure that the proper order is followed.

            // a1 and a8 clipping.
            try std.testing.expectEqual(2, rgMode9(Grid.init(T, &.{ 2, 0, 0, 0, 1, 100, 100, 100, 3 }, 3)));
            try std.testing.expectEqual(3, rgMode9(Grid.init(T, &.{ 2, 0, 0, 0, 4, 100, 100, 100, 3 }, 3)));

            // a2 and a7 clipping.
            try std.testing.expectEqual(2, rgMode9(Grid.init(T, &.{ 0, 2, 0, 0, 1, 100, 100, 3, 100 }, 3)));
            try std.testing.expectEqual(3, rgMode9(Grid.init(T, &.{ 0, 2, 0, 0, 4, 100, 100, 3, 100 }, 3)));

            // a3 and a6 clipping.
            try std.testing.expectEqual(2, rgMode9(Grid.init(T, &.{ 0, 0, 2, 0, 1, 100, 3, 100, 100 }, 3)));
            try std.testing.expectEqual(3, rgMode9(Grid.init(T, &.{ 0, 0, 2, 0, 4, 100, 3, 100, 100 }, 3)));

            // a4 and a5 clipping.
            try std.testing.expectEqual(2, rgMode9(Grid.init(T, &.{ 0, 0, 0, 2, 1, 3, 100, 100, 100 }, 3)));
            try std.testing.expectEqual(3, rgMode9(Grid.init(T, &.{ 0, 0, 0, 2, 4, 3, 100, 100, 100 }, 3)));
        }

        /// Replaces the center pixel with the closest neighbour. "Very poor denoise sharpener"
        fn rgMode10(grid: Grid) T {
            const cT: SAT = grid.center_center;

            const d1 = @abs(cT - grid.top_left);
            const d2 = @abs(cT - grid.top_center);
            const d3 = @abs(cT - grid.top_right);
            const d4 = @abs(cT - grid.center_left);
            const d5 = @abs(cT - grid.center_right);
            const d6 = @abs(cT - grid.bottom_left);
            const d7 = @abs(cT - grid.bottom_center);
            const d8 = @abs(cT - grid.bottom_right);

            const mindiff = @min(d1, d2, d3, d4, d5, d6, d7, d8);

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
            else
                grid.center_left;
        }

        test "RG Mode 10" {
            // TODO: Add testing to ensure that order is respected (d7, d8, d6, ...)
            try std.testing.expectEqual(2, rgMode10(Grid.init(T, &.{ 2, 3, 4, 5, 1, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(2, rgMode10(Grid.init(T, &.{ 2, 3, 4, 5, 1, 6, 7, 8, 9 }, 3)));
            try std.testing.expectEqual(2, rgMode10(Grid.init(T, &.{ 9, 2, 3, 4, 1, 5, 6, 7, 8 }, 3)));
            try std.testing.expectEqual(2, rgMode10(Grid.init(T, &.{ 8, 9, 2, 3, 1, 4, 5, 6, 7 }, 3)));
            try std.testing.expectEqual(2, rgMode10(Grid.init(T, &.{ 7, 8, 9, 2, 1, 3, 4, 5, 6 }, 3)));
            try std.testing.expectEqual(2, rgMode10(Grid.init(T, &.{ 6, 7, 8, 9, 1, 2, 3, 4, 5 }, 3)));
            try std.testing.expectEqual(2, rgMode10(Grid.init(T, &.{ 5, 6, 7, 8, 1, 9, 2, 3, 4 }, 3)));
            try std.testing.expectEqual(2, rgMode10(Grid.init(T, &.{ 4, 5, 6, 7, 1, 8, 9, 2, 3 }, 3)));
            try std.testing.expectEqual(2, rgMode10(Grid.init(T, &.{ 3, 4, 5, 6, 1, 7, 8, 9, 2 }, 3)));
        }

        /// Every pixel is replaced with a weighted arithmetic mean of its 3x3
        /// neighborhood.
        /// The center pixel has a weight of 4, the pixels above, below, to the
        /// left, and to the right of the center pixel each have a weight of 2,
        /// and the corner pixels each have a weight of 1.
        ///
        /// Identical to Convolution(matrix=[1, 2, 1, 2, 4, 2, 1, 2, 1])
        fn rgMode1112(grid: Grid) T {
            const sum = 4 * @as(UAT, grid.center_center) + 2 * (@as(UAT, grid.top_center) + grid.center_left + grid.center_right + grid.bottom_center) + grid.top_left + grid.top_right + grid.bottom_left + grid.bottom_right;
            return if (types.isFloat(T))
                sum / 16
            else
                @intCast((sum + 8) / 16);
        }

        test "RG Mode 11-12" {
            if (types.isInt(T)) {
                try std.testing.expectEqual(5, rgMode1112(Grid.init(T, &.{ 1, 5, 1, 5, 10, 5, 1, 5, 1 }, 3)));
            } else {
                try std.testing.expectEqual(5.25, rgMode1112(Grid.init(T, &.{ 1, 5, 1, 5, 10, 5, 1, 5, 1 }, 3)));
            }
        }

        /// RG 13 - Bob mode, interpolates top field from the line where the neighbours pixels are the closest.
        /// RG 14 - Bob mode, interpolates bottom field from the line where the neighbours pixels are the closest.
        fn rgMode1314(grid: Grid) T {
            const d1 = @abs(@as(SAT, grid.top_left) - grid.bottom_right);
            const d2 = @abs(@as(SAT, grid.top_center) - grid.bottom_center);
            const d3 = @abs(@as(SAT, grid.top_right) - grid.bottom_left);

            const mindiff = @min(d1, d2, d3);

            if (mindiff == d2) {
                return if (types.isFloat(T))
                    (@as(UAT, grid.top_center) + grid.bottom_center) / 2
                else
                    @intCast((@as(UAT, grid.top_center) + grid.bottom_center + 1) / 2);
            } else if (mindiff == d3) {
                return if (types.isFloat(T))
                    (@as(UAT, grid.top_right) + grid.bottom_left) / 2
                else
                    @intCast((@as(UAT, grid.top_right) + grid.bottom_left + 1) / 2);
            }
            return if (types.isFloat(T))
                (@as(UAT, grid.top_left) + grid.bottom_right) / 2
            else
                @intCast((@as(UAT, grid.top_left) + grid.bottom_right + 1) / 2);
        }

        test "RG Mode 13-14" {
            try std.testing.expectEqual(2, rgMode1314(Grid.init(T, &.{ 1, 1, 1, 0, 0, 0, 100, 100, 3 }, 3)));
            try std.testing.expectEqual(2, rgMode1314(Grid.init(T, &.{ 1, 1, 1, 0, 0, 0, 100, 3, 100 }, 3)));
            try std.testing.expectEqual(2, rgMode1314(Grid.init(T, &.{ 1, 1, 1, 0, 0, 0, 3, 100, 100 }, 3)));
        }

        /// RG15 - Bob mode, interpolates top field. Same as mode 13 but with a more complicated interpolation formula.
        /// RG16 - Bob mode, interpolates bottom field. Same as mode 14 but with a more complicated interpolation formula.
        fn rgMode1516(grid: Grid) T {
            const d1 = @abs(@as(SAT, grid.top_left) - grid.bottom_right);
            const d2 = @abs(@as(SAT, grid.top_center) - grid.bottom_center);
            const d3 = @abs(@as(SAT, grid.top_right) - grid.bottom_left);

            const mindiff = @min(d1, d2, d3);

            const average = if (types.isFloat(T))
                (2 * (@as(UAT, grid.top_center) + grid.bottom_center) + grid.top_left + grid.top_right + grid.bottom_left + grid.bottom_right) / 8
            else
                (2 * (@as(UAT, grid.top_center) + grid.bottom_center) + grid.top_left + grid.top_right + grid.bottom_left + grid.bottom_right + 4) / 8;

            if (mindiff == d2) {
                return math.lossyCast(T, std.math.clamp(average, @min(grid.top_center, grid.bottom_center), @max(grid.top_center, grid.bottom_center)));
            } else if (mindiff == d3) {
                return math.lossyCast(T, std.math.clamp(average, @min(grid.top_right, grid.bottom_left), @max(grid.top_right, grid.bottom_left)));
            }
            return math.lossyCast(T, std.math.clamp(average, @min(grid.top_left, grid.bottom_right), @max(grid.top_left, grid.bottom_right)));
        }

        test "RG Mode 15-16" {
            try std.testing.expectEqual(3, rgMode1516(Grid.init(T, &.{ 1, 1, 1, 0, 0, 0, 100, 100, 3 }, 3)));
            try std.testing.expectEqual(3, rgMode1516(Grid.init(T, &.{ 1, 1, 1, 0, 0, 0, 100, 3, 100 }, 3)));
            try std.testing.expectEqual(3, rgMode1516(Grid.init(T, &.{ 1, 1, 1, 0, 0, 0, 3, 100, 100 }, 3)));
        }

        /// Clips the pixel with the minimum and maximum of respectively the maximum and minimum of each pair of opposite neighbour pixels.
        fn rgMode17(grid: Grid) T {
            const sorted = grid.minMaxOppositesWithoutCenter();
            const l = @max(sorted.min1, sorted.min2, sorted.min3, sorted.min4);
            const u = @min(sorted.max1, sorted.max2, sorted.max3, sorted.max4);

            return std.math.clamp(grid.center_center, @min(l, u), @max(l, u));
        }

        test "RG Mode 17" {
            // Clip to the lowest maximum
            try std.testing.expectEqual(5, rgMode17(Grid.init(T, &.{ 1, 1, 1, 1, 10, 5, 6, 7, 8 }, 3)));

            // Clip to the highest minimum
            try std.testing.expectEqual(4, rgMode17(Grid.init(T, &.{ 1, 2, 3, 4, 0, 5, 5, 5, 5 }, 3)));
        }

        /// Line-sensitive clipping using opposite neighbours whose greatest distance from the current pixel is minimal.
        fn rgMode18(grid: Grid) T {
            const cT = @as(SAT, grid.center_center);
            const d1 = @max(@abs(cT - grid.top_left), @abs(cT - grid.bottom_right));
            const d2 = @max(@abs(cT - grid.top_center), @abs(cT - grid.bottom_center));
            const d3 = @max(@abs(cT - grid.top_right), @abs(cT - grid.bottom_left));
            const d4 = @max(@abs(cT - grid.center_left), @abs(cT - grid.center_right));

            const mindiff = @min(d1, d2, d3, d4);

            return if (mindiff == d4)
                std.math.clamp(grid.center_center, @min(grid.center_left, grid.center_right), @max(grid.center_left, grid.center_right))
            else if (mindiff == d2)
                std.math.clamp(grid.center_center, @min(grid.top_center, grid.bottom_center), @max(grid.top_center, grid.bottom_center))
            else if (mindiff == d3)
                std.math.clamp(grid.center_center, @min(grid.top_right, grid.bottom_left), @max(grid.top_right, grid.bottom_left))
            else
                std.math.clamp(grid.center_center, @min(grid.top_left, grid.bottom_right), @max(grid.top_left, grid.bottom_right));
        }

        test "RG Mode 18" {
            // a1 and a8 clipping.
            try std.testing.expectEqual(2, rgMode18(Grid.init(T, &.{ 2, 100, 100, 100, 1, 100, 100, 100, 3 }, 3)));
            try std.testing.expectEqual(3, rgMode18(Grid.init(T, &.{ 2, 100, 100, 100, 4, 100, 100, 100, 3 }, 3)));

            // a2 and a7 clipping.
            try std.testing.expectEqual(2, rgMode18(Grid.init(T, &.{ 100, 2, 100, 100, 1, 100, 100, 3, 100 }, 3)));
            try std.testing.expectEqual(3, rgMode18(Grid.init(T, &.{ 100, 2, 100, 100, 4, 100, 100, 3, 100 }, 3)));

            // a3 and a6 clipping
            try std.testing.expectEqual(2, rgMode18(Grid.init(T, &.{ 100, 100, 2, 100, 1, 100, 3, 100, 100 }, 3)));
            try std.testing.expectEqual(3, rgMode18(Grid.init(T, &.{ 100, 100, 2, 100, 4, 100, 3, 100, 100 }, 3)));

            // a4 and a5 clipping
            try std.testing.expectEqual(2, rgMode18(Grid.init(T, &.{ 100, 100, 100, 2, 1, 3, 100, 100, 100 }, 3)));
            try std.testing.expectEqual(3, rgMode18(Grid.init(T, &.{ 100, 100, 100, 2, 4, 3, 100, 100, 100 }, 3)));
        }

        /// Every pixel is replaced with the arithmetic mean of its 3x3 neighborhood,
        /// center pixel not included. In other words, the 8 neighbors are summed up
        /// and the sum is divided by 8.
        ///
        /// Identical to Convolution(matrix=[1, 1, 1, 1, 0, 1, 1, 1, 1])
        fn rgMode19(grid: Grid) T {
            const sum = @as(UAT, grid.top_left) + grid.top_center + grid.top_right + grid.center_left + grid.center_right + grid.bottom_left + grid.bottom_center + grid.bottom_right;

            return if (types.isFloat(T))
                sum / 8
            else
                @intCast((sum + 4) / 8);
        }

        test "RG Mode 19" {
            if (types.isFloat(T)) {
                try std.testing.expectEqual(4.5, rgMode19(Grid.init(T, &.{ 1, 2, 3, 4, 0, 5, 6, 7, 8 }, 3)));
            } else {
                try std.testing.expectEqual(5, rgMode19(Grid.init(T, &.{ 1, 2, 3, 4, 0, 5, 6, 7, 8 }, 3)));
            }
        }

        /// Every pixel is replaced with the arithmetic mean of its 3x3 neighborhood.
        /// In other words, all 9 pixels are summed up and the sum is divided by 9.
        ///
        /// Identical to Convolution(matrix=[1, 1, 1, 1, 1, 1, 1, 1, 1])
        fn rgMode20(grid: Grid) T {
            const sum = @as(UAT, grid.top_left) + grid.top_center + grid.top_right + grid.center_center + grid.center_left + grid.center_right + grid.bottom_left + grid.bottom_center + grid.bottom_right;

            return if (types.isFloat(T))
                sum / 9
            else
                @intCast((sum + 4) / 9);
        }

        test "RG Mode 20" {
            try std.testing.expectEqual(5, rgMode20(Grid.init(T, &.{ 1, 2, 3, 4, 9, 5, 6, 7, 8 }, 3)));
        }

        /// The center pixel is clipped to the smallest and the biggest average of the four surrounding pairs.
        fn rgMode21(grid: Grid) T {
            const l1l = (@as(UAT, grid.top_left) + grid.bottom_right) / 2;
            const l2l = (@as(UAT, grid.top_center) + grid.bottom_center) / 2;
            const l3l = (@as(UAT, grid.top_right) + grid.bottom_left) / 2;
            const l4l = (@as(UAT, grid.center_left) + grid.center_right) / 2;

            // Unused for integer
            const l1h = (@as(UAT, grid.top_left) + grid.bottom_right + 1) / 2;
            const l2h = (@as(UAT, grid.top_center) + grid.bottom_center + 1) / 2;
            const l3h = (@as(UAT, grid.top_right) + grid.bottom_left + 1) / 2;
            const l4h = (@as(UAT, grid.center_left) + grid.center_right + 1) / 2;

            const min = @min(l1l, l2l, l3l, l4l);
            const max = if (types.isInt(T))
                @max(l1h, l2h, l3h, l4h)
            else
                @max(l1l, l2l, l3l, l4l);

            return math.lossyCast(T, std.math.clamp(grid.center_center, min, max));
        }

        /// Same as mode 21 but simpler and faster. (rounding handled differently)
        /// Identical for floating point.
        fn rgMode22(grid: Grid) T {
            if (types.isFloat(T)) {
                return rgMode21(grid);
            }

            const l1 = (@as(UAT, grid.top_left) + grid.bottom_right + 1) / 2;
            const l2 = (@as(UAT, grid.top_center) + grid.bottom_center + 1) / 2;
            const l3 = (@as(UAT, grid.top_right) + grid.bottom_left + 1) / 2;
            const l4 = (@as(UAT, grid.center_left) + grid.center_right + 1) / 2;

            const min = @min(l1, l2, l3, l4);
            const max = @max(l1, l2, l3, l4);

            return math.lossyCast(T, std.math.clamp(grid.center_center, min, max));
        }

        test "RG Mode 21-22" {
            try std.testing.expectEqual(1, rgMode21(Grid.init(T, &.{ 1, 2, 3, 4, 0, 4, 3, 2, 1 }, 3)));
            try std.testing.expectEqual(4, rgMode21(Grid.init(T, &.{ 1, 2, 3, 4, 5, 4, 3, 2, 1 }, 3)));

            try std.testing.expectEqual(1, rgMode22(Grid.init(T, &.{ 1, 2, 3, 4, 0, 4, 3, 2, 1 }, 3)));
            try std.testing.expectEqual(4, rgMode22(Grid.init(T, &.{ 1, 2, 3, 4, 5, 4, 3, 2, 1 }, 3)));
        }

        /// Small edge and halo removal, but reportedly useless.
        fn rgMode23(grid: Grid) T {
            const sorted = grid.minMaxOppositesWithoutCenter();

            const linediff1 = sorted.max1 - sorted.min1;
            const linediff2 = sorted.max2 - sorted.min2;
            const linediff3 = sorted.max3 - sorted.min3;
            const linediff4 = sorted.max4 - sorted.min4;

            const cT = @as(SAT, grid.center_center);

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

            return math.lossyCast(T, grid.center_center - h + l);
        }

        /// Same as mode 23 but considerably more conservative and slightly slower. Preferred.
        fn rgMode24(grid: Grid) T {
            const sorted = grid.minMaxOppositesWithoutCenter();

            const linediff1 = sorted.max1 - sorted.min1;
            const linediff2 = sorted.max2 - sorted.min2;
            const linediff3 = sorted.max3 - sorted.min3;
            const linediff4 = sorted.max4 - sorted.min4;

            const cT = @as(SAT, grid.center_center);

            const th1 = cT - sorted.max1;
            const th2 = cT - sorted.max2;
            const th3 = cT - sorted.max3;
            const th4 = cT - sorted.max4;

            const h1 = @min(th1, linediff1 - th1);
            const h2 = @min(th2, linediff2 - th2);
            const h3 = @min(th3, linediff3 - th3);
            const h4 = @min(th4, linediff4 - th4);

            // Note: For YUV chroma planes, Avisynth uses 0 here, and RGSF uses -0.5.
            // In my testing, 0 appears visually correct and to match integer output.
            // -0.5 seems to break the image, and is likely a bug in RGSF.
            //
            // Reference:
            // * https://github.com/pinterf/RgTools/blob/a9cff29cb228b8a6fb52148f334554f4c3823798/RgTools/rg_functions_c.h#L1296
            // * https://github.com/IFeelBloated/RGSF/blob/master/RemoveGrain.cpp#L475
            const h = @max(0, h1, h2, h3, h4);

            const tl1 = sorted.min1 - cT;
            const tl2 = sorted.min2 - cT;
            const tl3 = sorted.min3 - cT;
            const tl4 = sorted.min4 - cT;

            const l1 = @min(tl1, linediff1 - tl1);
            const l2 = @min(tl2, linediff2 - tl2);
            const l3 = @min(tl3, linediff3 - tl3);
            const l4 = @min(tl4, linediff4 - tl4);
            const l = @max(0, l1, l2, l3, l4);

            return math.lossyCast(T, grid.center_center - h + l);
        }

        pub fn processPlaneScalar(mode: comptime_int, noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize, chroma: bool) void {
            // Copy the first line.
            @memcpy(dstp[0..width], srcp[0..width]);

            for (1..height - 1) |row| {
                // Handle interlacing (top field/bottom field) modes
                //
                // TODO: Skipping lines like this trashes performance, so modes 13, 14, 15, and 16 performance pretty poorly.
                // By comparison, RGVS is about 3-4x faster than this version, and its essentially doing the same thing.
                //
                // Example numbers on my 9950x: RGVS = ~500+fps, Zsmooth = ~120fps.
                //
                // So there's the potential for optimization here, even if it simply means upgrading to newer versions of Zig
                // that compile this into better code...
                if (shouldSkipLine(mode, row)) {
                    const currentLine = (row * stride);
                    @memcpy(dstp[currentLine..], srcp[currentLine..(currentLine + width)]);
                    continue;
                }

                // Copy the pixel at the beginning of the line.
                dstp[(row * stride)] = srcp[(row * stride)];
                for (1..width - 1) |w| {
                    const rowCurr = ((row) * stride);
                    const top_left = ((row - 1) * stride) + w - 1;

                    const grid = Grid.init(T, srcp[top_left..], math.lossyCast(u32, stride));

                    dstp[rowCurr + w] = switch (mode) {
                        1 => rgMode1(grid),
                        2 => rgMode2(grid),
                        3 => rgMode3(grid),
                        4 => rgMode4(grid),
                        5 => rgMode5(grid),
                        6 => rgMode6(grid, chroma),
                        7 => rgMode7(grid),
                        8 => rgMode8(grid, chroma),
                        9 => rgMode9(grid),
                        10 => rgMode10(grid),
                        11, 12 => rgMode1112(grid),
                        13, 14 => rgMode1314(grid),
                        15, 16 => rgMode1516(grid),
                        17 => rgMode17(grid),
                        18 => rgMode18(grid),
                        19 => rgMode19(grid),
                        20 => rgMode20(grid),
                        21 => rgMode21(grid),
                        22 => rgMode22(grid),
                        23 => rgMode23(grid),
                        24 => rgMode24(grid),
                        else => unreachable,
                    };
                }
                // Copy the pixel at the end of the line.
                dstp[(row * stride) + (width - 1)] = srcp[(row * stride) + (width - 1)];
            }

            // Copy the last line.
            const lastLine = ((height - 1) * stride);
            @memcpy(dstp[lastLine..], srcp[lastLine..(lastLine + width)]);
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
                    const dstp: []T = @as([*]T, @ptrCast(@alignCast(vsapi.?.getWritePtr.?(dst, plane))))[0..(height * stride)];
                    const chroma = d.vi.format.colorFamily == vs.ColorFamily.YUV and plane > 0;

                    // While these double switches may seem excessive at first glance, it's actually a substantial performance
                    // optimization. By having this switch operate at run time, process_plane_scalar can be
                    // optimized *at compile time* for *each* mode. This allows it to autovectorize each
                    // remove grain function for maximum performance.
                    //
                    // If I change the code to use function pointers, passing in the remove grain function into
                    // process_plane_scalar, FPS drops from 750+ to 48. Again, this is because the compiler can't
                    // properly optimize each RG function and its use in process_plane_scalar.
                    //
                    // Function pointers would likely work if I implemented a full @Vector support, but
                    // when the compiler can produce such performance code using my *scalar* implementation,
                    // there's literally no point for such an explosion in code.
                    //
                    // These double switches (see the other in process_plane_scalar, which operates at comptime)
                    // are a bit gratuitous but they are *FAST*.
                    switch (d.modes[_plane]) {
                        inline 1...24 => |mode| processPlaneScalar(mode, srcp, dstp, width, height, stride, chroma),
                        else => unreachable,
                    }
                }

                return dst;
            }

            return null;
        }
    };
}

export fn removeGrainFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *RemoveGrainData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn removeGrainCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    var d: RemoveGrainData = undefined;

    // TODO: Add error handling.
    var err: vs.MapPropertyError = undefined;

    d.node = vsapi.?.mapGetNode.?(in, "clip", 0, &err).?;
    d.vi = vsapi.?.getVideoInfo.?(d.node);

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

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("RemoveGrain", "clip:vnode;mode:int[]", "clip:vnode;", removeGrainCreate, null, plugin);
}
