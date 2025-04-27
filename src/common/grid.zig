const std = @import("std");
const vec = @import("vector.zig");
const sort = @import("sorting_networks.zig");

/// Encapsulates data for a 3x3 or 5x5 grid of pixels.
pub fn Grid(comptime T: type, comptime side_length: comptime_int) type {
    std.debug.assert(side_length == 3 or side_length == 5);

    return struct {
        far_top_far_left: T = undefined,
        far_top_left: T = undefined,
        far_top_center: T = undefined,
        far_top_right: T = undefined,
        far_top_far_right: T = undefined,

        top_far_left: T = undefined,
        top_left: T,
        top_center: T,
        top_right: T,
        top_far_right: T = undefined,

        center_far_left: T = undefined,
        center_left: T,
        center_center: T,
        center_right: T,
        center_far_right: T = undefined,

        bottom_far_left: T = undefined,
        bottom_left: T,
        bottom_center: T,
        bottom_right: T,
        bottom_far_right: T = undefined,

        far_bottom_far_left: T = undefined,
        far_bottom_left: T = undefined,
        far_bottom_center: T = undefined,
        far_bottom_right: T = undefined,
        far_bottom_far_right: T = undefined,

        const Self = @This();

        /// Loads a Grid from a slice of elements of type R, starting at the
        /// slice's index 0, and then jumping in slice by stride
        /// to access each row.
        ///
        /// Note that types R and T are not identical. We can create a grid of vectors,
        /// where the vector type is T, but from a slice of pixels which have type R.
        // TODO: Rename to `initFromTopLeft`
        pub fn init(comptime R: type, slice: []const R, stride: usize) Self {
            if (side_length != 3) {
                @compileError("Grid.init is currently only implemented for side length 3");
            }

            // Vector
            if (@typeInfo(T) == .Vector) {
                return Self{
                    .top_left = vec.load(T, slice, 0),
                    .top_center = vec.load(T, slice, 1),
                    .top_right = vec.load(T, slice, 2),

                    .center_left = vec.load(T, slice, stride),
                    .center_center = vec.load(T, slice, stride + 1),
                    .center_right = vec.load(T, slice, stride + 2),

                    .bottom_left = vec.load(T, slice, (stride * 2)),
                    .bottom_center = vec.load(T, slice, (stride * 2) + 1),
                    .bottom_right = vec.load(T, slice, (stride * 2) + 2),
                };
            }

            // Scalar
            return Self{
                .top_left = slice[0],
                .top_center = slice[1],
                .top_right = slice[2],

                .center_left = slice[stride..][0],
                .center_center = slice[stride..][1],
                .center_right = slice[stride..][2],

                .bottom_left = slice[stride * 2 ..][0],
                .bottom_center = slice[stride * 2 ..][1],
                .bottom_right = slice[stride * 2 ..][2],
            };
        }

        /// Loads data around a center pixel, using mirroring to fill in all missing pixels.
        /// Note tha for maximum performance, this function should *ONLY* be used on edge pixels.
        /// Using it on pixels that actually have pertinent data leads to crap performance and is completely unnecessary.
        pub fn initFromCenterMirrored(comptime R: type, row: usize, column: usize, width: usize, height: usize, slice: []const R, stride: usize) Self {
            const rowT: i32 = @intCast(row);
            const columnT: i32 = @intCast(column);

            switch (comptime side_length) {
                3 => {
                    // Cheap mirroring
                    // const rowAbove = if (rowT - 1 < 0) @abs(rowT - 1) else row - 1;
                    // const rowBelow = if (row + 1 >= height) 2 * (height - 1) - (row + 1) else row + 1;
                    const rowAbove = @abs(rowT - 1);
                    const rowBelow = @min(2 * (height - 1) - (row + 1), row + 1);

                    // const columnLeft = if (columnT - 1 < 0) @abs(columnT - 1) else column - 1;
                    // const columnRight = if (column + 1 >= width) 2 * (width - 1) - (column + 1) else column + 1;
                    const columnLeft = @abs(columnT - 1);
                    const columnRight = @min(2 * (width - 1) - (column + 1), column + 1);

                    // Scalar
                    return Self{
                        .top_left = slice[(rowAbove * stride) + columnLeft],
                        .top_center = slice[(rowAbove * stride) + column],
                        .top_right = slice[(rowAbove * stride) + columnRight],

                        .center_left = slice[(row * stride) + columnLeft],
                        .center_center = slice[(row * stride) + column],
                        .center_right = slice[(row * stride) + columnRight],

                        .bottom_left = slice[(rowBelow * stride) + columnLeft],
                        .bottom_center = slice[(rowBelow * stride) + column],
                        .bottom_right = slice[(rowBelow * stride) + columnRight],
                    };
                },
                5 => {
                    const rowFarAbove = @abs(rowT - 2);
                    const rowAbove = @abs(rowT - 1);

                    const rowBelow = @min(2 * (height - 1) - (row + 1), row + 1);
                    const rowFarBelow = @min(2 * (height - 1) - (row + 2), row + 2);

                    const columnFarLeft = @abs(columnT - 2);
                    const columnLeft = @abs(columnT - 1);

                    const columnRight = @min(2 * (width - 1) - (column + 1), column + 1);
                    const columnFarRight = @min(2 * (width - 1) - (column + 2), column + 2);

                    // Scalar
                    return Self{
                        .far_top_far_left = slice[(rowFarAbove) * stride + columnFarLeft],
                        .far_top_left = slice[(rowFarAbove) * stride + columnLeft],
                        .far_top_center = slice[(rowFarAbove) * stride + column],
                        .far_top_right = slice[(rowFarAbove) * stride + columnRight],
                        .far_top_far_right = slice[(rowFarAbove) * stride + columnFarRight],

                        .top_far_left = slice[(rowAbove * stride) + columnFarLeft],
                        .top_left = slice[(rowAbove * stride) + columnLeft],
                        .top_center = slice[(rowAbove * stride) + column],
                        .top_right = slice[(rowAbove * stride) + columnRight],
                        .top_far_right = slice[(rowAbove * stride) + columnFarRight],

                        .center_far_left = slice[(row * stride) + columnFarLeft],
                        .center_left = slice[(row * stride) + columnLeft],
                        .center_center = slice[(row * stride) + column],
                        .center_right = slice[(row * stride) + columnRight],
                        .center_far_right = slice[(row * stride) + columnFarRight],

                        .bottom_far_left = slice[(rowBelow * stride) + columnFarLeft],
                        .bottom_left = slice[(rowBelow * stride) + columnLeft],
                        .bottom_center = slice[(rowBelow * stride) + column],
                        .bottom_right = slice[(rowBelow * stride) + columnRight],
                        .bottom_far_right = slice[(rowBelow * stride) + columnFarRight],

                        .far_bottom_far_left = slice[(rowFarBelow) * stride + columnFarLeft],
                        .far_bottom_left = slice[(rowFarBelow) * stride + columnLeft],
                        .far_bottom_center = slice[(rowFarBelow) * stride + column],
                        .far_bottom_right = slice[(rowFarBelow) * stride + columnRight],
                        .far_bottom_far_right = slice[(rowFarBelow) * stride + columnFarRight],
                    };
                },
                else => unreachable,
            }
        }

        /// Loads data around a center pixel.
        //This seems *slightly* slower than `init` for some reason, at least on 0.12.1.
        //I'm seeing ~900fps (+/- 10fps) from `init`, while ~850fps from this function.
        pub fn initFromCenter(comptime R: type, row: u32, column: u32, slice: []const R, stride: u32) Self {
            if (side_length != 3) {
                @compileError("Grid.initFromCenter is currently only implemented for side length 3");
            }

            // Scalar
            return Self{
                .top_left = slice[((row - 1) * stride) + column - 1],
                .top_center = slice[((row - 1) * stride) + column],
                .top_right = slice[((row - 1) * stride) + column + 1],

                .center_left = slice[(row * stride) + column - 1],
                .center_center = slice[(row * stride) + column],
                .center_right = slice[(row * stride) + column + 1],

                .bottom_left = slice[((row + 1) * stride) + column - 1],
                .bottom_center = slice[((row + 1) * stride) + column],
                .bottom_right = slice[((row + 1) * stride) + column + 1],
            };
        }

        /// Just like `init`, only it loads data from two rows (lines) away instead of one,
        /// so as to ensure we're loading data from the same field instead of blending two fields together.
        pub fn initInterlaced(comptime R: type, slice: []const R, stride: u32) Self {
            if (side_length != 3) {
                @compileError("Grid.initInterlaced is currently only implemented for side length 3");
            }

            // Vector
            if (@typeInfo(T) == .Vector) {
                return Self{
                    .top_left = vec.load(T, slice, 0),
                    .top_center = vec.load(T, slice, 1),
                    .top_right = vec.load(T, slice, 2),

                    .center_left = vec.load(T, slice, (stride * 2)),
                    .center_center = vec.load(T, slice, (stride * 2) + 1),
                    .center_right = vec.load(T, slice, (stride * 2) + 2),

                    .bottom_left = vec.load(T, slice, (stride * 4)),
                    .bottom_center = vec.load(T, slice, (stride * 4) + 1),
                    .bottom_right = vec.load(T, slice, (stride * 4) + 2),
                };
            }

            // Scalar
            return Self{
                .top_left = slice[0],
                .top_center = slice[1],
                .top_right = slice[2],

                .center_left = slice[stride * 2 ..][0],
                .center_center = slice[stride * 2 ..][1],
                .center_right = slice[stride * 2 ..][2],

                .bottom_left = slice[stride * 4 ..][0],
                .bottom_center = slice[stride * 4 ..][1],
                .bottom_right = slice[stride * 4 ..][2],
            };
        }

        /// Finds the min value of all pixels, including the center.
        pub fn minWithCenter(self: Self) T {
            if (side_length != 3) {
                @compileError("Grid.minWithCenter is currently only implemented for side length 3");
            }

            return @min(self.top_left, self.top_center, self.top_right, //
                self.center_left, self.center_center, self.center_right, //
                self.bottom_left, self.bottom_center, self.bottom_right);
        }

        /// Finds the min value of all pixels, *not* including the center.
        pub fn minWithoutCenter(self: Self) T {
            if (side_length != 3) {
                @compileError("Grid.minWithoutCenter is currently only implemented for side length 3");
            }

            return @min(self.top_left, self.top_center, self.top_right, //
                self.center_left, self.center_right, //
                self.bottom_left, self.bottom_center, self.bottom_right);
        }

        /// Finds the max value of all pixels, including the center.
        pub fn maxWithCenter(self: Self) T {
            if (side_length != 3) {
                @compileError("Grid.maxWithCenter is currently only implemented for side length 3");
            }

            return @max(self.top_left, self.top_center, self.top_right, //
                self.center_left, self.center_center, self.center_right, //
                self.bottom_left, self.bottom_center, self.bottom_right);
        }

        /// Finds the max value of all pixels, *not* including the center.
        pub fn maxWithoutCenter(self: Self) T {
            if (side_length != 3) {
                @compileError("Grid.maxWithoutCenter is currently only implemented for side length 3");
            }

            return @max(self.top_left, self.top_center, self.top_right, self.center_left, self.center_right, self.bottom_left, self.bottom_center, self.bottom_right);
        }

        /// Creates an array of all pixels, including the center.
        pub fn toArrayWithCenter(self: Self) [9]T {
            return [9]T{ self.top_left, self.top_center, self.top_right, self.center_left, self.center_center, self.center_right, self.bottom_left, self.bottom_center, self.bottom_right };
        }

        /// Creates an array of all pixels, excluding the center.
        pub fn toArrayWithoutCenter(self: Self) [8]T {
            return [8]T{ self.top_left, self.top_center, self.top_right, self.center_left, self.center_right, self.bottom_left, self.bottom_center, self.bottom_right };
        }

        /// Sorts all pixels, excluding the center.
        pub fn sortWithoutCenter(self: Self) [(side_length * side_length) - 1]T {
            var a = self.toArrayWithoutCenter();

            sort.sort(T, a.len, &a);

            return a;
        }

        /// Sorts all pixels, including the center.
        pub fn sortWithCenter(self: Self) [side_length * side_length]T {
            var a = self.toArrayWithCenter();

            sort.sort(T, a.len, &a);

            return a;
        }

        // Computes the min and max of opposing pixels in the 3x3 grid.
        pub fn minMaxOppositesWithoutCenter(self: Self) struct { max1: T, min1: T, max2: T, min2: T, max3: T, min3: T, max4: T, min4: T } {
            if (side_length != 3) {
                @compileError("Grid.minMaxOppositesWithoutCenter is currently only implemented for side length 3");
            }

            return .{
                .max1 = @max(self.top_left, self.bottom_right),
                .min1 = @min(self.top_left, self.bottom_right),
                .max2 = @max(self.top_center, self.bottom_center),
                .min2 = @min(self.top_center, self.bottom_center),
                .max3 = @max(self.top_right, self.bottom_left),
                .min3 = @min(self.top_right, self.bottom_left),
                .max4 = @max(self.center_left, self.center_right),
                .min4 = @min(self.center_left, self.center_right),
            };
        }

        pub fn minMaxOppositesWithCenter(self: Self) struct { max1: T, min1: T, max2: T, min2: T, max3: T, min3: T, max4: T, min4: T } {
            if (side_length != 3) {
                @compileError("Grid.minMaxOppositesWithCenter is currently only implemented for side length 3");
            }

            return .{
                .max1 = @max(self.top_left, self.bottom_right, self.center_center),
                .min1 = @min(self.top_left, self.bottom_right, self.center_center),
                .max2 = @max(self.top_center, self.bottom_center, self.center_center),
                .min2 = @min(self.top_center, self.bottom_center, self.center_center),
                .max3 = @max(self.top_right, self.bottom_left, self.center_center),
                .min3 = @min(self.top_right, self.bottom_left, self.center_center),
                .max4 = @max(self.center_left, self.center_right, self.center_center),
                .min4 = @min(self.center_left, self.center_right, self.center_center),
            };
        }
    };
}

test "Grid init" {
    const T = u8;
    const data = [9]T{
        0, 1, 2, //
        3, 4, 5, //
        6, 7, 8, //
    };

    const grid = Grid(T, 3).init(T, &data, 3);

    try std.testing.expectEqual(0, grid.top_left);
    try std.testing.expectEqual(1, grid.top_center);
    try std.testing.expectEqual(2, grid.top_right);

    try std.testing.expectEqual(3, grid.center_left);
    try std.testing.expectEqual(4, grid.center_center);
    try std.testing.expectEqual(5, grid.center_right);

    try std.testing.expectEqual(6, grid.bottom_left);
    try std.testing.expectEqual(7, grid.bottom_center);
    try std.testing.expectEqual(8, grid.bottom_right);
}

test "Grid initFromCenter" {
    const T = u8;
    const data = [9]T{
        0, 1, 2, //
        3, 4, 5, //
        6, 7, 8, //
    };

    const grid = Grid(T, 3).initFromCenter(T, 1, 1, &data, 3);

    try std.testing.expectEqual(0, grid.top_left);
    try std.testing.expectEqual(1, grid.top_center);
    try std.testing.expectEqual(2, grid.top_right);

    try std.testing.expectEqual(3, grid.center_left);
    try std.testing.expectEqual(4, grid.center_center);
    try std.testing.expectEqual(5, grid.center_right);

    try std.testing.expectEqual(6, grid.bottom_left);
    try std.testing.expectEqual(7, grid.bottom_center);
    try std.testing.expectEqual(8, grid.bottom_right);
}

test "Grid3 init from center mirrored" {
    const T = u8;
    const data = [9]T{
        0, 1, 2, //
        3, 4, 5, //
        6, 7, 8, //
    };

    const gridTopLeft = Grid(T, 3).initFromCenterMirrored(T, 0, 0, 3, 3, &data, 3);

    try std.testing.expectEqual(4, gridTopLeft.top_left);
    try std.testing.expectEqual(3, gridTopLeft.top_center);
    try std.testing.expectEqual(4, gridTopLeft.top_right);

    try std.testing.expectEqual(1, gridTopLeft.center_left);
    try std.testing.expectEqual(0, gridTopLeft.center_center);
    try std.testing.expectEqual(1, gridTopLeft.center_right);

    try std.testing.expectEqual(4, gridTopLeft.bottom_left);
    try std.testing.expectEqual(3, gridTopLeft.bottom_center);
    try std.testing.expectEqual(4, gridTopLeft.bottom_right);

    const gridTopRight = Grid(T, 3).initFromCenterMirrored(T, 0, 2, 3, 3, &data, 3);

    try std.testing.expectEqual(4, gridTopRight.top_left);
    try std.testing.expectEqual(5, gridTopRight.top_center);
    try std.testing.expectEqual(4, gridTopRight.top_right);

    try std.testing.expectEqual(1, gridTopRight.center_left);
    try std.testing.expectEqual(2, gridTopRight.center_center);
    try std.testing.expectEqual(1, gridTopRight.center_right);

    try std.testing.expectEqual(4, gridTopRight.bottom_left);
    try std.testing.expectEqual(5, gridTopRight.bottom_center);
    try std.testing.expectEqual(4, gridTopRight.bottom_right);

    const gridBottomLeft = Grid(T, 3).initFromCenterMirrored(T, 2, 0, 3, 3, &data, 3);

    try std.testing.expectEqual(4, gridBottomLeft.top_left);
    try std.testing.expectEqual(3, gridBottomLeft.top_center);
    try std.testing.expectEqual(4, gridBottomLeft.top_right);

    try std.testing.expectEqual(7, gridBottomLeft.center_left);
    try std.testing.expectEqual(6, gridBottomLeft.center_center);
    try std.testing.expectEqual(7, gridBottomLeft.center_right);

    try std.testing.expectEqual(4, gridBottomLeft.bottom_left);
    try std.testing.expectEqual(3, gridBottomLeft.bottom_center);
    try std.testing.expectEqual(4, gridBottomLeft.bottom_right);

    const gridBottomRight = Grid(T, 3).initFromCenterMirrored(T, 2, 2, 3, 3, &data, 3);

    try std.testing.expectEqual(4, gridBottomRight.top_left);
    try std.testing.expectEqual(5, gridBottomRight.top_center);
    try std.testing.expectEqual(4, gridBottomRight.top_right);

    try std.testing.expectEqual(7, gridBottomRight.center_left);
    try std.testing.expectEqual(8, gridBottomRight.center_center);
    try std.testing.expectEqual(7, gridBottomRight.center_right);

    try std.testing.expectEqual(4, gridBottomRight.bottom_left);
    try std.testing.expectEqual(5, gridBottomRight.bottom_center);
    try std.testing.expectEqual(4, gridBottomRight.bottom_right);
}

test "Grid5 init from center mirrored" {
    const T = u8;
    const data = [25]T{
        0,  1,  2,  3,  4,
        5,  6,  7,  8,  9,
        10, 11, 12, 13, 14,
        15, 16, 17, 18, 19,
        20, 21, 22, 23, 24,
    };

    const gridTopLeft = Grid(T, 5).initFromCenterMirrored(T, 0, 0, 5, 5, &data, 5);

    try std.testing.expectEqual(12, gridTopLeft.far_top_far_left);
    try std.testing.expectEqual(11, gridTopLeft.far_top_left);
    try std.testing.expectEqual(10, gridTopLeft.far_top_center);
    try std.testing.expectEqual(11, gridTopLeft.far_top_right);
    try std.testing.expectEqual(12, gridTopLeft.far_top_far_right);

    try std.testing.expectEqual(7, gridTopLeft.top_far_left);
    try std.testing.expectEqual(6, gridTopLeft.top_left);
    try std.testing.expectEqual(5, gridTopLeft.top_center);
    try std.testing.expectEqual(6, gridTopLeft.top_right);
    try std.testing.expectEqual(7, gridTopLeft.top_far_right);

    try std.testing.expectEqual(2, gridTopLeft.center_far_left);
    try std.testing.expectEqual(1, gridTopLeft.center_left);
    try std.testing.expectEqual(0, gridTopLeft.center_center);
    try std.testing.expectEqual(1, gridTopLeft.center_right);
    try std.testing.expectEqual(2, gridTopLeft.center_far_right);

    try std.testing.expectEqual(7, gridTopLeft.bottom_far_left);
    try std.testing.expectEqual(6, gridTopLeft.bottom_left);
    try std.testing.expectEqual(5, gridTopLeft.bottom_center);
    try std.testing.expectEqual(6, gridTopLeft.bottom_right);
    try std.testing.expectEqual(7, gridTopLeft.bottom_far_right);

    try std.testing.expectEqual(12, gridTopLeft.far_bottom_far_left);
    try std.testing.expectEqual(11, gridTopLeft.far_bottom_left);
    try std.testing.expectEqual(10, gridTopLeft.far_bottom_center);
    try std.testing.expectEqual(11, gridTopLeft.far_bottom_right);
    try std.testing.expectEqual(12, gridTopLeft.far_bottom_far_right);

    const gridTopRight = Grid(T, 5).initFromCenterMirrored(T, 0, 4, 5, 5, &data, 5);

    try std.testing.expectEqual(12, gridTopRight.far_top_far_left);
    try std.testing.expectEqual(13, gridTopRight.far_top_left);
    try std.testing.expectEqual(14, gridTopRight.far_top_center);
    try std.testing.expectEqual(13, gridTopRight.far_top_right);
    try std.testing.expectEqual(12, gridTopRight.far_top_far_right);

    try std.testing.expectEqual(7, gridTopRight.top_far_left);
    try std.testing.expectEqual(8, gridTopRight.top_left);
    try std.testing.expectEqual(9, gridTopRight.top_center);
    try std.testing.expectEqual(8, gridTopRight.top_right);
    try std.testing.expectEqual(7, gridTopRight.top_far_right);

    try std.testing.expectEqual(2, gridTopRight.center_far_left);
    try std.testing.expectEqual(3, gridTopRight.center_left);
    try std.testing.expectEqual(4, gridTopRight.center_center);
    try std.testing.expectEqual(3, gridTopRight.center_right);
    try std.testing.expectEqual(2, gridTopRight.center_far_right);

    try std.testing.expectEqual(7, gridTopRight.bottom_far_left);
    try std.testing.expectEqual(8, gridTopRight.bottom_left);
    try std.testing.expectEqual(9, gridTopRight.bottom_center);
    try std.testing.expectEqual(8, gridTopRight.bottom_right);
    try std.testing.expectEqual(7, gridTopRight.bottom_far_right);

    try std.testing.expectEqual(12, gridTopRight.far_bottom_far_left);
    try std.testing.expectEqual(13, gridTopRight.far_bottom_left);
    try std.testing.expectEqual(14, gridTopRight.far_bottom_center);
    try std.testing.expectEqual(13, gridTopRight.far_bottom_right);
    try std.testing.expectEqual(12, gridTopRight.far_bottom_far_right);

    const gridBottomLeft = Grid(T, 5).initFromCenterMirrored(T, 4, 0, 5, 5, &data, 5);

    try std.testing.expectEqual(12, gridBottomLeft.far_top_far_left);
    try std.testing.expectEqual(11, gridBottomLeft.far_top_left);
    try std.testing.expectEqual(10, gridBottomLeft.far_top_center);
    try std.testing.expectEqual(11, gridBottomLeft.far_top_right);
    try std.testing.expectEqual(12, gridBottomLeft.far_top_far_right);

    try std.testing.expectEqual(17, gridBottomLeft.top_far_left);
    try std.testing.expectEqual(16, gridBottomLeft.top_left);
    try std.testing.expectEqual(15, gridBottomLeft.top_center);
    try std.testing.expectEqual(16, gridBottomLeft.top_right);
    try std.testing.expectEqual(17, gridBottomLeft.top_far_right);

    try std.testing.expectEqual(22, gridBottomLeft.center_far_left);
    try std.testing.expectEqual(21, gridBottomLeft.center_left);
    try std.testing.expectEqual(20, gridBottomLeft.center_center);
    try std.testing.expectEqual(21, gridBottomLeft.center_right);
    try std.testing.expectEqual(22, gridBottomLeft.center_far_right);

    try std.testing.expectEqual(17, gridBottomLeft.bottom_far_left);
    try std.testing.expectEqual(16, gridBottomLeft.bottom_left);
    try std.testing.expectEqual(15, gridBottomLeft.bottom_center);
    try std.testing.expectEqual(16, gridBottomLeft.bottom_right);
    try std.testing.expectEqual(17, gridBottomLeft.bottom_far_right);

    try std.testing.expectEqual(12, gridBottomLeft.far_bottom_far_left);
    try std.testing.expectEqual(11, gridBottomLeft.far_bottom_left);
    try std.testing.expectEqual(10, gridBottomLeft.far_bottom_center);
    try std.testing.expectEqual(11, gridBottomLeft.far_bottom_right);
    try std.testing.expectEqual(12, gridBottomLeft.far_bottom_far_right);

    const gridBottomRight = Grid(T, 5).initFromCenterMirrored(T, 4, 4, 5, 5, &data, 5);

    try std.testing.expectEqual(12, gridBottomRight.far_top_far_left);
    try std.testing.expectEqual(13, gridBottomRight.far_top_left);
    try std.testing.expectEqual(14, gridBottomRight.far_top_center);
    try std.testing.expectEqual(13, gridBottomRight.far_top_right);
    try std.testing.expectEqual(12, gridBottomRight.far_top_far_right);

    try std.testing.expectEqual(17, gridBottomRight.top_far_left);
    try std.testing.expectEqual(18, gridBottomRight.top_left);
    try std.testing.expectEqual(19, gridBottomRight.top_center);
    try std.testing.expectEqual(18, gridBottomRight.top_right);
    try std.testing.expectEqual(17, gridBottomRight.top_far_right);

    try std.testing.expectEqual(22, gridBottomRight.center_far_left);
    try std.testing.expectEqual(23, gridBottomRight.center_left);
    try std.testing.expectEqual(24, gridBottomRight.center_center);
    try std.testing.expectEqual(23, gridBottomRight.center_right);
    try std.testing.expectEqual(22, gridBottomRight.center_far_right);

    try std.testing.expectEqual(17, gridBottomRight.bottom_far_left);
    try std.testing.expectEqual(18, gridBottomRight.bottom_left);
    try std.testing.expectEqual(19, gridBottomRight.bottom_center);
    try std.testing.expectEqual(18, gridBottomRight.bottom_right);
    try std.testing.expectEqual(17, gridBottomRight.bottom_far_right);

    try std.testing.expectEqual(12, gridBottomRight.far_bottom_far_left);
    try std.testing.expectEqual(13, gridBottomRight.far_bottom_left);
    try std.testing.expectEqual(14, gridBottomRight.far_bottom_center);
    try std.testing.expectEqual(13, gridBottomRight.far_bottom_right);
    try std.testing.expectEqual(12, gridBottomRight.far_bottom_far_right);
}

test "Grid min" {
    const T = u8;
    const data = [9]T{
        1, 2, 3, //
        4, 0, 6, //
        7, 8, 9, //
    };

    var grid = Grid(T, 3).init(T, &data, 3);

    try std.testing.expectEqual(0, grid.minWithCenter());
    try std.testing.expectEqual(1, grid.minWithoutCenter());
}

test "Grid max" {
    const T = u8;
    const data = [9]T{
        0, 1, 2, //
        3, 9, 5, //
        6, 7, 8, //
    };

    const grid = Grid(T, 3).init(T, &data, 3);

    try std.testing.expectEqual(9, grid.maxWithCenter());
    try std.testing.expectEqual(8, grid.maxWithoutCenter());
}

test "Grid toArray" {
    const T = u8;
    const data = [9]T{
        0, 1, 2, //
        3, 4, 5, //
        6, 7, 8, //
    };

    const grid = Grid(T, 3).init(T, &data, 3);

    try std.testing.expectEqualDeep(data, grid.toArrayWithCenter());
    try std.testing.expectEqualDeep(.{ 0, 1, 2, 3, 5, 6, 7, 8 }, grid.toArrayWithoutCenter());
}

test "Grid minMaxOpposites" {
    const T = u8;
    const data = [9]T{
        0, 1, 2, //
        3, 4, 5, //
        6, 7, 8, //
    };

    const grid = Grid(T, 3).init(T, &data, 3);
    const minMax = grid.minMaxOppositesWithoutCenter();

    try std.testing.expectEqual(0, minMax.min1);
    try std.testing.expectEqual(8, minMax.max1);

    try std.testing.expectEqual(1, minMax.min2);
    try std.testing.expectEqual(7, minMax.max2);

    try std.testing.expectEqual(2, minMax.min3);
    try std.testing.expectEqual(6, minMax.max3);

    try std.testing.expectEqual(3, minMax.min4);
    try std.testing.expectEqual(5, minMax.max4);
}

test "Grid minMaxOppositesWithCenter" {
    const T = u8;
    const dataLow = [9]T{
        1, 2, 3, //
        4, 0, 5, //
        6, 7, 8, //
    };

    const gridLow = Grid(T, 3).init(T, &dataLow, 3);
    const minMaxLow = gridLow.minMaxOppositesWithCenter();

    try std.testing.expectEqual(0, minMaxLow.min1);
    try std.testing.expectEqual(8, minMaxLow.max1);

    try std.testing.expectEqual(0, minMaxLow.min2);
    try std.testing.expectEqual(7, minMaxLow.max2);

    try std.testing.expectEqual(0, minMaxLow.min3);
    try std.testing.expectEqual(6, minMaxLow.max3);

    try std.testing.expectEqual(0, minMaxLow.min4);
    try std.testing.expectEqual(5, minMaxLow.max4);

    const dataHigh = [9]T{
        1, 2, 3, //
        4, 9, 5, //
        6, 7, 8, //
    };

    const gridHigh = Grid(T, 3).init(T, &dataHigh, 3);
    const minMaxHigh = gridHigh.minMaxOppositesWithCenter();

    try std.testing.expectEqual(1, minMaxHigh.min1);
    try std.testing.expectEqual(9, minMaxHigh.max1);

    try std.testing.expectEqual(2, minMaxHigh.min2);
    try std.testing.expectEqual(9, minMaxHigh.max2);

    try std.testing.expectEqual(3, minMaxHigh.min3);
    try std.testing.expectEqual(9, minMaxHigh.max3);

    try std.testing.expectEqual(4, minMaxHigh.min4);
    try std.testing.expectEqual(9, minMaxHigh.max4);
}
