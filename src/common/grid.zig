const std = @import("std");
const vec = @import("vector.zig");

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

        // Need to benchmark this - might be slower or faster, not sure.
        // pub fn min(self: Self) T {
        //     const vector: @Vector(9, T) = self.toArray();
        //     return @reduce(.Min, vector);
        // }
        // pub fn max(self: Self) T {
        //     const vector: @Vector(9, T) = self.toArray();
        //     return @reduce(.Max, vector);
        // }

        pub fn min(self: Self) T {
            return @min(self.top_left, self.top_center, self.top_right, self.center_left, self.center_center, self.center_right, self.bottom_left, self.bottom_center, self.bottom_right);
        }

        pub fn max(self: Self) T {
            return @max(self.top_left, self.top_center, self.top_right, self.center_left, self.center_center, self.center_right, self.bottom_left, self.bottom_center, self.bottom_right);
        }

        pub fn toArray(self: Self) [9]T {
            return [9]T{ self.top_left, self.top_center, self.top_right, self.center_left, self.center_center, self.center_right, self.bottom_left, self.bottom_center, self.bottom_right };
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
        0, 1, 2, //
        3, 4, 5, //
        6, 7, 8, //
    };

    const grid = Grid(T).init(T, &data, 3);

    try std.testing.expectEqual(0, grid.min());
}

test "Grid max" {
    const T = u8;
    const data = [9]T{
        0, 1, 2, //
        3, 4, 5, //
        6, 7, 8, //
    };

    const grid = Grid(T).init(T, &data, 3);

    try std.testing.expectEqual(8, grid.max());
}

test "Grid toArray" {
    const T = u8;
    const data = [9]T{
        0, 1, 2, //
        3, 4, 5, //
        6, 7, 8, //
    };

    const grid = Grid(T).init(T, &data, 3);

    try std.testing.expectEqualDeep(data, grid.toArray());
}
