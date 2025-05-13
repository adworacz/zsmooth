/// Common module for operations on vectors.
const std = @import("std");
const assert = std.debug.assert;

/// Loads a vector of type VT from the specific offset memory address.
pub fn load(comptime VT: type, src: []const @typeInfo(VT).vector.child, offset: usize) VT {
    return src[offset..][0..@typeInfo(VT).vector.len].*;
}

/// Stores vector data into memory at a given offset.
pub fn store(comptime VT: type, _dst: []@typeInfo(VT).vector.child, offset: usize, result: VT) void {
    var dst: []@typeInfo(VT).vector.child = @ptrCast(@alignCast(_dst));
    inline for (dst[offset..][0..@typeInfo(VT).vector.len], 0..) |*d, i| {
        d.* = result[i];
    }
}

// Inspired by https://github.com/zig-gamedev/zig-gamedev/blob/main/libs/zmath/src/zmath.zig#L744
pub fn minFast(v0: anytype, v1: anytype) @TypeOf(v0, v1) {
    // Use a fast vector trick for floating point vectors,
    // otherwise use the builtin @min
    if (@typeInfo(@TypeOf(v0)) == .vector and (@typeInfo(@TypeOf(v0)).vector.child == f32 or @typeInfo(@TypeOf(v0)).vector.child == f16)) {
        return @select(@typeInfo(@TypeOf(v0)).vector.child, v0 < v1, v0, v1);
    }
    return @min(v0, v1);
}

pub fn maxFast(v0: anytype, v1: anytype) @TypeOf(v0, v1) {
    // Use a fast vector trick for floating point vectors,
    // otherwise use the builtin @max
    if (@typeInfo(@TypeOf(v0)) == .vector and (@typeInfo(@TypeOf(v0)).vector.child == f32 or @typeInfo(@TypeOf(v0)).vector.child == f16)) {
        return @select(@typeInfo(@TypeOf(v0)).vector.child, v0 > v1, v0, v1);
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
pub fn andB(v0: anytype, v1: anytype) @Vector(@typeInfo(@TypeOf(v0)).vector.len, bool) {
    assert(@typeInfo(@TypeOf(v0)).vector.len == @typeInfo(@TypeOf(v1)).vector.len);
    assert(@typeInfo(@TypeOf(v0)).vector.child == bool);
    assert(@typeInfo(@TypeOf(v1)).vector.child == bool);

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
pub fn orB(v0: anytype, v1: anytype) @Vector(@typeInfo(@TypeOf(v0)).vector.len, bool) {
    assert(@typeInfo(@TypeOf(v0)).vector.len == @typeInfo(@TypeOf(v1)).vector.len);
    assert(@typeInfo(@TypeOf(v0)).vector.child == bool);
    assert(@typeInfo(@TypeOf(v1)).vector.child == bool);

    return @select(bool, v0, v0, v1);
}

/// Gets a pertinent vector size for the given type based on the compilation target.
// TODO: Rename to getVectorLength, and rename all vec_size variables to vector_len
pub inline fn getVecSize(comptime T: type) comptime_int {
    if (std.simd.suggestVectorLength(T)) |suggested| {
        return suggested;
    }

    @compileError("The compilation target does not support vector sizing");
}

/// Index a slice using a vector containing indexes.
/// Stolen fair and square from:
/// https://github.com/ziglang/zig/issues/12815
///
//TODO: Switch to official "gather" implementation whenever the above link is resolved.
pub fn gather(slice: anytype, index: anytype) @Vector(
    @typeInfo(@TypeOf(index)).vector.len,
    @typeInfo(@TypeOf(slice)).pointer.child,
) {
    const vector_len = @typeInfo(@TypeOf(index)).vector.len;
    const Elem = @typeInfo(@TypeOf(slice)).pointer.child;
    var result: [vector_len]Elem = undefined;
    comptime var vec_i = 0;
    inline while (vec_i < vector_len) : (vec_i += 1) {
        result[vec_i] = slice[index[vec_i]];
    }
    return result;
}

/// Same as gather, but it works with arrays instead of slices (and is strangely faster?)
/// Interestingly, Zig seems to have issues casting an array into a slice in order to use the
/// gather above. I might need to file a bug with Zig on this one.
pub fn gatherArray(array: anytype, index: anytype) @Vector(
    @typeInfo(@TypeOf(index)).vector.len,
    @typeInfo(@TypeOf(array)).array.child,
) {
    const vector_len = @typeInfo(@TypeOf(index)).vector.len;
    const Elem = @typeInfo(@TypeOf(array)).array.child;
    var result: [vector_len]Elem = undefined;
    comptime var vec_i = 0;
    inline while (vec_i < vector_len) : (vec_i += 1) {
        result[vec_i] = array[index[vec_i]];
    }
    return result;
}

test "vector gather" {
    const hello: []const u8 = "hello world";
    const index: @Vector(3, usize) = .{ 1, 3, 5 };
    const result = gather(hello, index);
    try std.testing.expect(@TypeOf(result) == @Vector(3, u8));
    try std.testing.expect(result[0] == 'e');
    try std.testing.expect(result[1] == 'l');
    try std.testing.expect(result[2] == ' ');

}

test "vector gather array" {
    const array = [3]u8{ 0, 1, 2 };
    const index: @Vector(3, usize) = .{ 0, 1, 1 };
    const result = gatherArray(array, index); // error: expected integer, float, bool, or pointer for the vector element type; found '[3]u8'
    try std.testing.expect(result[0] == 0);
    try std.testing.expect(result[1] == 1);
    try std.testing.expect(result[2] == 1);
}
