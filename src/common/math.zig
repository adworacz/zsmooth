const std = @import("std");
const isScalar = @import("./type.zig").isScalar;

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
        .Float => {
            switch (@typeInfo(@TypeOf(value))) {
                .Int => return @as(T, @floatFromInt(value)),
                .Float => return @as(T, @floatCast(value)),
                .ComptimeInt => return @as(T, value),
                .ComptimeFloat => return @as(T, value),
                else => @compileError("bad type"),
            }
        },
        .Int => {
            switch (@typeInfo(@TypeOf(value))) {
                .Int, .ComptimeInt => {
                    return @as(T, @intCast(value));
                },
                .Float, .ComptimeFloat => {
                    return @as(T, @intFromFloat(value));
                },
                else => @compileError("bad type"),
            }
        },
        else => @compileError("bad result type"),
    }
}

// Identical to std.math.clamp, just works with Vectors
// by removing the assert it previously used. Ideally this should be fixed in the std library...
pub fn clamp(val: anytype, lower: anytype, upper: anytype) @TypeOf(val, lower, upper) {
    if (isScalar(@TypeOf(val, lower, upper))) {
        std.debug.assert(lower <= upper);
    }
    return @max(lower, @min(val, upper));
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
