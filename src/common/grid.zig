const std = @import("std");
const vec = @import("vector.zig");
const sort = @import("sorting_networks.zig");

// Encapsulates data for a 3x3 grid of pixels.
pub fn Grid(comptime T: type) type {
    return struct {
        top_left: T,
        top_center: T,
        top_right: T,
        center_left: T,
        center_center: T,
        center_right: T,
        bottom_left: T,
        bottom_center: T,
        bottom_right: T,

        const Self = @This();

        /// Loads a Grid from a slice of elements of type R, starting at the
        /// slice's index 0, and then jumping in slice by stride
        /// to access each row.
        ///
        /// Note that types R and T are not identical. We can create a grid of vectors,
        /// where the vector type is T, but from a slice of pixels which have type R.
        ///
        /// TODO: Support loading a grid from a center pixel instead of the top left pixel.
        pub fn init(comptime R: type, slice: []const R, stride: u32) Self {
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

        /// Just like `init`, only it loads data from two rows (lines) away instead of one,
        /// so as to ensure we're loading data from the same field instead of blending two fields together.
        pub fn initInterlaced(comptime R: type, slice: []const R, stride: u32) Self {
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

        // Need to benchmark this - might be slower or faster, not sure.
        // pub fn min(self: Self) T {
        //     const vector: @Vector(9, T) = self.toArray();
        //     return @reduce(.Min, vector);
        // }
        // pub fn max(self: Self) T {
        //     const vector: @Vector(9, T) = self.toArray();
        //     return @reduce(.Max, vector);
        // }

        // Finds the min value of all pixels, including the center.
        pub fn minWithCenter(self: Self) T {
            return @min(self.top_left, self.top_center, self.top_right, self.center_left, self.center_center, self.center_right, self.bottom_left, self.bottom_center, self.bottom_right);
        }

        // Finds the min value of all pixels, *not* including the center.
        pub fn minWithoutCenter(self: Self) T {
            return @min(self.top_left, self.top_center, self.top_right, self.center_left, self.center_right, self.bottom_left, self.bottom_center, self.bottom_right);
        }

        pub fn maxWithCenter(self: Self) T {
            return @max(self.top_left, self.top_center, self.top_right, self.center_left, self.center_center, self.center_right, self.bottom_left, self.bottom_center, self.bottom_right);
        }

        // Finds the max value of all pixels, *not* including the center.
        pub fn maxWithoutCenter(self: Self) T {
            return @max(self.top_left, self.top_center, self.top_right, self.center_left, self.center_right, self.bottom_left, self.bottom_center, self.bottom_right);
        }

        // Creates an array of all pixels, including the center.
        pub fn toArrayWithCenter(self: Self) [9]T {
            return [9]T{ self.top_left, self.top_center, self.top_right, self.center_left, self.center_center, self.center_right, self.bottom_left, self.bottom_center, self.bottom_right };
        }

        // Creates an array of all pixels, excluding the center.
        pub fn toArrayWithoutCenter(self: Self) [8]T {
            return [8]T{ self.top_left, self.top_center, self.top_right, self.center_left, self.center_right, self.bottom_left, self.bottom_center, self.bottom_right };
        }

        // Sorts all pixels, excluding the center.
        pub fn sortWithoutCenter(self: Self) [8]T {
            var a = self.toArrayWithoutCenter();
            sort.sort(T, a.len, &a);

            return a;
        }

        // Computes the min and max of opposing pixels in the 3x3 grid.
        pub fn minMaxOpposites(self: Self) struct { max1: T, min1: T, max2: T, min2: T, max3: T, min3: T, max4: T, min4: T } {
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
    };
}

test "Grid init" {
    const T = u8;
    const data = [9]T{
        0, 1, 2, //
        3, 4, 5, //
        6, 7, 8, //
    };

    const grid = Grid(T).init(T, &data, 3);

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

test "Grid min" {
    const T = u8;
    const data = [9]T{
        1, 2, 3, //
        4, 0, 6, //
        7, 8, 9, //
    };

    var grid = Grid(T).init(T, &data, 3);

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

    const grid = Grid(T).init(T, &data, 3);

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

    const grid = Grid(T).init(T, &data, 3);

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

    const grid = Grid(T).init(T, &data, 3);
    const minMax = grid.minMaxOpposites();

    try std.testing.expectEqual(0, minMax.min1);
    try std.testing.expectEqual(8, minMax.max1);

    try std.testing.expectEqual(1, minMax.min2);
    try std.testing.expectEqual(7, minMax.max2);

    try std.testing.expectEqual(2, minMax.min3);
    try std.testing.expectEqual(6, minMax.max3);

    try std.testing.expectEqual(3, minMax.min4);
    try std.testing.expectEqual(5, minMax.max4);
}
