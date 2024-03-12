const std = @import("std");
const vapoursynth = @import("vapoursynth");
const vs = vapoursynth.vapoursynth4;

/// Gets a pertinent vector size for the given type based on the compilation target.
pub inline fn GetVecSize(comptime T: type) comptime_int {
    if (std.simd.suggestVectorLength(T)) |suggested| {
        return suggested;
    }

    @compileError("The compilation target does not support vector sizing");
}

test "GetVecSize returns reasonable vector sizes" {
    try std.testing.expectEqual(32, GetVecSize(u8));
    try std.testing.expectEqual(16, GetVecSize(u16));
    try std.testing.expectEqual(16, GetVecSize(f16));
    try std.testing.expectEqual(8, GetVecSize(f32));
}

pub inline fn IsFloat(comptime T: type) bool {
    return @typeInfo(T) == .Float;
}

test IsFloat {
    try std.testing.expectEqual(true, IsFloat(f32));
    try std.testing.expectEqual(true, IsFloat(f16));
    try std.testing.expectEqual(false, IsFloat(u16));
    try std.testing.expectEqual(false, IsFloat(u8));
}

/////////////////////////////////////////////////
// Video format utilities (value scaling, peak finding, etc)
/////////////////////////////////////////////////

/// Scales a value from 8bit to the bit depth pertinent to the provided type.
/// Use the chroma param to indicate if the value is for a chroma plane,
/// which range from -0.5 to 0.5 instead of 0.0-1.0 like the luma plane
pub fn scale_8bit(comptime T: type, value: u8, chroma: bool) T {
    if (T == f16 or T == f32) {
        const out = @as(T, @floatFromInt(value)) / 255.0;

        if (chroma) {
            return out - 0.5;
        }

        return out;
    }

    return @as(T, @intCast(value)) << (@bitSizeOf(T) - 8);
}

test scale_8bit {
    try std.testing.expectEqual(1, scale_8bit(u8, 1, false));
    try std.testing.expectEqual(256, scale_8bit(u16, 1, false));
    try std.testing.expectEqual(1.0 / 255.0, scale_8bit(f32, 1, false));
    try std.testing.expectEqual((1.0 / 255.0) - 0.5, scale_8bit(f32, 1, true));
}

// TODO: Add tests for this function.
// TODO: rename "scale_to_sample", since this scales based on sample type
// and *not* the size of the containing type.
pub fn scale_8bit_to_format(vf: vs.VideoFormat, value: u8) u32 {
    // Float support, 16-32 bit.
    if (vf.sampleType == vs.SampleType.Float) {
        return @bitCast(@as(f32, @floatFromInt(value)) / 255.0);
    }

    // Integer support, 9-16 bit.
    if (vf.bitsPerSample > 8) {
        return std.math.shl(u32, value, vf.bitsPerSample - 8);
    }

    // Integer support, 8 bit.
    return value;
}

pub fn get_peak(vf: vs.VideoFormat) u32 {
    if (vf.sampleType == vs.SampleType.Float) {
        return @bitCast(@as(f32, 1.0));
    }

    return switch (vf.bytesPerSample) {
        1 => 255,
        2 => 65535,
        else => unreachable,
    };
}

test get_peak {
    const float_vf: vs.VideoFormat = .{
        .sampleType = vs.SampleType.Float,
        .colorFamily = vs.ColorFamily.RGB,
        .bitsPerSample = 32,
        .bytesPerSample = 4,
        .numPlanes = 3,
        .subSamplingW = 2,
        .subSamplingH = 2,
    };
    const u8_vf: vs.VideoFormat = .{
        .sampleType = vs.SampleType.Integer,
        .colorFamily = vs.ColorFamily.RGB,
        .bitsPerSample = 8,
        .bytesPerSample = 1,
        .numPlanes = 3,
        .subSamplingW = 2,
        .subSamplingH = 2,
    };
    const u16_vf: vs.VideoFormat = .{
        .sampleType = vs.SampleType.Integer,
        .colorFamily = vs.ColorFamily.RGB,
        .bitsPerSample = 16,
        .bytesPerSample = 2,
        .numPlanes = 3,
        .subSamplingW = 2,
        .subSamplingH = 2,
    };

    try std.testing.expectEqual(1.0, @as(f32, @bitCast(get_peak(float_vf))));
    try std.testing.expectEqual(255, get_peak(u8_vf));
    try std.testing.expectEqual(65535, get_peak(u16_vf));
}

/////////////////////////////////////////////////
// Utilities
/////////////////////////////////////////////////

/// Finds the min/max of the values of a and b and then assigns
/// the min value to a and the max value to b, effectively sorting the results.
pub fn compare_swap(comptime T: type, a: *T, b: *T) void {
    const min = @min(a.*, b.*);
    b.* = @max(a.*, b.*);
    a.* = min;
}

test compare_swap {
    var a: u8 = 5;
    var b: u8 = 1;

    compare_swap(u8, &a, &b);
    try std.testing.expectEqual(1, a);
    try std.testing.expectEqual(5, b);

    a = 6;
    b = 10;

    compare_swap(u8, &a, &b);
    try std.testing.expectEqual(6, a);
    try std.testing.expectEqual(10, b);

    var d = @Vector(1, u8){5};
    var e = @Vector(1, u8){1};

    compare_swap(@Vector(1, u8), &d, &e);
    try std.testing.expectEqual(@Vector(1, u8){1}, d);
    try std.testing.expectEqual(@Vector(1, u8){5}, e);
}

/////////////////////////////////////////////////
// Vector handling
/////////////////////////////////////////////////

pub fn loadVec(comptime T: type, src: [*]const @typeInfo(T).Vector.child, offset: usize) T {
    return src[offset..][0..@typeInfo(T).Vector.len].*;
}

pub fn storeVec(comptime T: type, _dst: [*]@typeInfo(T).Vector.child, offset: usize, result: T) void {
    var dst: [*]@typeInfo(T).Vector.child = @ptrCast(@alignCast(_dst));
    inline for (dst[offset..][0..@typeInfo(T).Vector.len], 0..) |*d, i| {
        d.* = result[i];
    }
}

// Really seems to be faster for floats, with no real difference for 8/16 bit integer.
// TODO needs more testing. Maybe *slightly* faster than @min/@max, but it's not a major difference.
// Good testing is provided in TemporalMedian, Radius 4, with 8, 16, and 32 bit depth.
// Inspired by https://github.com/zig-gamedev/zig-gamedev/blob/main/libs/zmath/src/zmath.zig#L744
pub fn minFastVec(v0: anytype, v1: anytype) @TypeOf(v0, v1) {
    return @select(@typeInfo(@TypeOf(v0)).Vector.child, v0 < v1, v0, v1);
}

pub fn maxFastVec(v0: anytype, v1: anytype) @TypeOf(v0, v1) {
    return @select(@typeInfo(@TypeOf(v0)).Vector.child, v0 > v1, v0, v1);
}

pub fn clampFastVec(v: anytype, vmin: anytype, vmax: anytype) @TypeOf(v, vmin, vmax) {
    return minFastVec(vmax, maxFastVec(vmin, v));
}

//////////////////////////////////////////////////
// String formatting
//////////////////////////////////////////////////

/// Convience funtion for writing strings / error messages that we pass back to
/// the vapoursynth C API.
///
/// Note that passing these strings back to Vapoursynth effectively means that
/// we're going to *leak memory when the program exits, but there's nothing we
/// can do about that due to the realities of the C interop.
pub fn printf(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) []const u8 {
    return std.fmt.allocPrintZ(allocator, fmt, args) catch "Out of memory occurred while writing string.";
}

// TODO: Debug this test, seems to be freeing less memory than was allocated.
// test printf {
//     const msg = printf(std.testing.allocator, "Hello {s}", .{"world"});
//     defer std.testing.allocator.free(msg);
//
//     try std.testing.expectEqualStrings("Hello world", msg);
// }

/// Reports an error to the VS API and frees the input node;
pub fn reportError(msg: []u8, vsapi: vs.API, out: vs.Map, node: vs.Node) void {
    vsapi.?.mapSetError.?(out, msg);
    vsapi.?.freeNode.?(node);
    return;
}
