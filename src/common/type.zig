const std = @import("std");

pub inline fn isFloat(comptime T: type) bool {
    const type_info = @typeInfo(T);
    return switch (type_info) {
        .Float => true,
        .Vector => isFloat(type_info.Vector.child),
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
        .Int => true,
        .Vector => isInt(type_info.Vector.child),
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
    return @typeInfo(T) == .Vector;
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
        u8 => 255, // 0xFF
        u16 => 65535, // 0xFFFF
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
