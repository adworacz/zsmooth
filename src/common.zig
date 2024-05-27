const std = @import("std");
const vapoursynth = @import("vapoursynth");
// TODO: Move all Vapoursynth related functions to ./common/vapoursynth.zig
const vs = vapoursynth.vapoursynth4;

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

/////////////////////////////////////////////////
// Video format utilities (value scaling, peak finding, etc)
/////////////////////////////////////////////////

/// Scales an 8 bit value match the pertinent bit depth, sample
/// type, and plane (is/is not chroma).
pub fn scaleToFormat(comptime T: type, vf: vs.VideoFormat, value: u8, plane: anytype) T {
    // Float support, 16-32 bit.
    if (vf.sampleType == vs.SampleType.Float) {
        var out: f32 = @as(f32, @floatFromInt(value)) / 255.0;

        if (vf.colorFamily == vs.ColorFamily.YUV and plane > 0) {
            // YUV floating point chroma planes range from -0.5 to 0.5
            out -= 0.5;
        }

        return lossyCast(T, out);
    }

    // Integer support, 9-16 bit.
    if (vf.bitsPerSample > 8) {
        return lossyCast(T, std.math.shl(u32, value, vf.bitsPerSample - 8));
    }

    // Integer support, 8 bit.
    return lossyCast(T, value);
}

test scaleToFormat {
    // Zig, please let me partially initialize a struct.

    for (0..3) |plane| {
        // 8 bit gray int - should be the same
        try std.testing.expectEqual(128, scaleToFormat(u8, .{
            .sampleType = vs.SampleType.Integer,
            .colorFamily = vs.ColorFamily.Gray,
            .bitsPerSample = 8,
            .bytesPerSample = 1,
            .numPlanes = 3,
            .subSamplingW = 0,
            .subSamplingH = 0,
        }, 128, plane));

        // Check that a different output type still produces the same
        // inherent value.
        try std.testing.expectEqual(128, scaleToFormat(f32, .{
            .sampleType = vs.SampleType.Integer,
            .colorFamily = vs.ColorFamily.Gray,
            .bitsPerSample = 8,
            .bytesPerSample = 1,
            .numPlanes = 3,
            .subSamplingW = 0,
            .subSamplingH = 0,
        }, 128, plane));

        // 8 bit RGB int - should be the same
        try std.testing.expectEqual(128, scaleToFormat(u8, .{
            .sampleType = vs.SampleType.Integer,
            .colorFamily = vs.ColorFamily.RGB,
            .bitsPerSample = 8,
            .bytesPerSample = 1,
            .numPlanes = 3,
            .subSamplingW = 0,
            .subSamplingH = 0,
        }, 128, plane));

        // 8 bit YUV int - should be the same
        try std.testing.expectEqual(128, scaleToFormat(u8, .{
            .sampleType = vs.SampleType.Integer,
            .colorFamily = vs.ColorFamily.YUV,
            .bitsPerSample = 8,
            .bytesPerSample = 1,
            .numPlanes = 3,
            .subSamplingW = 0,
            .subSamplingH = 0,
        }, 128, plane));

        // 10 bit gray int - should be shifted.
        try std.testing.expectEqual(512, scaleToFormat(u16, .{
            .sampleType = vs.SampleType.Integer,
            .colorFamily = vs.ColorFamily.Gray,
            .bitsPerSample = 10,
            .bytesPerSample = 1,
            .numPlanes = 3,
            .subSamplingW = 0,
            .subSamplingH = 0,
        }, 128, plane));

        // 10 bit RGB int - should be shifted.
        try std.testing.expectEqual(512, scaleToFormat(u16, .{
            .sampleType = vs.SampleType.Integer,
            .colorFamily = vs.ColorFamily.RGB,
            .bitsPerSample = 10,
            .bytesPerSample = 1,
            .numPlanes = 3,
            .subSamplingW = 0,
            .subSamplingH = 0,
        }, 128, plane));

        // 10 bit YUV int - should be shifted.
        try std.testing.expectEqual(512, scaleToFormat(u16, .{
            .sampleType = vs.SampleType.Integer,
            .colorFamily = vs.ColorFamily.YUV,
            .bitsPerSample = 10,
            .bytesPerSample = 1,
            .numPlanes = 3,
            .subSamplingW = 0,
            .subSamplingH = 0,
        }, 128, plane));

        // 32 bit gray float - should be divided
        try std.testing.expectApproxEqAbs(0.5, scaleToFormat(f32, .{
            .sampleType = vs.SampleType.Float,
            .colorFamily = vs.ColorFamily.Gray,
            .bitsPerSample = 32,
            .bytesPerSample = 1,
            .numPlanes = 3,
            .subSamplingW = 0,
            .subSamplingH = 0,
        }, 128, plane), 0.01);

        // 32 bit RGB int - should be divided
        try std.testing.expectApproxEqAbs(0.5, scaleToFormat(f32, .{
            .sampleType = vs.SampleType.Float,
            .colorFamily = vs.ColorFamily.RGB,
            .bitsPerSample = 32,
            .bytesPerSample = 1,
            .numPlanes = 3,
            .subSamplingW = 0,
            .subSamplingH = 0,
        }, 128, plane), 0.01);

        // 32 bit YUV int - should be divided.
        // Float should scale for YUV
        const expected: f32 = if (plane == 0) 0.5 else 0;
        try std.testing.expectApproxEqAbs(expected, scaleToFormat(f32, .{
            .sampleType = vs.SampleType.Float,
            .colorFamily = vs.ColorFamily.YUV,
            .bitsPerSample = 32,
            .bytesPerSample = 1,
            .numPlanes = 3,
            .subSamplingW = 0,
            .subSamplingH = 0,
        }, 128, plane), 0.01);
    }
}

pub fn getFormatMaximum(comptime T: type, vf: vs.VideoFormat, chroma: bool) T {
    if (vf.sampleType == vs.SampleType.Float) {
        return lossyCast(T, @as(f32, if (vf.colorFamily == vs.ColorFamily.YUV and chroma) 0.5 else 1.0));
    }

    return lossyCast(T, (@as(u32, 1) << @intCast(vf.bitsPerSample)) - 1);
}

pub fn getFormatMinimum(comptime T: type, vf: vs.VideoFormat, chroma: bool) T {
    if (vf.sampleType == vs.SampleType.Float) {
        return lossyCast(T, @as(f32, if (vf.colorFamily == vs.ColorFamily.YUV and chroma) -0.5 else 0.0));
    }

    return 0;
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

test getFormatMaximum {
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
    const u10_vf: vs.VideoFormat = .{
        .sampleType = vs.SampleType.Integer,
        .colorFamily = vs.ColorFamily.RGB,
        .bitsPerSample = 10,
        .bytesPerSample = 2,
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

    try std.testing.expectEqual(1.0, getFormatMaximum(f32, float_vf, false));
    try std.testing.expectEqual(255, getFormatMaximum(f32, u8_vf, false));
    try std.testing.expectEqual(1023, getFormatMaximum(f32, u10_vf, false));
    try std.testing.expectEqual(65535, getFormatMaximum(f32, u16_vf, false));
}

/// Considers the color family and plane index to determine
/// whether or not it is a chroma plane.
///
/// The concept of "chroma" only relates to YUV color families.
///
/// RGB and Gray color families don't use any concept of chroma planes.
pub fn isChromaPlane(family: vs.ColorFamily, plane: anytype) bool {
    if (family == vs.ColorFamily.YUV) {
        return plane > 0;
    }
    return false;
}

/////////////////////////////////////////////////
// Utilities
/////////////////////////////////////////////////

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
