const std = @import("std");
const types = @import("./type.zig");

/////////////////////////////////////////////////
// Math
/////////////////////////////////////////////////

/// My own modified version of std.math.lossyCast without that min/maxInt checks
/// since I want to avoid branching as much as possible and the usages of this
/// function should be on values that are guarranteed *by the programmer* NOT
/// to be out of range of the target type.
///
/// So yes, this is a more dangerous lossyCast, but also a faster (no branches)
/// version.
pub fn lossyCast(comptime T: type, value: anytype) T {
    switch (@typeInfo(T)) {
        .float => {
            switch (@typeInfo(@TypeOf(value))) {
                .int => return @as(T, @floatFromInt(value)),
                .float => return @as(T, @floatCast(value)),
                .comptime_int => return @as(T, value),
                .comptime_float => return @as(T, value),
                else => @compileError("bad type"),
            }
        },
        .int => {
            switch (@typeInfo(@TypeOf(value))) {
                .int, .comptime_int => {
                    return @as(T, @intCast(value));
                },
                .float, .comptime_float => {
                    return @as(T, @intFromFloat(value));
                },
                else => @compileError("bad type"),
            }
        },
        .vector => {
            switch (@typeInfo(@typeInfo(T).vector.child)) {
                .float => {
                    switch (@typeInfo(@typeInfo(@TypeOf(value)).vector.child)) {
                        .int => return @as(T, @floatFromInt(value)),
                        .float => return @as(T, @floatCast(value)),
                        .comptime_int => return @as(T, value),
                        .comptime_float => return @as(T, value),
                        else => @compileError("bad type"),
                    }
                },
                .int => {
                    switch (@typeInfo(@typeInfo(@TypeOf(value)).vector.child)) {
                        .int, .comptime_int => {
                            return @as(T, @intCast(value));
                        },
                        .float, .comptime_float => {
                            return @as(T, @intFromFloat(value));
                        },
                        else => @compileError("bad type"),
                    }
                },
                else => @compileError("bad result type"),
            }
        },
        else => @compileError("bad result type"),
    }
}

// Identical to std.math.clamp, just works with Vectors
// by removing the assert it previously used. Ideally this should be fixed in the std library...
pub fn clamp(val: anytype, lower: anytype, upper: anytype) @TypeOf(val, lower, upper) {
    if (types.isScalar(@TypeOf(val, lower, upper))) {
        std.debug.assert(lower <= upper);
    }
    return @max(lower, @min(val, upper));
}

/// Performs a clamped (or "saturating") subtraction of two values.
/// The second parameter is subtracted from the first parameter.
/// So clampSub(10, 5) == 10 - 5
/// Integers clamp to zero, and floats clamp to pixel_min.
pub fn subSat(a: anytype, b: anytype, min: anytype) @TypeOf(a, b) {
    return if (types.isInt(@TypeOf(a, b)))
        a -| b
    else
        @max(min, a - b);
}

test subSat {
    try std.testing.expectEqual(5, subSat(10, 5, 0));
    try std.testing.expectEqual(0, subSat(@as(u8, 5), 10, 2)); // Integers clamp to zero.
    try std.testing.expectEqual(1.0, subSat(5.0, 10.0, 1.0));
}

/// Performs saturating (clamped) addition of two values.
/// 8-bit is special cased (optimized) since we never use less than 8 bits.
pub fn addSat(a: anytype, b: anytype, max: anytype) @TypeOf(a, b) {
    return if (types.isInt(@TypeOf(a, b)))
        // Special case 8-bit to prevent extra @min instruction.
        if (@TypeOf(a, b) == u8) a +| b else @min(a +| b, max)
    else
        @min(a + b, max);
}

test addSat {
    const two_fifty_five: u8 = 255;
    try std.testing.expectEqual(255, addSat(two_fifty_five, 1, 9999));
    try std.testing.expectEqual(256.0, addSat(255.0, 1.0, 9999));
    try std.testing.expectEqual(1023, addSat(@as(u16, 1023), 1, 1023));
}

/// Computes the absolute difference of two values.
/// Supports fast operation on unsigned types using max/min.
pub fn absDiff(a: anytype, b: anytype) @TypeOf(a, b) {
    return if (types.isFloat(@TypeOf(a, b)))
        @abs(a - b)
    else
        @max(a, b) - @min(a, b);
}

test absDiff {
    try std.testing.expectEqual(10, absDiff(0, 10));
    try std.testing.expectEqual(10, absDiff(10, 0));
    try std.testing.expectEqual(0.5, absDiff(0, -0.5));
    try std.testing.expectEqual(0.5, absDiff(-0.5, 0));
}

/// Finds the min/max of the values of a and b and then assigns
/// the min value to a and the max value to b, effectively sorting the results.
pub fn compareSwap(comptime T: type, a: *T, b: *T) void {
    const min = @min(a.*, b.*);
    b.* = @max(a.*, b.*);
    a.* = min;
}

test compareSwap {
    var a: u8 = 5;
    var b: u8 = 1;

    compareSwap(u8, &a, &b);
    try std.testing.expectEqual(1, a);
    try std.testing.expectEqual(5, b);

    a = 6;
    b = 10;

    compareSwap(u8, &a, &b);
    try std.testing.expectEqual(6, a);
    try std.testing.expectEqual(10, b);

    var d = @Vector(1, u8){5};
    var e = @Vector(1, u8){1};

    compareSwap(@Vector(1, u8), &d, &e);
    try std.testing.expectEqual(@Vector(1, u8){1}, d);
    try std.testing.expectEqual(@Vector(1, u8){5}, e);
}

pub fn averageArray(comptime T: type, comptime N: comptime_int, array: *const [N]T) T {
    const UAT = types.UnsignedArithmeticType(T);

    var sum: UAT = if (types.isScalar(T)) 0 else @splat(0);
    for (array) |v| {
        sum += v;
    }

    const array_len: UAT = if (types.isScalar(T)) array.len else @splat(array.len);
    const half_array_len: UAT = if (types.isScalar(T)) array.len / 2 else array_len / @as(UAT, @splat(2));

    return lossyCast(T, if (types.isInt(T))
        (sum + half_array_len) / array_len
    else
        sum / array_len);
}

test averageArray {
    const arr = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };

    try std.testing.expectEqual(5, averageArray(u8, arr.len, &arr)); //4.5, but integer, so its rounded up.
}

/// Calculates a mirrored index
pub fn mirrorIndex(index: isize, _dimension: usize) usize {
    //TODO: Explore different implementations, as some might be faster than others.
    //TODO: Check this in compiler explorer...

    const dimension: isize = @intCast(_dimension);
    const result: isize = if (index < 0)
        -index
    else if (index >= dimension)
        2 * (dimension - 1) - index
    else
        index;

    return @intCast(result);
}

test mirrorIndex {
    const width = 10;
    try std.testing.expectEqual(1, mirrorIndex(1, width));
    try std.testing.expectEqual(1, mirrorIndex(-1, width));

    try std.testing.expectEqual(9, mirrorIndex(9, width));
    try std.testing.expectEqual(8, mirrorIndex(10, width));
}
