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

/// Scales a value from 8bit to the desired
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

pub inline fn loadVec(vec_size: comptime_int, comptime T: type, src: [*]const T, offset: usize) @Vector(vec_size, T) {
    return src[offset..][0..vec_size].*;
}

pub inline fn storeVec(vec_size: comptime_int, comptime T: type, _dst: [*]T, offset: usize, result: @Vector(vec_size, T)) void {
    var dst: [*]T = @ptrCast(@alignCast(_dst));
    inline for (dst[offset..][0..vec_size], 0..) |*d, i| {
        d.* = result[i];
    }
}
