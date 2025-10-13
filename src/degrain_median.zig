const std = @import("std");
const vapoursynth = @import("vapoursynth");
const ZAPI = vapoursynth.ZAPI;
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;

const string = @import("common/string.zig");
const types = @import("common/type.zig");
const math = @import("common/math.zig");
const vscmn = @import("common/vapoursynth.zig");
const vec = @import("common/vector.zig");
const grid = @import("common/grid.zig");
const copy = @import("common/copy.zig");
const float_mode: std.builtin.FloatMode = if (@import("config").optimize_float) .optimized else .strict;

const vs = vapoursynth.vapoursynth4;
const vsh = vapoursynth.vshelper;

const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;

const Grid = grid.Grid;

const allocator = std.heap.c_allocator;
const assert = std.debug.assert;

const DegrainMedianData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    vi: *const vs.VideoInfo,

    // Limit of the allowed pixel change.
    limit: [3]f32,
    // Processing mode, 0-5.
    mode: [3]u3,
    // Process as interlaced or not.
    interlaced: bool,
    // Include the pixels on the left/right of the current pixel in calculations.
    norow: bool,

    // Which planes we will process.
    process: [3]bool,
};

fn DegrainMedian(comptime T: type) type {
    const vector_len = vec.getVecSize(T);
    const VT = @Vector(vector_len, T);
    const UAT = switch (T) {
        u8 => u16,
        u16 => u32,
        f16 => f16, //TODO: This might be more performant as f32 on some systems.
        f32 => f32,
        else => unreachable,
    };

    return struct {
        // Grid of scalar values
        const GridS = Grid(T);
        // Grid of vector values
        const GridV = Grid(VT);

        // Note that `interlaced` is intentionally absent from this options
        // list. In my testing, having `interlaced` as a comptime known option
        // provided no speed benefit (when using vectorized algorithms), and
        // bloated the final library size from 4.5 MB -> 6.0 MB. I believe this
        // is because the `interlaced` option is high enough in the processing
        // loop that branch predictors can accurately guess which branch to
        // take (since its going to be the same for the entire frame, and thus
        // *always* the same branch being taken) and thus there's no real
        // performance penalty for having the "if interlaced" branch.
        const Options = packed struct(u4) {
            mode: u3 = 0,
            norow: bool = false,
        };

        const DegrainMedianOperation = enum(u4) {
            MODE_0 = @bitCast(Options{ .mode = 0 }),
            MODE_0_NOROW = @bitCast(Options{ .mode = 0, .norow = true }),

            MODE_1 = @bitCast(Options{ .mode = 1 }),
            MODE_1_NOROW = @bitCast(Options{ .mode = 1, .norow = true }),

            MODE_2 = @bitCast(Options{ .mode = 2 }),
            MODE_2_NOROW = @bitCast(Options{ .mode = 2, .norow = true }),

            MODE_3 = @bitCast(Options{ .mode = 3 }),
            MODE_3_NOROW = @bitCast(Options{ .mode = 3, .norow = true }),

            MODE_4 = @bitCast(Options{ .mode = 4 }),
            MODE_4_NOROW = @bitCast(Options{ .mode = 4, .norow = true }),

            MODE_5 = @bitCast(Options{ .mode = 5 }),
            MODE_5_NOROW = @bitCast(Options{ .mode = 5, .norow = true }),

            const Self = @This();

            pub fn processPlane(self: Self, srcp: [3][]const T, noalias dstp: []T, width: u32, height: u32, stride: u32, limit: T, pixel_min: T, pixel_max: T, interlaced: bool) void {
                switch (self) {
                    // inline else => |m| processPlaneScalar(m.getMode(), interlaced, m.getNoRow(), srcp, dstp, width, height, stride, limit, pixel_min, pixel_max),
                    inline else => |m| processPlaneVector(m.getMode(), interlaced, m.getNoRow(), srcp, dstp, width, height, stride, limit, pixel_min, pixel_max),
                }
            }

            pub fn init(mode: u3, norow: bool) Self {
                const value: u4 = @bitCast(Options{ .mode = mode, .norow = norow });
                return @enumFromInt(value);
            }

            pub fn getMode(self: Self) u3 {
                const options: Options = @bitCast(@intFromEnum(self));
                return options.mode;
            }

            pub fn getNoRow(self: Self) bool {
                const options: Options = @bitCast(@intFromEnum(self));
                return options.norow;
            }
        };

        //TODO: Use a new generic (Kernel?) to remove the *anytype*s.

        /// Limits the change (difference) of a pixel to be no greater or less than limit,
        /// and no greater than pixel_max or less than pixel_min.
        // fn limitPixelCorrectionScalar(old_pixel: T, new_pixel: T, limit: T, pixel_min: T, pixel_max: T) T
        fn limitPixelCorrection(old_pixel: anytype, new_pixel: anytype, limit: anytype, pixel_min: anytype, pixel_max: anytype) @TypeOf(new_pixel) {
            const lower = if (types.isInt(T))
                // Integer formats never go below zero
                // so we an use saturating subtraction.
                old_pixel -| limit
            else
                // Float formats can go to -0.5, for YUV
                // so we clamp to pixel_min.
                @max(pixel_min, old_pixel - limit);

            const upper = if (types.isInt(T))
                // Using saturating addition to prevent integer overflow.
                @min(old_pixel +| limit, pixel_max)
            else
                @min(old_pixel + limit, pixel_max);

            return @max(lower, @min(new_pixel, upper));
        }

        test limitPixelCorrection {
            // New pixel is lesser - within limit
            try std.testing.expectEqual(8, limitPixelCorrection(10, 8, 3, 0, 255));
            try std.testing.expectEqual(@as(VT, @splat(8)), limitPixelCorrection(@as(VT, @splat(10)), @as(VT, @splat(8)), @as(VT, @splat(3)), @as(VT, @splat(0)), @as(VT, @splat(255))));

            // New pixel is lesser - beyond limit (clamped)
            try std.testing.expectEqual(9, limitPixelCorrection(10, 8, 1, 0, 255));
            try std.testing.expectEqual(@as(VT, @splat(9)), limitPixelCorrection(@as(VT, @splat(10)), @as(VT, @splat(8)), @as(VT, @splat(1)), @as(VT, @splat(0)), @as(VT, @splat(255))));

            // New pixel is lesser - below pixel_min (clamped)
            if (types.isFloat(T)) {
                try std.testing.expectEqual(9, limitPixelCorrection(10, 8, 255, 9, 255));
                try std.testing.expectEqual(@as(VT, @splat(9)), limitPixelCorrection(@as(VT, @splat(10)), @as(VT, @splat(8)), @as(VT, @splat(255)), @as(VT, @splat(9)), @as(VT, @splat(255))));
            }

            // New pixel is greater - within limit
            try std.testing.expectEqual(12, limitPixelCorrection(10, 12, 3, 0, 255));
            try std.testing.expectEqual(@as(VT, @splat(12)), limitPixelCorrection(@as(VT, @splat(10)), @as(VT, @splat(12)), @as(VT, @splat(3)), @as(VT, @splat(0)), @as(VT, @splat(255))));

            // New pixel is greater - beyond limit (clamped)
            try std.testing.expectEqual(11, limitPixelCorrection(10, 12, 1, 0, 255));
            try std.testing.expectEqual(@as(VT, @splat(11)), limitPixelCorrection(@as(VT, @splat(10)), @as(VT, @splat(12)), @as(VT, @splat(1)), @as(VT, @splat(0)), @as(VT, @splat(255))));

            // New pixel is greater - above pixel_max (clamped)
            try std.testing.expectEqual(11, limitPixelCorrection(10, 12, 255, 0, 11));
            try std.testing.expectEqual(@as(VT, @splat(11)), limitPixelCorrection(@as(VT, @splat(10)), @as(VT, @splat(12)), @as(VT, @splat(255)), @as(VT, @splat(0)), @as(VT, @splat(11))));
        }

        /// Computes the absolute difference of two pixels, and if the
        /// difference is less than the provided diff param, it updates
        /// the diff param, as well as the min and max params with their
        /// corresponding values of the two pixels.
        // fn checkBetterNeighorsScalar(a: T, b: T, diff: *T, min: *T, max: *T) void
        fn checkBetterNeighbors(a: anytype, b: anytype, diff: anytype, min: anytype, max: anytype) void {
            const newdiff = math.absDiff(a, b);

            if (types.isScalar(@TypeOf(a))) {
                // scalar
                if (newdiff <= diff.*) {
                    diff.* = newdiff;
                    min.* = @min(a, b);
                    max.* = @max(a, b);
                }
            } else {
                // vector
                diff.* = vec.minFast(newdiff, diff.*);
                min.* = @select(T, newdiff <= diff.*, @min(a, b), min.*);
                max.* = @select(T, newdiff <= diff.*, @max(a, b), max.*);
            }
        }

        test checkBetterNeighbors {
            var diff: T = 255;
            var diffV: VT = @splat(255);
            var max: T = 255;
            var maxV: VT = @splat(255);
            var min: T = 0;
            var minV: VT = @splat(0);

            checkBetterNeighbors(10, 7, &diff, &min, &max);
            checkBetterNeighbors(@as(VT, @splat(10)), @as(VT, @splat(7)), &diffV, &minV, &maxV);
            try std.testing.expectEqualDeep(.{ 3, 7, 10 }, .{ diff, min, max });
            try std.testing.expectEqualDeep(.{ @as(VT, @splat(3)), @as(VT, @splat(7)), @as(VT, @splat(10)) }, .{ diffV, minV, maxV });

            diff = 255;
            diffV = @splat(255);
            max = 255;
            maxV = @splat(255);
            min = 0;
            minV = @splat(0);

            // Ensure pixel value order doesn't matter, which ensures we use @abs
            checkBetterNeighbors(7, 10, &diff, &min, &max);
            checkBetterNeighbors(@as(VT, @splat(7)), @as(VT, @splat(10)), &diffV, &minV, &maxV);
            try std.testing.expectEqualDeep(.{ 3, 7, 10 }, .{ diff, min, max });
            try std.testing.expectEqualDeep(.{ @as(VT, @splat(3)), @as(VT, @splat(7)), @as(VT, @splat(10)) }, .{ diffV, minV, maxV });

            diff = 5;
            diffV = @splat(5);
            max = 255;
            maxV = @splat(255);
            min = 0;
            minV = @splat(0);

            // Ensure that if the difference is greater than diff param,
            // nothing gets updated.
            checkBetterNeighbors(0, 255, &diff, &min, &max);
            checkBetterNeighbors(@as(VT, @splat(0)), @as(VT, @splat(255)), &diffV, &minV, &maxV);
            try std.testing.expectEqualDeep(.{ 5, 0, 255 }, .{ diff, min, max });
            try std.testing.expectEqualDeep(.{ @as(VT, @splat(5)), @as(VT, @splat(0)), @as(VT, @splat(255)) }, .{ diffV, minV, maxV });
        }

        //TODO: Add tests?
        fn diagWeight(comptime mode: u3, old_pixel: anytype, a: anytype, b: anytype, old_result: anytype, old_weight: anytype, pixel_min: anytype, pixel_max: anytype) void {
            const R = @TypeOf(a);
            const U = if (types.isScalar(R)) UAT else @Vector(vector_len, UAT);

            var new_pixel: U = @max(a, b);
            var weight: U = @min(a, b);

            const pixel_clamped_diff = if (types.isInt(T))
                old_pixel -| new_pixel
            else
                @max(old_pixel - new_pixel, pixel_min);

            new_pixel = @max(weight, @min(old_pixel, new_pixel));
            weight = if (types.isInt(T))
                weight -| old_pixel
            else
                @max(weight - old_pixel, pixel_min);

            weight = @max(weight, pixel_clamped_diff);

            // Mode 1-4 require additional calculations,
            // Mode 5 just jumps to weight <= old_weight
            if (mode != 5) {
                var neighbor_abs_diff: U = math.absDiff(a, b);

                // TODO: Find out why this is slower than DGM plugin
                //
                // Don't need to clamp float, since later calculations
                // clamp inherently.
                if (mode == 4) {
                    // Weight * 2
                    weight = if (types.isInt(U))
                        weight +| weight
                    else
                        weight + weight;
                } else if (mode == 2) {
                    // neighbor_abs_diff * 2
                    neighbor_abs_diff = if (types.isInt(T))
                        neighbor_abs_diff +| neighbor_abs_diff
                    else
                        neighbor_abs_diff + neighbor_abs_diff;
                } else if (mode == 1) {
                    // neighbor_abs_diff * 4
                    neighbor_abs_diff = if (types.isInt(T))
                        neighbor_abs_diff +| neighbor_abs_diff +| neighbor_abs_diff +| neighbor_abs_diff
                    else
                        neighbor_abs_diff + neighbor_abs_diff + neighbor_abs_diff + neighbor_abs_diff;
                }

                weight = if (types.isInt(T))
                    @min(weight +| neighbor_abs_diff, pixel_max)
                else
                    @min(weight + neighbor_abs_diff, pixel_max);
            }

            if (types.isScalar(R)) {
                if (weight <= old_weight.*) {
                    old_weight.* = math.lossyCast(T, weight);
                    old_result.* = math.lossyCast(T, new_pixel);
                }
            } else {
                old_weight.* = @select(T, weight <= old_weight.*, math.lossyCast(VT, weight), old_weight.*);
                old_result.* = @select(T, weight <= old_weight.*, math.lossyCast(VT, new_pixel), old_result.*);
            }
        }

        /// Essentially a spatial-temporal, line-sensitive, limited, clipping function.
        ///
        /// Compares the current pixel's neighbors (diagonal, vertical, and horizontal) in both temporal
        /// (previous, next frames) and spatial (current frame) domains. Whenever the pixels being compared
        /// have a difference less than the current known minimum difference, the minimum difference is updated
        /// and new min/max values are calculated.
        ///
        /// Next, the min and max values are used to clamp the current pixel.
        ///
        /// Finally, the clamped result is limited according to the `limit` parameter.
        ///
        /// Similar to RemoveGrain mode 9.
        ///
        // fn mode0Scalar(prev: GridS, current: GridS, next: GridS, limit: T, pixel_min: T, pixel_max: T) T {
        fn mode0(comptime norow: bool, prev: anytype, current: anytype, next: anytype, limit: anytype, pixel_min: anytype, pixel_max: anytype) @TypeOf(pixel_max) {
            @setFloatMode(float_mode);

            const R = @TypeOf(pixel_max);
            var diff: R = pixel_max;
            var max: R = pixel_max;
            var min: R = if (types.isScalar(R)) 0 else @splat(0);

            // Check the diagonals of the temporal neighbors.
            checkBetterNeighbors(next.top_left, prev.bottom_right, &diff, &min, &max);
            checkBetterNeighbors(next.top_right, prev.bottom_left, &diff, &min, &max);
            checkBetterNeighbors(next.bottom_left, prev.top_right, &diff, &min, &max);
            checkBetterNeighbors(next.bottom_right, prev.top_left, &diff, &min, &max);

            // Check the verticals of the temporal neighbors.
            checkBetterNeighbors(next.bottom_center, prev.top_center, &diff, &min, &max);
            checkBetterNeighbors(next.top_center, prev.bottom_center, &diff, &min, &max);

            // Check the horizontals of the temporal neighbors.
            checkBetterNeighbors(next.center_left, prev.center_right, &diff, &min, &max);
            checkBetterNeighbors(next.center_right, prev.center_left, &diff, &min, &max);

            // Check the center of the temporal neighbors.
            checkBetterNeighbors(next.center_center, prev.center_center, &diff, &min, &max);

            // Check the diagonals of the current frame.
            checkBetterNeighbors(current.top_left, current.bottom_right, &diff, &min, &max);
            checkBetterNeighbors(current.top_right, current.bottom_left, &diff, &min, &max);

            // Check the vertical of the current frame.
            checkBetterNeighbors(current.top_center, current.bottom_center, &diff, &min, &max);

            // Include the left/right pixels on the same line if the 'norow' option is disabled.
            if (!norow) {
                checkBetterNeighbors(current.center_left, current.center_right, &diff, &min, &max);
            }

            const result = math.clamp(current.center_center, min, max);

            return limitPixelCorrection(current.center_center, result, limit, pixel_min, pixel_max);
        }

        //TODO: Add tests?
        fn mode1to5(comptime mode: u3, comptime norow: bool, prev: anytype, current: anytype, next: anytype, limit: anytype, pixel_min: anytype, pixel_max: anytype) @TypeOf(pixel_max) {
            @setFloatMode(float_mode);

            const R = @TypeOf(pixel_max);

            var result: R = if (types.isScalar(R)) 0 else @splat(0);
            var weight = pixel_max;

            //Compare the neighbors of the current frame.
            diagWeight(mode, current.center_center, current.top_left, current.bottom_right, &result, &weight, pixel_min, pixel_max);
            diagWeight(mode, current.center_center, current.bottom_left, current.top_right, &result, &weight, pixel_min, pixel_max);
            diagWeight(mode, current.center_center, current.bottom_center, current.top_center, &result, &weight, pixel_min, pixel_max);

            if (!norow) {
                diagWeight(mode, current.center_center, current.center_left, current.center_right, &result, &weight, pixel_min, pixel_max);
            }

            //Compare the diagonals of the next and previous frames.
            diagWeight(mode, current.center_center, next.top_left, prev.bottom_right, &result, &weight, pixel_min, pixel_max);
            diagWeight(mode, current.center_center, next.top_right, prev.bottom_left, &result, &weight, pixel_min, pixel_max);
            diagWeight(mode, current.center_center, next.bottom_left, prev.top_right, &result, &weight, pixel_min, pixel_max);
            diagWeight(mode, current.center_center, next.bottom_right, prev.top_left, &result, &weight, pixel_min, pixel_max);

            // Compare the verticals
            diagWeight(mode, current.center_center, next.bottom_center, prev.top_center, &result, &weight, pixel_min, pixel_max);
            diagWeight(mode, current.center_center, next.top_center, prev.bottom_center, &result, &weight, pixel_min, pixel_max);

            // Compare the horizontals
            diagWeight(mode, current.center_center, next.center_left, prev.center_right, &result, &weight, pixel_min, pixel_max);
            diagWeight(mode, current.center_center, next.center_right, prev.center_left, &result, &weight, pixel_min, pixel_max);
            diagWeight(mode, current.center_center, next.center_center, prev.center_center, &result, &weight, pixel_min, pixel_max);

            return limitPixelCorrection(current.center_center, result, limit, pixel_min, pixel_max);
        }

        fn processPlaneScalar(comptime mode: u8, interlaced: bool, comptime norow: bool, srcp: [3][]const T, noalias dstp: []T, width: u32, height: u32, stride: u32, limit: T, pixel_min: T, pixel_max: T) void {
            const skip_rows = @as(u8, 1) << @intFromBool(interlaced);

            // Copy the first and second lines, first only if not interlaced.
            {
                var row: u32 = 0;
                while (row < skip_rows) : (row += 1) {
                    const line = row * stride;
                    const end = line + width;
                    @memcpy(dstp[line..end], srcp[1][line..end]);
                }
            }

            for (skip_rows..height - skip_rows) |row| {
                // Copy the pixel at the beginning of the line.
                dstp[(row * stride)] = srcp[1][(row * stride)];

                for (1..width - 1) |column| {
                    const current_pixel = row * stride + column;
                    // We're loading pixels from the top left of a 3x3 grid centered around
                    // the current pixel of interest.
                    //
                    // So we subtract the stride from the current pixel location to get the row
                    // above, and then subtract 1 to get the pixel in the top left, instead of the top center.
                    //
                    // All of this is to make loading from Grid.init easier.
                    const offset = if (interlaced)
                        current_pixel - (stride * 2) - 1
                    else
                        current_pixel - stride - 1;

                    const prev = if (interlaced)
                        GridS.initInterlaced(T, srcp[0][offset..], stride)
                    else
                        GridS.init(T, srcp[0][offset..], stride);

                    const current = if (interlaced)
                        GridS.initInterlaced(T, srcp[1][offset..], stride)
                    else
                        GridS.init(T, srcp[1][offset..], stride);

                    const next = if (interlaced)
                        GridS.initInterlaced(T, srcp[2][offset..], stride)
                    else
                        GridS.init(T, srcp[2][offset..], stride);

                    dstp[current_pixel] = switch (mode) {
                        0 => mode0(norow, prev, current, next, limit, pixel_min, pixel_max),
                        1...5 => |m| mode1to5(m, norow, prev, current, next, limit, pixel_min, pixel_max),
                        else => unreachable,
                    };
                }

                // Copy the pixel at the end of the line.
                dstp[(row * stride) + (width - 1)] = srcp[1][(row * stride) + (width - 1)];
            }

            // Copy the last lines, second to last and last if interlaced, just last if not interlaced
            var row = (height - skip_rows);
            while (row < height) : (row += 1) {
                const line = row * stride;
                const end = line + width;
                @memcpy(dstp[line..end], srcp[1][line..end]);
            }
        }

        fn processPlaneVector(comptime mode: u8, interlaced: bool, comptime norow: bool, srcp: [3][]const T, noalias dstp: []T, width: u32, height: u32, stride: u32, _limit: T, _pixel_min: T, _pixel_max: T) void {
            // TODO: Consider replacing all uses of '1' with 'grid_radius', since
            // that's what it actually means.
            const grid_radius = comptime (3 / 2); // Diameter of 3 frames, cut in half to get radius.

            // We need to make sure we don't read past the edge of the frame.
            // So we take into account the size of vector and the size of the grid we
            // need to load, and work backwards (subtract) from the overall frame size
            // to calculate a safe width.
            const width_simd = (width - grid_radius) / vector_len * vector_len;

            const limit: VT = @splat(_limit);
            const pixel_min: VT = @splat(_pixel_min);
            const pixel_max: VT = @splat(_pixel_max);

            const skip_rows = @as(u8, 1) << @intFromBool(interlaced);

            // Copy the first and second lines, first only if not interlaced.
            copy.copyFirstNLines(T, dstp, srcp[1], width, stride, skip_rows);

            // Compiler optimizer hints
            // These assertions honestly seems to lead to some nice speedups.
            // I'm seeing a difference of ~190 -> ~200fps, single core.
            assert(width >= vector_len);
            assert(stride >= width);
            assert(stride % vector_len == 0);

            for (skip_rows..height - skip_rows) |row| {
                // Copy the pixel at the beginning of the line.
                dstp[(row * stride)] = srcp[1][(row * stride)];

                var column: usize = 1;
                while (column < width_simd) : (column += vector_len) {
                    const current_pixel = row * stride + column;
                    // Target the offset at the pixel in the top left;
                    const grid_offset = if (interlaced)
                        current_pixel - (stride * 2) - 1
                    else
                        current_pixel - stride - 1;

                    const prev = if (interlaced)
                        GridV.initInterlaced(T, srcp[0][grid_offset..], stride)
                    else
                        GridV.init(T, srcp[0][grid_offset..], stride);

                    const current = if (interlaced)
                        GridV.initInterlaced(T, srcp[1][grid_offset..], stride)
                    else
                        GridV.init(T, srcp[1][grid_offset..], stride);

                    const next = if (interlaced)
                        GridV.initInterlaced(T, srcp[2][grid_offset..], stride)
                    else
                        GridV.init(T, srcp[2][grid_offset..], stride);

                    const result = switch (mode) {
                        0 => mode0(norow, prev, current, next, limit, pixel_min, pixel_max),
                        1...5 => |m| mode1to5(m, norow, prev, current, next, limit, pixel_min, pixel_max),
                        else => unreachable,
                    };

                    vec.store(VT, dstp, current_pixel, result);
                }

                // If the video width is not perfectly aligned with the vector width, do one
                // last operation at the end of the plane to cover what's leftover from the loop above.
                if (width_simd < width) {
                    const current_pixel = row * stride + width - vector_len - grid_radius;
                    // Target the offset at the pixel in the top left;
                    const grid_offset = if (interlaced)
                        current_pixel - (stride * 2) - 1
                    else
                        current_pixel - stride - 1;

                    const prev = if (interlaced)
                        GridV.initInterlaced(T, srcp[0][grid_offset..], stride)
                    else
                        GridV.init(T, srcp[0][grid_offset..], stride);

                    const current = if (interlaced)
                        GridV.initInterlaced(T, srcp[1][grid_offset..], stride)
                    else
                        GridV.init(T, srcp[1][grid_offset..], stride);

                    const next = if (interlaced)
                        GridV.initInterlaced(T, srcp[2][grid_offset..], stride)
                    else
                        GridV.init(T, srcp[2][grid_offset..], stride);

                    const result = switch (mode) {
                        0 => mode0(norow, prev, current, next, limit, pixel_min, pixel_max),
                        1...5 => |m| mode1to5(m, norow, prev, current, next, limit, pixel_min, pixel_max),
                        else => unreachable,
                    };

                    vec.store(VT, dstp, current_pixel, result);
                }

                // Copy the pixel at the end of the line.
                dstp[(row * stride) + (width - 1)] = srcp[1][(row * stride) + (width - 1)];
            }

            // Copy the last lines, second to last and last if interlaced, just last if not interlaced
            copy.copyLastNLines(T, dstp, srcp[1], width, height, stride, skip_rows);
        }

        fn processPlane(mode: u3, norow: bool, _limit: f32, interlaced: bool, _pixel_min: f32, _pixel_max: f32, noalias dstp8: []u8, srcp8: [3][]const u8, width: u32, height: u32, stride8: u32) void {
            const stride = stride8 / @sizeOf(T);
            const srcp: [3][]const T = .{
                @ptrCast(@alignCast(srcp8[0])),
                @ptrCast(@alignCast(srcp8[1])),
                @ptrCast(@alignCast(srcp8[2])),
            };
            const dstp: []T = @ptrCast(@alignCast(dstp8));

            const limit: T  = math.lossyCast(T, _limit);
            const pixel_min: T = math.lossyCast(T, _pixel_min);
            const pixel_max: T = math.lossyCast(T, _pixel_max);

            DegrainMedianOperation.init(mode, norow)
                .processPlane(srcp, dstp, width, height, stride, limit, pixel_min, pixel_max, interlaced);
        }
    };
}

fn degrainMedianGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const zapi = ZAPI.init(vsapi, core, frame_ctx);
    const d: *const DegrainMedianData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        // Request previous, current, and next frames.
        zapi.requestFrameFilter(@max(0, n - 1), d.node);
        zapi.requestFrameFilter(n, d.node);
        zapi.requestFrameFilter(@min(n + 1, d.vi.numFrames - 1), d.node);
    } else if (activation_reason == ar.AllFramesReady) {
        // Skip filtering on the first and last frames that lie inside the filter radius,
        // since we do not have enough information to filter them properly.
        if (n == 0 or n == d.vi.numFrames - 1) {
            return zapi.getFrameFilter(n, d.node);
        }

        const src_frames = [3]ZAPI.ZFrame(*const vs.Frame){
            zapi.initZFrame(d.node, n - 1),
            zapi.initZFrame(d.node, n),
            zapi.initZFrame(d.node, n + 1),
        };
        defer for (src_frames) |frame| frame.deinit();

        const dst = src_frames[1].newVideoFrame2(d.process);

        const processPlane = switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &DegrainMedian(u8).processPlane,
            .U16 => &DegrainMedian(u16).processPlane,
            .F16 => &DegrainMedian(f16).processPlane,
            .F32 => &DegrainMedian(f32).processPlane,
        };

        for (0..3) |plane| {

            // Skip planes we aren't supposed to process
            if (!d.process[plane]) {
                continue;
            }

            const width= dst.getWidth(plane);
            const height= dst.getHeight(plane);
            const stride8= dst.getStride(plane);

            const srcp8 = [3][]const u8{
                src_frames[0].getReadSlice(plane),
                src_frames[1].getReadSlice(plane),
                src_frames[2].getReadSlice(plane),
            };
            const dstp8 = dst.getWriteSlice(plane);

            const pixel_min = vscmn.getFormatMinimum(f32, d.vi.format, plane > 0);
            const pixel_max = vscmn.getFormatMaximum(f32, d.vi.format, plane > 0);

            processPlane(d.mode[plane], d.norow, d.limit[plane], d.interlaced, pixel_min, pixel_max, dstp8, srcp8, width, height, stride8);
        }

        return dst.frame;
    }

    return null;
}

export fn degrainMedianFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = core;
    const d: *DegrainMedianData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn degrainMedianCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = user_data;

    const zapi = ZAPI.init(vsapi, core, null);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);

    var d: DegrainMedianData = undefined;

    d.node, d.vi = inz.getNodeVi("clip").?;

    if (!vsh.isConstantVideoFormat(d.vi) or
        (d.vi.format.colorFamily != vs.ColorFamily.YUV and
            d.vi.format.colorFamily != vs.ColorFamily.RGB and
            d.vi.format.colorFamily != vs.ColorFamily.Gray))
    {
        return vscmn.reportError2("DegrainMedian: only constant format YUV, RGB or Grey input is supported", zapi, outz, d.node);
    }

    const vector_len = vscmn.formatVectorLength(d.vi.format);
    if (d.vi.width < vector_len) {
        return vscmn.reportError2(string.printf(allocator,
            \\DegrainMedian: For performance reasons, DegrainMedian does not support clip widths under {} for this sample type. 
            \\If you have good reason to process such small clips, please open an issue describing your use csae.
        , .{vector_len}), zapi, outz, d.node);
    }

    d.interlaced = inz.getBool("interlaced") orelse false;
    d.norow = inz.getBool("norow") orelse false;

    const scalep = inz.getBool("scalep") orelse false;

    const num_limits = inz.numElements("limit") orelse 0;
    if (num_limits > math.lossyCast(u32, d.vi.format.numPlanes)) {
        return vscmn.reportError("DegrainMedian: limit has more elements than there are planes.", vsapi, out, d.node);
    }

    d.limit = [3]f32{ 4, 4, 4 };

    for (0..3) |i| {
        if (inz.getFloat2(f32, "limit", i)) |_limit| {
            if (scalep and (_limit < 0 or _limit > 255)) {
                return vscmn.reportError2(string.printf(allocator, "DegrainMedian: Using parameter scaling (scalep), but limit value of {d} is outside the range of 0-255", .{_limit}), zapi, outz, d.node);
            }

            const formatMaximum = vscmn.getFormatMaximum(f32, d.vi.format, i > 0);
            const formatMinimum = vscmn.getFormatMinimum(f32, d.vi.format, i > 0);

            const limit = if (scalep)
                // vscmn.scaleToFormat(f32, d.vi.format, @intFromFloat(_limit), 0)
                // The original VS plugin uses a slightly different scaling
                // method than I've seen before.
                // I've matched that here to ensure identical output.
                formatMaximum * _limit / 255
            else
                _limit;

            if ((limit < formatMinimum or limit > formatMaximum)) {
                return vscmn.reportError2(string.printf(allocator, "DegrainMedian: Index {d} limit '{d}' must be between {d} and {d} (inclusive)", .{ i, limit, formatMinimum, formatMaximum }), zapi, outz, d.node);
            }

            d.limit[i] = limit;
        } else {
            // No limit specified for this plane
            if (i > 0) {
                d.limit[i] = d.limit[i - 1];
            }
        }
    }

    if (d.limit[0] == 0 and d.limit[1] == 0 and d.limit[2] == 0) {
        return vscmn.reportError2("DegrainMedian: All limits cannot be 0.", zapi, outz, d.node);
    }

    d.process = [_]bool{
        d.limit[0] > 0,
        d.limit[1] > 0,
        d.limit[2] > 0,
    };

    const num_modes = inz.numElements("mode") orelse 0;
    if (num_modes > math.lossyCast(u32, d.vi.format.numPlanes)) {
        return vscmn.reportError2("DegrainMedian: mode has more elements than there are planes.", zapi, outz, d.node);
    }

    d.mode = [3]u3{ 1, 1, 1 };

    for (0..3) |i| {
        if (inz.getInt2(i32, "mode", i)) |mode| {
            if (mode < 0 or mode > 5) {
                return vscmn.reportError2("DegrainMedian: Mode cannot be less than 0 or greater than 5.", zapi, outz, d.node);
            }
            d.mode[i] = @intCast(mode);
        } else {
            // No mode specified for this plane.
            if (i > 0) {
                d.mode[i] = d.mode[i - 1];
            }
        }
    }

    const data: *DegrainMedianData = allocator.create(DegrainMedianData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.General,
        },
    };

    zapi.createVideoFilter(out, "DegrainMedian", d.vi, degrainMedianGetFrame, degrainMedianFree, fm.Parallel, &deps, data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("DegrainMedian", "clip:vnode;limit:float[]:opt;mode:int[]:opt;interlaced:int:opt;norow:int:opt;scalep:int:opt", "clip:vnode;", degrainMedianCreate, null, plugin);
}
