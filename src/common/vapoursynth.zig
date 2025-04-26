const std = @import("std");
const vapoursynth = @import("vapoursynth");

const lossyCast = @import("math.zig").lossyCast;
const getVecSize = @import("vector.zig").getVecSize;

const vs = vapoursynth.vapoursynth4;
const vsh = vapoursynth.vshelper;

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

test "Format maximum and minimum" {
    const float_vf: vs.VideoFormat = .{
        .sampleType = vs.SampleType.Float,
        .colorFamily = vs.ColorFamily.RGB,
        .bitsPerSample = 32,
        .bytesPerSample = 4,
        .numPlanes = 3,
        .subSamplingW = 2,
        .subSamplingH = 2,
    };
    const float_yuv_vf: vs.VideoFormat = .{
        .sampleType = vs.SampleType.Float,
        .colorFamily = vs.ColorFamily.YUV,
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
    try std.testing.expectEqual(1.0, getFormatMaximum(f32, float_yuv_vf, false));
    try std.testing.expectEqual(0.0, getFormatMinimum(f32, float_vf, false));
    try std.testing.expectEqual(0.0, getFormatMinimum(f32, float_vf, true));
    try std.testing.expectEqual(-0.5, getFormatMinimum(f32, float_yuv_vf, true));

    try std.testing.expectEqual(255, getFormatMaximum(f32, u8_vf, false));
    try std.testing.expectEqual(0, getFormatMinimum(f32, u8_vf, false));

    try std.testing.expectEqual(1023, getFormatMaximum(f32, u10_vf, false));
    try std.testing.expectEqual(0, getFormatMinimum(f32, u10_vf, false));

    try std.testing.expectEqual(65535, getFormatMaximum(f32, u16_vf, false));
    try std.testing.expectEqual(0, getFormatMinimum(f32, u16_vf, false));
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

test isChromaPlane {
    try std.testing.expectEqual(false, isChromaPlane(vs.ColorFamily.RGB, 0));
    try std.testing.expectEqual(false, isChromaPlane(vs.ColorFamily.RGB, 1));
    try std.testing.expectEqual(false, isChromaPlane(vs.ColorFamily.RGB, 2));

    try std.testing.expectEqual(false, isChromaPlane(vs.ColorFamily.Gray, 0));

    try std.testing.expectEqual(false, isChromaPlane(vs.ColorFamily.YUV, 0));
    try std.testing.expectEqual(true, isChromaPlane(vs.ColorFamily.YUV, 1));
    try std.testing.expectEqual(true, isChromaPlane(vs.ColorFamily.YUV, 2));
}

// Returns the recommended vector (SIMD) length of the given video format.
//
// This is useful for ensuring that we can always use vectorized algorithms for
// optimal speed.
//
// Luckily, the required width here is actually quite small.
//
// For 8 bit (which is the smallest data type and thus requires the greatest
// number of pixels to fill), we need a minimum of 64 pixels on AVX512, and 32
// pixels on AVX2.
//
pub fn formatVectorLength(format: vs.VideoFormat) u8 {
    const sample_type = format.sampleType;
    const num_bytes = format.bytesPerSample;

    return switch (num_bytes) {
        1 => getVecSize(u8),
        2 => if (sample_type == .Integer) getVecSize(u16) else getVecSize(f16),
        4 => getVecSize(f32),
        else => unreachable,
    };
}

test formatVectorLength {
    const u8_format = vs.VideoFormat{
        .bytesPerSample = 1,
        .sampleType = vs.SampleType.Integer,

        .colorFamily = vs.ColorFamily.RGB,
        .bitsPerSample = 8,
        .numPlanes = 3,
        .subSamplingW = 2,
        .subSamplingH = 2,
    };

    const u16_format = vs.VideoFormat{
        .bytesPerSample = 2,
        .sampleType = vs.SampleType.Integer,

        .colorFamily = vs.ColorFamily.RGB,
        .bitsPerSample = 16,
        .numPlanes = 3,
        .subSamplingW = 2,
        .subSamplingH = 2,
    };

    const f16_format = vs.VideoFormat{
        .bytesPerSample = 2,
        .sampleType = vs.SampleType.Float,

        .colorFamily = vs.ColorFamily.RGB,
        .bitsPerSample = 16,
        .numPlanes = 3,
        .subSamplingW = 2,
        .subSamplingH = 2,
    };

    const f32_format = vs.VideoFormat{
        .bytesPerSample = 4,
        .sampleType = vs.SampleType.Float,

        .colorFamily = vs.ColorFamily.RGB,
        .bitsPerSample = 32,
        .numPlanes = 3,
        .subSamplingW = 2,
        .subSamplingH = 2,
    };

    try std.testing.expectEqual(getVecSize(u8), formatVectorLength(u8_format));
    try std.testing.expectEqual(getVecSize(u16), formatVectorLength(u16_format));
    try std.testing.expectEqual(getVecSize(f16), formatVectorLength(f16_format));
    try std.testing.expectEqual(getVecSize(f32), formatVectorLength(f32_format));
}

/// Creates a new video frame with optional copying of source planes from a src
/// frame. The copies are goverened by the boolean values in the `process`
/// variable. If the value is true, then its expected to be proccessed by the
/// caller, and thus is *not* copied from the src frame.
///
/// If the value is false, then the plane is copied from the source frame.
pub fn newVideoFrame(process: *const [3]bool, src: ?*const vs.Frame, vi: *const vs.VideoInfo, core: ?*vs.Core, vsapi: ?*const vs.API) ?*vs.Frame {
    // Prepare array of frame pointers, with null for planes we will process,
    // and pointers to the source frame for planes we won't process.
    var plane_src = [_]?*const vs.Frame{
        if (process[0]) null else src,
        if (process[1]) null else src,
        if (process[2]) null else src,
    };
    const planes = [_]c_int{ 0, 1, 2 };

    return vsapi.?.newVideoFrame2.?(&vi.format, vi.width, vi.height, @ptrCast(&plane_src), @ptrCast(&planes), src, core);
}

pub const PlanesError = error{
    IndexOutOfRange,
    SpecifiedTwice,
};

/// Handles coercing plane specifications from user input into a usable
/// process array.
///
/// Specifically it handles input like:
/// planes=[1]
/// planes=[0,1,2]
/// planes=2
///
/// It will error if a plane is out of range (like 999) or
/// if the plane has been specified twice (like [1,1]).
pub fn normalizePlanes(format: vs.VideoFormat, in: ?*const vs.Map, vsapi: ?*const vs.API) PlanesError![3]bool {
    //mapNumElements returns -1 if the element doesn't exist (aka, the user doesn't specify the option.)
    const requestedPlanesSize = vsapi.?.mapNumElements.?(in, "planes");
    const requestedPlanesIsEmpty = requestedPlanesSize <= 0;
    const numPlanes = format.numPlanes;
    var process = [_]bool{ requestedPlanesIsEmpty, requestedPlanesIsEmpty, requestedPlanesIsEmpty };

    if (!requestedPlanesIsEmpty) {
        for (0..@intCast(requestedPlanesSize)) |i| {
            const plane: u8 = vsh.mapGetN(u8, in, "planes", @intCast(i), vsapi) orelse unreachable;

            if (plane < 0 or plane > numPlanes) {
                return PlanesError.IndexOutOfRange;
            }

            if (process[plane]) {
                return PlanesError.SpecifiedTwice;
            }

            process[plane] = true;
        }
    }
    return process;
}

/// Reports an error to the VS API and frees the input node;
pub fn reportError(msg: []const u8, vsapi: ?*const vs.API, out: ?*vs.Map, node: ?*vs.Node) void {
    vsapi.?.mapSetError.?(out, msg.ptr);
    vsapi.?.freeNode.?(node);
    return;
}

const SoftThresholdParams = struct { bias: f32, threshold_lower: f32, threshold_upper: f32, threshold_scale: f32 };

/// Calculates a set of parameters that can be used to soft-threshold specific pixel values.
/// Note that this is not the full calculation of the soft-threshold, just the parameters used in its calculation.
pub fn calculateSoftThresholdParams(format: vs.VideoFormat, threshold: f32, scalep: bool) SoftThresholdParams {
    // const chroma = format.colorFamily == vs.ColorFamily.YUV and i > 0;
    const format_max = getFormatMaximum(f32, format, false);
    // const format_min = getFormatMinimum(f32, format, chroma);
    const th = if (scalep) scaleToFormat(f32, format, threshold, 0) else threshold;
    const mult = if (scalep) threshold / 255 else threshold / format_max;
    const bias = @min(2 * @cos(std.math.pi + (2 * std.math.pi * mult)) + 2, 1) * 20;
    const bias_scaled = scaleToFormat(f32, format, bias, 0);
    const thr_lower = @max(th - scaleToFormat(f32, format, 10, 0) - bias_scaled, 0); // lower threshold
    const thr_upper = @min(th + scaleToFormat(f32, format, 10, 0) + bias_scaled, format_max); // higher threshold
    const thr_scale = format_max / (thr_upper - thr_lower);

    return .{
        .bias = bias,
        .threshold_lower = thr_lower,
        .threshold_upper = thr_upper,
        .threshold_scale = thr_scale,
    };
}

test calculateSoftThresholdParams {
    const u8_format = vs.VideoFormat{
        .bytesPerSample = 1,
        .sampleType = vs.SampleType.Integer,

        .colorFamily = vs.ColorFamily.YUV,
        .bitsPerSample = 8,
        .numPlanes = 3,
        .subSamplingW = 2,
        .subSamplingH = 2,
    };

    const u16_format = vs.VideoFormat{
        .bytesPerSample = 2,
        .sampleType = vs.SampleType.Integer,

        .colorFamily = vs.ColorFamily.YUV,
        .bitsPerSample = 16,
        .numPlanes = 3,
        .subSamplingW = 2,
        .subSamplingH = 2,
    };
    //
    // const f16_format = vs.VideoFormat{
    //     .bytesPerSample = 2,
    //     .sampleType = vs.SampleType.Float,
    //
    //     .colorFamily = vs.ColorFamily.YUV,
    //     .bitsPerSample = 16,
    //     .numPlanes = 3,
    //     .subSamplingW = 2,
    //     .subSamplingH = 2,
    // };
    //
    const f32_format = vs.VideoFormat{
        .bytesPerSample = 4,
        .sampleType = vs.SampleType.Float,

        .colorFamily = vs.ColorFamily.YUV,
        .bitsPerSample = 32,
        .numPlanes = 3,
        .subSamplingW = 2,
        .subSamplingH = 2,
    };

    // Lower bound

    // 8 bit - scalep = true (no-op)
    var params = calculateSoftThresholdParams(u8_format, 0, true);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 0,
        .threshold_lower = 0,
        .threshold_upper = 10,
        .threshold_scale = 25.5,
    }, params);

    // 8 bit - scalep = false (no-op)
    params = calculateSoftThresholdParams(u8_format, 0, false);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 0,
        .threshold_lower = 0,
        .threshold_upper = 10,
        .threshold_scale = 25.5,
    }, params);

    // 16 bit - scalep = true
    params = calculateSoftThresholdParams(u16_format, 0, true);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 0,
        .threshold_lower = 0,
        .threshold_upper = 2560,
        .threshold_scale = 25.59961,
    }, params);

    // 16 bit - scalep = false
    params = calculateSoftThresholdParams(u16_format, 0, false);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 0,
        .threshold_lower = 0,
        .threshold_upper = 2560,
        .threshold_scale = 25.59961,
    }, params);

    // 32 bit - scalep = true
    params = calculateSoftThresholdParams(f32_format, 0, true);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 0,
        .threshold_lower = 0,
        .threshold_upper = 0.039215688,
        .threshold_scale = 25.5,
    }, params);

    // 32 bit - scalep = false
    params = calculateSoftThresholdParams(f32_format, 0, false);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 0,
        .threshold_lower = 0,
        .threshold_upper = 0.039215688,
        .threshold_scale = 25.5,
    }, params);

    // Somewhere in the middle.

    // 8 bit - scalep = true (no-op)
    params = calculateSoftThresholdParams(u8_format, 30, true);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 10.439644,
        .threshold_lower = 9.560356,
        .threshold_upper = 50.439644,
        .threshold_scale = 6.237878,
    }, params);

    // 8 bit - scalep = false (no-op)
    params = calculateSoftThresholdParams(u8_format, 30, false);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 10.439644,
        .threshold_lower = 9.560356,
        .threshold_upper = 50.439644,
        .threshold_scale = 6.237878,
    }, params);

    // 16 bit - scalep = true
    params = calculateSoftThresholdParams(u16_format, 30, true);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 10.439644,
        .threshold_lower = 2447.4512,
        .threshold_upper = 12912.549,
        .threshold_scale = 6.2622447,
    }, params);

    // 16 bit - scalep = false
    params = calculateSoftThresholdParams(u16_format, 30 << 8, false);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 10.362263,
        .threshold_lower = 2467.2607,
        .threshold_upper = 12892.739,
        .threshold_scale = 6.286042,
    }, params);

    // 32 bit - scalep = true
    params = calculateSoftThresholdParams(f32_format, 30, true);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 10.439644,
        .threshold_lower = 0.03749159,
        .threshold_upper = 0.19780253,
        .threshold_scale = 6.2378774,
    }, params);

    // 32 bit - scalep = false
    params = calculateSoftThresholdParams(f32_format, 30.0 / 255.0, false);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 10.439644,
        .threshold_lower = 0.03749159,
        .threshold_upper = 0.19780253,
        .threshold_scale = 6.2378774,
    }, params);

    // Upper bound

    // 8 bit - scalep = true (no-op)
    params = calculateSoftThresholdParams(u8_format, 255, true);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 0,
        .threshold_lower = 245,
        .threshold_upper = 255,
        .threshold_scale = 25.5,
    }, params);

    // 8 bit - scalep = false (no-op)
    params = calculateSoftThresholdParams(u8_format, 255, false);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 0,
        .threshold_lower = 245,
        .threshold_upper = 255,
        .threshold_scale = 25.5,
    }, params);

    // 16 bit - scalep = true
    params = calculateSoftThresholdParams(u16_format, 255, true);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 0,
        .threshold_lower = 62720,
        .threshold_upper = 65535,
        .threshold_scale = 23.28064,
    }, params);

    // 16 bit - scalep = false
    params = calculateSoftThresholdParams(u16_format, 255 << 8, false);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 0.011954308,
        .threshold_lower = 62716.94,
        .threshold_upper = 65535,
        .threshold_scale = 23.255371,
    }, params);

    // 32 bit - scalep = true
    params = calculateSoftThresholdParams(f32_format, 255, true);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 0.0,
        .threshold_lower = 0.9607843,
        .threshold_upper = 1.0,
        .threshold_scale = 25.500002,
    }, params);

    // 32 bit - scalep = false
    params = calculateSoftThresholdParams(f32_format, 255.0 / 255.0, false);
    try std.testing.expectEqualDeep(SoftThresholdParams{
        .bias = 0.0,
        .threshold_lower = 0.9607843,
        .threshold_upper = 1.0,
        .threshold_scale = 25.500002,
    }, params);
}
