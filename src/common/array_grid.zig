const std = @import("std");
const vec = @import("vector.zig");
const sort = @import("sorting_networks.zig");
const types = @import("type.zig");

/// Creates a grid of side x side size with values of type T.
/// This is a sister to Grid, without convenient value aliases
/// (like `top_left`, etc). But it has the benefit of easily supporting
/// arbitrary grid sizes.
pub fn ArrayGrid(comptime side: comptime_int, comptime T: type) type {
    const A = [side * side]T;
    return struct {
        const Self = @This();

        values: A,

        /// Loads a Grid from a slice of elements of type R, starting at the
        /// slice's index 0, and then jumping in slice by stride
        /// to access each row.
        ///
        /// Note that types R and T are not identical. We can create a grid of vectors,
        /// where the vector type is T, but from a slice of pixels which have type R.
        // TODO: Rename to `initFromTopLeft`
        pub fn init(comptime R: type, slice: []const R, stride: usize) Self {
            var v: A = undefined;

            for (0..side) |row| {
                for (0..side) |column| {
                    v[row * side + column] = if (types.isScalar(T))
                        slice[row * stride + column] // Scalar
                    else
                        vec.load(T, slice, row * stride + column); // Vector
                }
            }

            return Self{ .values = v };
        }

        /// Loads data around a center pixel, without any mirroring.
        ///
        /// Small wrapper around `init`.
        pub fn initFromCenter(comptime R: type, row: usize, column: usize, slice: []const R, stride: usize) Self {
            const radius = side / 2;
            const top_left = ((row - radius) * stride) + column - radius;
            return init(R, slice[top_left..], stride);
        }

        /// Loads data around a center pixel, using mirroring to fill in all missing pixels.
        /// Note that for maximum performance, this function should *ONLY* be used on edge pixels.
        /// Using it on pixels that actually have pertinent data leads to crap performance and is completely unnecessary.
        ///
        /// TODO BUG: This doesn't actually work with vectors. Specifically a vector is composed of a mix of
        /// pixel positions, some out of range of the edge (and thus in need of mirroring) and some in range of mirroring.
        /// In order to properly handle this mix, a vector would need to be loaded with a "gather", so addresses for each
        /// member of the vector would need to be calculated and then "gathered" accordingly.
        pub fn initFromCenterMirrored(comptime R: type, _row: usize, _column: usize, _width: usize, _height: usize, slice: []const R, stride: usize) Self {
            comptime std.debug.assert(!types.isVector(T)); // This function doesn't support Vectors yet.
            const row: i16 = @intCast(_row);
            const column: i16 = @intCast(_column);
            const width: i16 = @intCast(_width);
            const height: i16 = @intCast(_height);

            const radius = side / 2;

            var v: A = undefined;

            for (0..side) |y| {
                for (0..side) |x| {
                    const yi: i16 = @intCast(y);
                    const xi: i16 = @intCast(x);

                    const minRow: i32 = @abs(row + yi - radius);
                    const minColumn: i32 = @abs(column + xi - radius);

                    const clamped_y: usize = @intCast(@min(minRow, 2 * (height - 1) - (row + yi - radius)));
                    const clamped_x: usize = @intCast(@min(minColumn, 2 * (width - 1) - (column + xi - radius)));

                    v[y * side + x] = if (types.isScalar(T))
                        slice[clamped_y * stride + clamped_x]
                    else
                        vec.load(T, slice, clamped_y * stride + clamped_x);
                }
            }

            return Self{ .values = v };
        }

        /// Sorts the `values` member.
        ///
        /// Note that this is a *mutative* operation.
        pub fn sortWithCenter(self: *Self) void {
            sort.sort(T, &self.values);
        }

        /// Finds the median of the `values` member.
        ///
        /// Note that this has the side effect of *mutating* the `values` member.
        pub fn medianWithCenter(self: *Self) T {
            return sort.median(T, &self.values);
        }

        /// Creates an array containing all values of the grid
        /// except the center.
        pub fn valuesWithoutCenter(self: *Self) [side * side - 1]T {
            var values_without_center: [self.values.len - 1]T = undefined;
            var values_idx: usize = 0;
            for (self.values, 0..) |v, i| {
                // Skip the center value.
                if (i == self.values.len / 2) {
                    continue;
                }
                values_without_center[values_idx] = v;
                values_idx += 1;
            }
            return values_without_center;
        }
    };
}

test "ArrayGrid init" {
    const T = u8;
    const data = [_]T{
        1, 2, 3, //
        4, 5, 6, //
        7, 8, 9, //
    };

    const grid = ArrayGrid(3, T).init(T, &data, 3);

    try std.testing.expectEqual(1, grid.values[0]);
    try std.testing.expectEqual(2, grid.values[1]);
    try std.testing.expectEqual(3, grid.values[2]);
    try std.testing.expectEqual(4, grid.values[3]);
    try std.testing.expectEqual(5, grid.values[4]);
    try std.testing.expectEqual(6, grid.values[5]);
    try std.testing.expectEqual(7, grid.values[6]);
    try std.testing.expectEqual(8, grid.values[7]);
    try std.testing.expectEqual(9, grid.values[8]);
}

test "ArrayGrid initFromCenter" {
    const T = u8;
    const data = [_]T{
        1, 2, 3, //
        4, 5, 6, //
        7, 8, 9, //
    };

    const grid = ArrayGrid(3, T).initFromCenter(T, 1, 1, &data, 3);

    try std.testing.expectEqual(1, grid.values[0]);
    try std.testing.expectEqual(2, grid.values[1]);
    try std.testing.expectEqual(3, grid.values[2]);
    try std.testing.expectEqual(4, grid.values[3]);
    try std.testing.expectEqual(5, grid.values[4]);
    try std.testing.expectEqual(6, grid.values[5]);
    try std.testing.expectEqual(7, grid.values[6]);
    try std.testing.expectEqual(8, grid.values[7]);
    try std.testing.expectEqual(9, grid.values[8]);
}

test "ArrayGrid initFromCenterMirrored" {
    const T = u8;
    const data = [_]T{
        0, 1, 2, //
        3, 4, 5, //
        6, 7, 8, //
    };

    const gridTopLeft = ArrayGrid(3, T).initFromCenterMirrored(T, 0, 0, 3, 3, &data, 3);

    try std.testing.expectEqual(4, gridTopLeft.values[0]);
    try std.testing.expectEqual(3, gridTopLeft.values[1]);
    try std.testing.expectEqual(4, gridTopLeft.values[2]);

    try std.testing.expectEqual(1, gridTopLeft.values[3]);
    try std.testing.expectEqual(0, gridTopLeft.values[4]);
    try std.testing.expectEqual(1, gridTopLeft.values[5]);

    try std.testing.expectEqual(4, gridTopLeft.values[6]);
    try std.testing.expectEqual(3, gridTopLeft.values[7]);
    try std.testing.expectEqual(4, gridTopLeft.values[8]);

    const gridTopRight = ArrayGrid(3, T).initFromCenterMirrored(T, 0, 2, 3, 3, &data, 3);

    try std.testing.expectEqual(4, gridTopRight.values[0]);
    try std.testing.expectEqual(5, gridTopRight.values[1]);
    try std.testing.expectEqual(4, gridTopRight.values[2]);

    try std.testing.expectEqual(1, gridTopRight.values[3]);
    try std.testing.expectEqual(2, gridTopRight.values[4]);
    try std.testing.expectEqual(1, gridTopRight.values[5]);

    try std.testing.expectEqual(4, gridTopRight.values[6]);
    try std.testing.expectEqual(5, gridTopRight.values[7]);
    try std.testing.expectEqual(4, gridTopRight.values[8]);

    const gridBottomLeft = ArrayGrid(3, T).initFromCenterMirrored(T, 2, 0, 3, 3, &data, 3);

    try std.testing.expectEqual(4, gridBottomLeft.values[0]);
    try std.testing.expectEqual(3, gridBottomLeft.values[1]);
    try std.testing.expectEqual(4, gridBottomLeft.values[2]);

    try std.testing.expectEqual(7, gridBottomLeft.values[3]);
    try std.testing.expectEqual(6, gridBottomLeft.values[4]);
    try std.testing.expectEqual(7, gridBottomLeft.values[5]);

    try std.testing.expectEqual(4, gridBottomLeft.values[6]);
    try std.testing.expectEqual(3, gridBottomLeft.values[7]);
    try std.testing.expectEqual(4, gridBottomLeft.values[8]);

    const gridBottomRight = ArrayGrid(3, T).initFromCenterMirrored(T, 2, 2, 3, 3, &data, 3);

    try std.testing.expectEqual(4, gridBottomRight.values[0]);
    try std.testing.expectEqual(5, gridBottomRight.values[1]);
    try std.testing.expectEqual(4, gridBottomRight.values[2]);

    try std.testing.expectEqual(7, gridBottomRight.values[3]);
    try std.testing.expectEqual(8, gridBottomRight.values[4]);
    try std.testing.expectEqual(7, gridBottomRight.values[5]);

    try std.testing.expectEqual(4, gridBottomRight.values[6]);
    try std.testing.expectEqual(5, gridBottomRight.values[7]);
    try std.testing.expectEqual(4, gridBottomRight.values[8]);
}

test "ArrayGrid sort" {
    const T = u8;
    const data = [_]T{
        9, 8, 7, //
        6, 5, 4, //
        3, 2, 1, //
    };

    var grid = ArrayGrid(3, T).init(T, &data, 3);
    grid.sortWithCenter();

    try std.testing.expectEqual(1, grid.values[0]);
}

test "ArrayGrid median" {
    const T = u8;
    const data = [_]T{
        9, 8, 7, //
        6, 1, 4, //
        3, 2, 5, //
    };

    var grid = ArrayGrid(3, T).init(T, &data, 3);
    const median = grid.medianWithCenter();

    try std.testing.expectEqual(5, median);
}
