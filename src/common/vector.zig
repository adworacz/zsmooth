/// Common module for operations on vectors.
const std = @import("std");
const assert = std.debug.assert;

/// Loads data from memory to type T data at a specific offset address.
pub fn load(comptime T: type, src: [*]const @typeInfo(T).Vector.child, offset: usize) T {
    return src[offset..][0..@typeInfo(T).Vector.len].*;
}

/// Stores data in a vector into memory at a given offset.
pub fn store(comptime T: type, _dst: [*]@typeInfo(T).Vector.child, offset: usize, result: T) void {
    var dst: [*]@typeInfo(T).Vector.child = @ptrCast(@alignCast(_dst));
    inline for (dst[offset..][0..@typeInfo(T).Vector.len], 0..) |*d, i| {
        d.* = result[i];
    }
}

// Inspired by https://github.com/zig-gamedev/zig-gamedev/blob/main/libs/zmath/src/zmath.zig#L744
pub fn minFast(v0: anytype, v1: anytype) @TypeOf(v0, v1) {
    // Use a fast vector trick for floating point vectors,
    // otherwise use the builtin @min
    if (@typeInfo(@TypeOf(v0)) == .Vector and (@typeInfo(@TypeOf(v0)).Vector.child == f32 or @typeInfo(@TypeOf(v0)).Vector.child == f16)) {
        return @select(@typeInfo(@TypeOf(v0)).Vector.child, v0 < v1, v0, v1);
    }
    return @min(v0, v1);
}

pub fn maxFast(v0: anytype, v1: anytype) @TypeOf(v0, v1) {
    // Use a fast vector trick for floating point vectors,
    // otherwise use the builtin @max
    if (@typeInfo(@TypeOf(v0)) == .Vector and (@typeInfo(@TypeOf(v0)).Vector.child == f32 or @typeInfo(@TypeOf(v0)).Vector.child == f16)) {
        return @select(@typeInfo(@TypeOf(v0)).Vector.child, v0 > v1, v0, v1);
    }
    return @max(v0, v1);
}

pub fn clampFast(v: anytype, vmin: anytype, vmax: anytype) @TypeOf(v, vmin, vmax) {
    return minFast(vmax, maxFast(vmin, v));
}

/// Computes an 'and' of arguments v0 and v1, returning
/// a vector of bools of the same length.
///
/// This is a workaround until Zig properly supports boolean
/// logic on vectors.
///
/// The 'B' in this name simply stands for 'boolean', and is
/// included only to avoid collisions with the zig keyword 'and'.
///
/// Reference: https://github.com/ziglang/zig/issues/14306#issuecomment-1626892042
pub fn andB(v0: anytype, v1: anytype) @Vector(@typeInfo(@TypeOf(v0)).Vector.len, bool) {
    assert(@typeInfo(@TypeOf(v0)).Vector.len == @typeInfo(@TypeOf(v1)).Vector.len);
    assert(@typeInfo(@TypeOf(v0)).Vector.child == bool);
    assert(@typeInfo(@TypeOf(v1)).Vector.child == bool);

    return @select(bool, v0, v1, v0);
}

/// Computes an 'or' of arguments v0 and v1, returning
/// a vector of bools of the same length.
///
/// This is a workaround until Zig properly supports boolean
/// logic on vectors.
///
/// The 'B' in this name simply stands for 'boolean', and is
/// included only to avoid collisions with the zig keyword 'and'.
///
/// Reference: https://github.com/ziglang/zig/issues/14306#issuecomment-1626892042
pub fn orB(v0: anytype, v1: anytype) @Vector(@typeInfo(@TypeOf(v0)).Vector.len, bool) {
    assert(@typeInfo(@TypeOf(v0)).Vector.len == @typeInfo(@TypeOf(v1)).Vector.len);
    assert(@typeInfo(@TypeOf(v0)).Vector.child == bool);
    assert(@typeInfo(@TypeOf(v1)).Vector.child == bool);

    return @select(bool, v0, v0, v1);
}

/// Gets a pertinent vector size for the given type based on the compilation target.
pub inline fn getVecSize(comptime T: type) comptime_int {
    if (std.simd.suggestVectorLength(T)) |suggested| {
        return suggested;
    }

    @compileError("The compilation target does not support vector sizing");
}

test "getVecSize returns reasonable vector sizes" {
    try std.testing.expectEqual(32, getVecSize(u8));
    try std.testing.expectEqual(16, getVecSize(u16));
    try std.testing.expectEqual(16, getVecSize(f16));
    try std.testing.expectEqual(8, getVecSize(f32));
}
