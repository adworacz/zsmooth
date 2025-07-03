const std = @import("std");
const vapoursynth = @import("vapoursynth");
const ZAPI = vapoursynth.ZAPI;
const testing = @import("std").testing;

const types = @import("common/type.zig");
const vscmn = @import("common/vapoursynth.zig");
const gridcmn = @import("common/array_grid.zig");
const vec = @import("common/vector.zig");
const sort = @import("common/sorting_networks.zig");
const math = @import("common/math.zig");
const lossyCast = math.lossyCast;
const printf = @import("common/string.zig").printf;

const string = @import("common/string.zig");
const float_mode: std.builtin.FloatMode = if (@import("config").optimize_float) .optimized else .strict;

const vs = vapoursynth.vapoursynth4;

const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;
const st = vs.SampleType;

// https://ziglang.org/documentation/master/#Choosing-an-Allocator
//
// Using the C allocator since we're passing pointers to allocated memory between Zig and C code,
// specifically the filter data between the Create and GetFrame functions.
const allocator = std.heap.c_allocator;

const CCDData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,

    vi: *const vs.VideoInfo,

    threshold: f32,
    scale: f32,
};

fn CCD(comptime T: type) type {
    const diameter = 25;
    const radius = diameter / 2;

    const vector_len = vec.getVecSize(T);
    const VT = @Vector(vector_len, T);
    const BSAT = types.BigSignedArithmeticType(T);
    const VBSAT = @Vector(vector_len, BSAT);
    const UAT = types.UnsignedArithmeticType(T);
    const VUAT = @Vector(vector_len, UAT);
    const BUAT = types.BigUnsignedArithmeticType(T);
    const VBUAT = @Vector(vector_len, BUAT);

    return struct {
        fn ccdScalar(comptime mirror: bool, threshold: BUAT, scale: f32, format_min: T, format_max: T, row: usize, column: usize, width: usize, height: usize, stride: usize, src: [3][]const T) struct { T, T, T } {
            @setFloatMode(float_mode);

            const F = if (types.isInt(T)) f32 else T;

            const center_r = src[0][row * stride + column];
            const center_g = src[1][row * stride + column];
            const center_b = src[2][row * stride + column];

            var total_r: UAT = center_r;
            var total_g: UAT = center_g;
            var total_b: UAT = center_b;

            var count: u8 = 0;

            // zig fmt: off
            const scaled_radius: isize = @intFromFloat(@round(radius * scale));
            const start_y: isize = @as(isize, @intCast(row)) - scaled_radius;
            const end_y:   isize = @as(isize, @intCast(row)) + scaled_radius;

            const start_x: isize = @as(isize, @intCast(column)) - scaled_radius;
            const end_x:   isize = @as(isize, @intCast(column)) + scaled_radius;

            const step:    isize = @intFromFloat(@round(8 * scale));
            // zig fmt: on

            // TODO: support different point selections (high/medium/low) like vs-jetpack.
            var y: isize = start_y;
            while (y <= end_y) : (y += step) {
                var x: isize = start_x;
                while (x <= end_x) : (x += step) {
                    const absolute_y: usize = if (mirror) math.mirrorIndex(y, height) else @intCast(y);
                    const absolute_x: usize = if (mirror) math.mirrorIndex(x, width) else @intCast(x);

                    const neighbor_r = src[0][absolute_y * stride + absolute_x];
                    const neighbor_g = src[1][absolute_y * stride + absolute_x];
                    const neighbor_b = src[2][absolute_y * stride + absolute_x];

                    const diff_r: BSAT = lossyCast(BSAT, neighbor_r) - center_r;
                    const diff_g: BSAT = lossyCast(BSAT, neighbor_g) - center_g;
                    const diff_b: BSAT = lossyCast(BSAT, neighbor_b) - center_b;

                    // sum of squared differences
                    const ssd: BUAT = lossyCast(BUAT, diff_r * diff_r) + lossyCast(BUAT, diff_g * diff_g) + lossyCast(BUAT, diff_b * diff_b);

                    if (ssd < threshold) {
                        total_r += neighbor_r;
                        total_g += neighbor_g;
                        total_b += neighbor_b;
                        count += 1;
                    }
                }
            }

            var calculated_r: F = lossyCast(F, total_r) * (1.0 / (lossyCast(F, count) + 1.0));
            var calculated_g: F = lossyCast(F, total_g) * (1.0 / (lossyCast(F, count) + 1.0));
            var calculated_b: F = lossyCast(F, total_b) * (1.0 / (lossyCast(F, count) + 1.0));

            if (types.isInt(T)) {
                // Round int formats before we cast back.
                calculated_r = @round(calculated_r);
                calculated_g = @round(calculated_g);
                calculated_b = @round(calculated_b);
            }

            return .{
                std.math.clamp(lossyCast(T, calculated_r), format_min, format_max),
                std.math.clamp(lossyCast(T, calculated_g), format_min, format_max),
                std.math.clamp(lossyCast(T, calculated_b), format_min, format_max),
            };
        }

        // Only handles non-mirrored content, since mirroring is much more difficult to implement for vectors.
        fn ccdVector(_threshold: BUAT, scale: f32, _format_min: T, _format_max: T, row: usize, column: usize, stride: usize, src: [3][]const T) struct { VT, VT, VT } {
            @setFloatMode(float_mode);

            const F = if (types.isInt(T)) @Vector(vector_len, f32) else VT;

            const threshold: VBUAT = @splat(_threshold);
            const format_min: VT = @splat(_format_min);
            const format_max: VT = @splat(_format_max);

            const center_r = vec.load(VT, src[0], row * stride + column);
            const center_g = vec.load(VT, src[1], row * stride + column);
            const center_b = vec.load(VT, src[2], row * stride + column);

            var total_r: VUAT = center_r;
            var total_g: VUAT = center_g;
            var total_b: VUAT = center_b;

            var count: @Vector(vector_len, u8) = @splat(0);
            const one: @Vector(vector_len, u8) = @splat(1);

            // zig fmt: off
            const scaled_radius: usize = @intFromFloat(@round(radius * scale));
            const start_y = row - scaled_radius;
            const end_y   = row + scaled_radius;

            const start_x = column - scaled_radius;
            const end_x   = column + scaled_radius;

            const step: usize = @intFromFloat(@round(8 * scale));
            // zig fmt: on

            // TODO: support different point selections (high/medium/low) like vs-jetpack.
            var y: usize = start_y;
            while (y <= end_y) : (y += step) {
                var x: usize = start_x;
                while (x <= end_x) : (x += step) {
                    const neighbor_r = vec.load(VT, src[0], y * stride + x);
                    const neighbor_g = vec.load(VT, src[1], y * stride + x);
                    const neighbor_b = vec.load(VT, src[2], y * stride + x);

                    const diff_r: VBSAT = lossyCast(VBSAT, neighbor_r) - center_r;
                    const diff_g: VBSAT = lossyCast(VBSAT, neighbor_g) - center_g;
                    const diff_b: VBSAT = lossyCast(VBSAT, neighbor_b) - center_b;

                    // sum of squared differences
                    const ssd: VBUAT = lossyCast(VBUAT, diff_r * diff_r) + lossyCast(VBUAT, diff_g * diff_g) + lossyCast(VBUAT, diff_b * diff_b);

                    const ssd_lt_threshold = ssd < threshold;
                    total_r = @select(UAT, ssd_lt_threshold, total_r + neighbor_r, total_r);
                    total_g = @select(UAT, ssd_lt_threshold, total_g + neighbor_g, total_g);
                    total_b = @select(UAT, ssd_lt_threshold, total_b + neighbor_b, total_b);
                    count = @select(u8, ssd_lt_threshold, count + one, count);
                }
            }

            const one_point_zero: F = @splat(1.0);
            var calculated_r: F = lossyCast(F, total_r) * (one_point_zero / (lossyCast(F, count) + one_point_zero));
            var calculated_g: F = lossyCast(F, total_g) * (one_point_zero / (lossyCast(F, count) + one_point_zero));
            var calculated_b: F = lossyCast(F, total_b) * (one_point_zero / (lossyCast(F, count) + one_point_zero));

            if (types.isInt(T)) {
                // Round int formats before we cast back.
                calculated_r = @round(calculated_r);
                calculated_g = @round(calculated_g);
                calculated_b = @round(calculated_b);
            }

            return .{
                std.math.clamp(lossyCast(VT, calculated_r), format_min, format_max),
                std.math.clamp(lossyCast(VT, calculated_g), format_min, format_max),
                std.math.clamp(lossyCast(VT, calculated_b), format_min, format_max),
            };
        }

        // TODO: Add scale support. Low priority, since this function is currently unused.
        fn processPlanesScalar(threshold: BUAT, format_min: T, format_max: T, src: [3][]const T, dst: [3][]T, width: usize, height: usize, stride: usize) void {
            // Process top rows with mirrored grid.
            for (0..radius) |row| {
                for (0..width) |column| {
                    const result = ccdScalar(true, threshold, format_min, format_max, row, column, width, height, stride, src);

                    dst[0][(row * stride) + column] = result[0];
                    dst[1][(row * stride) + column] = result[1];
                    dst[2][(row * stride) + column] = result[2];
                }
            }

            for (radius..height - radius) |row| {
                // Process first pixels of the row with mirrored grid.
                for (0..radius) |column| {
                    const result = ccdScalar(true, threshold, format_min, format_max, row, column, width, height, stride, src);

                    dst[0][(row * stride) + column] = result[0];
                    dst[1][(row * stride) + column] = result[1];
                    dst[2][(row * stride) + column] = result[2];
                }

                for (radius..width - radius) |column| {
                    // Use a non-mirrored grid everywhere else for maximum performance.
                    // We don't need the mirror effect anyways, as all pixels contain valid data.
                    const result = ccdScalar(false, threshold, format_min, format_max, row, column, width, height, stride, src);

                    dst[0][(row * stride) + column] = result[0];
                    dst[1][(row * stride) + column] = result[1];
                    dst[2][(row * stride) + column] = result[2];
                }

                // Process last pixel of the row with mirrored grid.
                for (width - radius..width) |column| {
                    const result = ccdScalar(true, threshold, format_min, format_max, row, column, width, height, stride, src);

                    dst[0][(row * stride) + column] = result[0];
                    dst[1][(row * stride) + column] = result[1];
                    dst[2][(row * stride) + column] = result[2];
                }
            }

            // Process bottom rows with mirrored grid.
            for (height - radius..height) |row| {
                for (0..width) |column| {
                    const result = ccdScalar(true, threshold, format_min, format_max, row, column, width, height, stride, src);

                    dst[0][(row * stride) + column] = result[0];
                    dst[1][(row * stride) + column] = result[1];
                    dst[2][(row * stride) + column] = result[2];
                }
            }
        }

        fn processPlanesVector(threshold: BUAT, scale: f32, format_min: T, format_max: T, src: [3][]const T, dst: [3][]T, width: usize, height: usize, stride: usize) void {
            // We make some assumptions in this code in order to make processing with vectors simpler.
            std.debug.assert(width >= vector_len);
            std.debug.assert(radius < vector_len);

            const scaled_radius: usize = @intFromFloat(@round(radius * scale));
            const scaled_diameter: usize = @intFromFloat(@round(diameter * scale));
            const width_simd = (width - scaled_diameter) / vector_len * vector_len;

            // Top rows - mirrored
            for (0..scaled_radius) |row| {
                for (0..width) |column| {
                    const result = ccdScalar(true, threshold, scale, format_min, format_max, row, column, width, height, stride, src);

                    dst[0][(row * stride) + column] = result[0];
                    dst[1][(row * stride) + column] = result[1];
                    dst[2][(row * stride) + column] = result[2];
                }
            }

            // Middle rows
            for (scaled_radius..height - scaled_radius) |row| {
                // First columns - mirrored
                for (0..scaled_radius) |column| {
                    const result = ccdScalar(true, threshold, scale, format_min, format_max, row, column, width, height, stride, src);

                    dst[0][(row * stride) + column] = result[0];
                    dst[1][(row * stride) + column] = result[1];
                    dst[2][(row * stride) + column] = result[2];
                }

                // Middle columns - not mirrored
                var column: usize = scaled_radius;
                while (column < width_simd) : (column += vector_len) {
                    const result = ccdVector(threshold, scale, format_min, format_max, row, column, stride, src);

                    vec.store(VT, dst[0], row * stride + column, result[0]);
                    vec.store(VT, dst[1], row * stride + column, result[1]);
                    vec.store(VT, dst[2], row * stride + column, result[2]);
                }

                // Last columns - non-mirrored
                // We do this to minimize the use of scalar mirror code.
                if (width_simd < width) {
                    const adjusted_column = width - vector_len - scaled_radius;
                    const result = ccdVector(threshold, scale, format_min, format_max, row, adjusted_column, stride, src);

                    vec.store(VT, dst[0], row * stride + adjusted_column, result[0]);
                    vec.store(VT, dst[1], row * stride + adjusted_column, result[1]);
                    vec.store(VT, dst[2], row * stride + adjusted_column, result[2]);
                }

                // Last columns - mirrored
                for (width - scaled_radius..width) |c| {
                    const result = ccdScalar(true, threshold, scale, format_min, format_max, row, c, width, height, stride, src);

                    dst[0][(row * stride) + c] = result[0];
                    dst[1][(row * stride) + c] = result[1];
                    dst[2][(row * stride) + c] = result[2];
                }
            }

            // Bottom rows - mirrored
            for (height - scaled_radius..height) |row| {
                for (0..width) |column| {
                    const result = ccdScalar(true, threshold, scale, format_min, format_max, row, column, width, height, stride, src);

                    dst[0][(row * stride) + column] = result[0];
                    dst[1][(row * stride) + column] = result[1];
                    dst[2][(row * stride) + column] = result[2];
                }
            }
        }

        fn processPlanes(_threshold: f32, scale: f32, chroma: bool, bits_per_sample: u6, srcp8: [3][]const u8, dstp8: [3][]u8, width: usize, height: usize, stride8: usize) void {
            const threshold: BUAT = lossyCast(BUAT, _threshold);
            const stride = stride8 / @sizeOf(T);
            const srcp: [3][]const T = .{
                @ptrCast(@alignCast(srcp8[0])),
                @ptrCast(@alignCast(srcp8[1])),
                @ptrCast(@alignCast(srcp8[2])),
            };
            const dstp: [3][]T = .{
                @ptrCast(@alignCast(dstp8[0])),
                @ptrCast(@alignCast(dstp8[1])),
                @ptrCast(@alignCast(dstp8[2])),
            };

            const format_max = vscmn.getFormatMaximum2(T, bits_per_sample, chroma);
            const format_min = vscmn.getFormatMinimum2(T, chroma);

            processPlanesVector(threshold, scale, format_min, format_max, srcp, dstp, width, height, stride);
        }
    };
}

fn ccdGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const zapi = ZAPI.init(vsapi, core);
    const d: *CCDData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        zapi.requestFrameFilter(n, d.node, frame_ctx);
    } else if (activation_reason == ar.AllFramesReady) {
        const src_frame = zapi.initZFrame(d.node, n, frame_ctx);
        defer src_frame.deinit();

        const dst = src_frame.newVideoFrame();

        const processPlanes: @TypeOf(&CCD(u8).processPlanes) = switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &CCD(u8).processPlanes,
            .U16 => &CCD(u16).processPlanes,
            .F16 => &CCD(f16).processPlanes,
            .F32 => &CCD(f32).processPlanes,
        };

        // Width, height, and stride are the same for all planes,
        // so just using values from the first one.
        const width: usize = dst.getWidth(0);
        const height: usize = dst.getHeight(0);
        const stride8: usize = dst.getStride(0);
        const srcp8: [3][]const u8 = .{
            src_frame.getReadSlice(0),
            src_frame.getReadSlice(1),
            src_frame.getReadSlice(2),
        };
        const dstp8: [3][]u8 = .{
            dst.getWriteSlice(0),
            dst.getWriteSlice(1),
            dst.getWriteSlice(2),
        };
        const chroma = vscmn.isChromaPlane(d.vi.format.colorFamily, 0);
        const bits_per_sample: u6 = @intCast(d.vi.format.bitsPerSample);

        processPlanes(d.threshold, d.scale, chroma, bits_per_sample, srcp8, dstp8, width, height, stride8);

        return dst.frame;
    }

    return null;
}

export fn ccdFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *CCDData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn ccdCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    const zapi = ZAPI.init(vsapi, core);
    const inz = zapi.initZMap(in);
    // const outz = zapi.initZMap(out);
    //
    // TODO:
    // 1. Add scale support
    // 2. Add temporal support.
    // 3. Add different points support.

    var d: CCDData = undefined;

    d.node, d.vi = inz.getNodeVi("clip").?;

    const format_max = vscmn.getFormatMaximum(f32, d.vi.format, false);

    d.threshold = inz.getFloat(f32, "threshold") orelse 4;
    d.threshold = d.threshold * format_max; // Scale to input bit depth for consitency across inputs.
    d.threshold = (d.threshold * d.threshold) / (255 * 255 * 3); // squared euclidian, scaled to sum of sqaured differences for float.

    d.scale = inz.getFloat(f32, "scale") orelse @as(f32, @floatFromInt(d.vi.height)) / 240.0;

    const data: *CCDData = allocator.create(CCDData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
    };

    zapi.createVideoFilter(out, "CCD", d.vi, ccdGetFrame, ccdFree, fm.Parallel, &deps, data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("CCD", "clip:vnode;threshold:float:opt;scale:float:opt;", "clip:vnode;", ccdCreate, null, plugin);
}
