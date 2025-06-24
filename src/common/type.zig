const std = @import("std");

pub inline fn isFloat(comptime T: type) bool {
    const type_info = @typeInfo(T);
    return switch (type_info) {
        .float, .comptime_float => true,
        .vector => isFloat(type_info.vector.child),
        else => false,
    };
}

test isFloat {
    try std.testing.expectEqual(true, isFloat(f32));
    try std.testing.expectEqual(true, isFloat(@Vector(1, f32)));
    try std.testing.expectEqual(true, isFloat(f16));
    try std.testing.expectEqual(true, isFloat(@Vector(1, f16)));
    try std.testing.expectEqual(false, isFloat(u16));
    try std.testing.expectEqual(false, isFloat(@Vector(1, u16)));
    try std.testing.expectEqual(false, isFloat(u8));
    try std.testing.expectEqual(false, isFloat(@Vector(1, u8)));
}

pub inline fn isInt(comptime T: type) bool {
    const type_info = @typeInfo(T);
    return switch (type_info) {
        .int, .comptime_int => true,
        .vector => isInt(type_info.vector.child),
        else => false,
    };
}

test isInt {
    try std.testing.expectEqual(true, isInt(u16));
    try std.testing.expectEqual(true, isInt(@Vector(1, u16)));
    try std.testing.expectEqual(true, isInt(u8));
    try std.testing.expectEqual(true, isInt(@Vector(1, u8)));
    try std.testing.expectEqual(false, isInt(f32));
    try std.testing.expectEqual(false, isInt(@Vector(1, f32)));
    try std.testing.expectEqual(false, isInt(f16));
    try std.testing.expectEqual(false, isInt(@Vector(1, f16)));
}

pub inline fn isVector(comptime T: type) bool {
    return @typeInfo(T) == .vector;
}

test isVector {
    try std.testing.expectEqual(true, isVector(@Vector(1, u8)));
    try std.testing.expectEqual(false, isVector(u8));
}

pub inline fn isScalar(comptime T: type) bool {
    return !isVector(T);
}

test isScalar {
    try std.testing.expectEqual(true, isScalar(u8));
    try std.testing.expectEqual(false, isScalar(@Vector(1, u8)));
}

pub inline fn getTypeMaximum(comptime T: type, comptime chroma: bool) T {
    return switch (T) {
        u8, u16 => |t| std.math.maxInt(t),
        f16, f32 => if (chroma) 0.5 else 1.0,
        else => unreachable,
    };
}

pub inline fn getTypeMinimum(comptime T: type, comptime chroma: bool) T {
    return switch (T) {
        u8, u16 => 0,
        f16, f32 => if (chroma) -0.5 else 0.0,
        else => unreachable,
    };
}

test "Type max / min" {
    try std.testing.expectEqual(255, getTypeMaximum(u8, false));
    try std.testing.expectEqual(255, getTypeMaximum(u8, true));
    try std.testing.expectEqual(0, getTypeMinimum(u8, false));
    try std.testing.expectEqual(0, getTypeMinimum(u8, true));

    try std.testing.expectEqual(65535, getTypeMaximum(u16, false));
    try std.testing.expectEqual(65535, getTypeMaximum(u16, true));
    try std.testing.expectEqual(0, getTypeMinimum(u16, false));
    try std.testing.expectEqual(0, getTypeMinimum(u16, true));

    try std.testing.expectEqual(1.0, getTypeMaximum(f16, false));
    try std.testing.expectEqual(1.0, getTypeMaximum(f32, false));
    try std.testing.expectEqual(0.5, getTypeMaximum(f16, true));
    try std.testing.expectEqual(0.5, getTypeMaximum(f32, true));
    try std.testing.expectEqual(0.0, getTypeMinimum(f16, false));
    try std.testing.expectEqual(0.0, getTypeMinimum(f32, false));
    try std.testing.expectEqual(-0.5, getTypeMinimum(f16, true));
    try std.testing.expectEqual(-0.5, getTypeMinimum(f32, true));
}

pub fn floatFromInt(comptime T: type, val: anytype) T {
    return @as(T, @floatFromInt(val));
}

/// Determines the minimal type that can be used to store
/// the full value of T (which is expected to be unsigned for integers)
/// without overflowing in signed arithmetic.
pub fn SignedArithmeticType(comptime T: type) type {
    return switch (T) {
        u8 => i16,
        u16 => i32,
        f16 => f16,
        f32 => f32,
        else => unreachable,
    };
}

/// Determines the minimal type to store unsigned values (particularly integers)
/// without overflowing when doing most arithmetic.
///
/// Note that sometimes this type is not big enough, and thus wider types may be required.
pub fn UnsignedArithmeticType(comptime T: type) type {
    if (isScalar(T)) {
        return switch (T) {
            u8 => u16,
            u16 => u32,
            f16 => f16,
            f32 => f32,
            else => unreachable,
        };
    } else {
        // Vector
        const vector_len = @typeInfo(T).vector.len;
        const VC = @typeInfo(T).vector.child;
        return @Vector(vector_len, UnsignedArithmeticType(VC));
    }
}

/// Similar to UnsignedArithmeticType, only bigger. Meant to handle
/// operations where the original unsigned value may be multiplied muliple times
/// over (and thus overflow on smaller types).
pub fn BigUnsignedArithmeticType(comptime T: type) type {
    return switch (T) {
        u8 => u32,
        u16 => u64,
        f16 => f16,
        f32 => f32,
        else => unreachable,
    };
}
