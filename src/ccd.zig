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

const Point = struct {
    isize, //x
    isize, //y
};

const low_points = [_]Point{
    .{ -4, -4 }, .{ 4, -4 },
    .{ -4, 4 },  .{ 4, 4 },
};

// zig fmt: off
const medium_points = [_]Point{
    .{ -8, -8 }, .{ 0, -8 }, .{ 8, -8 },
    .{ -8, 0 },              .{ 8, 0 },
    .{ -8, 8 },  .{ 0, 8 },  .{ 8, 8 },
};

const high_points = [_]Point{
    .{-12, -12}, .{-4, -12}, .{4, -12}, .{12, -12},
    .{-12, -4},                         .{12, -4},
    .{-12, 4},                          .{12, 4},
    .{-12, 12}, .{-4, 12},   .{4, 12},  .{12, 12},
};
// zig fmt: on

fn less_than_points(_: void, lhs: Point, rhs: Point) bool {
    // prioritize least Y (row) first.
    if (lhs[1] < rhs[1]) {
        return true;
    } else if (lhs[1] == rhs[1]) {
        // If Y's are the same, use the least X (column) first.
        return lhs[0] < rhs[0];
    }
    return false;
}

test less_than_points {
    var points = [_]Point{
        .{ 4, -2 },
        .{ 2, -2 },
        .{ 4, -4 },
        .{ 2, -4 },
    };
    std.sort.insertion(Point, &points, {}, less_than_points);

    const expected = [_]Point{ .{ 2, -4 }, .{ 4, -4 }, .{ 2, -2 }, .{ 4, -2 } };
    try std.testing.expectEqualDeep(expected, points);
}

// https://ziglang.org/documentation/master/#Choosing-an-Allocator
//
// Using the C allocator since we're passing pointers to allocated memory between Zig and C code,
// specifically the filter data between the Create and GetFrame functions.
const allocator = std.heap.c_allocator;

const MAX_TEMPORAL_RADIUS = 10;
const MAX_TEMPORAL_DIAMETER = MAX_TEMPORAL_RADIUS * 2 + 1;
// number of planes involved to hold all frames in the temporal radius.
const MAX_TEMPORAL_DIAMETER_PLANES = MAX_TEMPORAL_DIAMETER * 3;

const CCDData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,

    vi: *const vs.VideoInfo,

    threshold: f32,
    temporal_radius: u8,
    weights: [MAX_TEMPORAL_DIAMETER]f32,
    scale: f32,
    points: []Point,
};

fn CCD(comptime T: type) type {
    const diameter = 25;

    const vector_len = vec.getVecSize(T);
    const VT = @Vector(vector_len, T);
    const BSAT = types.BigSignedArithmeticType(T);
    const VBSAT = @Vector(vector_len, BSAT);
    const UAT = types.UnsignedArithmeticType(T);
    const VUAT = @Vector(vector_len, UAT);
    const BUAT = types.BigUnsignedArithmeticType(T);
    const VBUAT = @Vector(vector_len, BUAT);

    return struct {
        fn ccdScalar(comptime mirror: bool, threshold: BUAT, points: []const Point, comptime temporal_radius: u8, weights: [MAX_TEMPORAL_DIAMETER]f32, format_max: T, row: usize, column: usize, width: usize, height: usize, stride: usize, src: [MAX_TEMPORAL_DIAMETER_PLANES][]const T) struct { T, T, T } {
            @setFloatMode(float_mode);

            const F = if (types.isInt(T)) f32 else T;

            const temporal_diameter = temporal_radius * 2 + 1;

            const center_r = src[temporal_radius * 3 + 0][row * stride + column];
            const center_g = src[temporal_radius * 3 + 1][row * stride + column];
            const center_b = src[temporal_radius * 3 + 2][row * stride + column];

            var total_r: UAT = center_r;
            var total_g: UAT = center_g;
            var total_b: UAT = center_b;

            var count: u8 = 0;

            for (points) |point| {
                const y: isize = @as(isize, @intCast(row)) + point[1];
                const x: isize = @as(isize, @intCast(column)) + point[0];

                const absolute_y: usize = if (mirror) math.mirrorIndex(y, height) else @intCast(y);
                const absolute_x: usize = if (mirror) math.mirrorIndex(x, width) else @intCast(x);

                const current_neighbor_r = src[temporal_radius * 3 + 0][absolute_y * stride + absolute_x];
                const current_neighbor_g = src[temporal_radius * 3 + 1][absolute_y * stride + absolute_x];
                const current_neighbor_b = src[temporal_radius * 3 + 2][absolute_y * stride + absolute_x];

                var ssd: BUAT = 0;

                for (0..temporal_diameter) |i| {
                    const temporal_neighbor_r = src[i * 3 + 0][absolute_y * stride + absolute_x];
                    const temporal_neighbor_g = src[i * 3 + 1][absolute_y * stride + absolute_x];
                    const temporal_neighbor_b = src[i * 3 + 2][absolute_y * stride + absolute_x];

                    const diff_r: BSAT = lossyCast(BSAT, temporal_neighbor_r) - center_r;
                    const diff_g: BSAT = lossyCast(BSAT, temporal_neighbor_g) - center_g;
                    const diff_b: BSAT = lossyCast(BSAT, temporal_neighbor_b) - center_b;

                    // sum of squared differences
                    const frame_ssd: BUAT = lossyCast(BUAT, diff_r * diff_r) + lossyCast(BUAT, diff_g * diff_g) + lossyCast(BUAT, diff_b * diff_b);

                    if (temporal_radius == 0) {
                        // optimization: Bypass weight calculation for temporal_radius 0 (spatial only),
                        // since we know that the weight is always 1. This avoids a lookup, multiplication, and casting.
                        ssd += frame_ssd;
                    } else {
                        ssd += if (types.isFloat(T))
                            frame_ssd * lossyCast(F, weights[i])
                        else
                            @intFromFloat(@round(lossyCast(f32, frame_ssd) * weights[i]));
                    }
                }

                // optimization: using a branch to avoid expensive integer division when temporal_radius = 0
                if (temporal_radius > 0) {
                    // Average the SSD across the number of frames.
                    ssd = ssd / lossyCast(T, temporal_diameter);
                }

                if (ssd < threshold) {
                    total_r += current_neighbor_r;
                    total_g += current_neighbor_g;
                    total_b += current_neighbor_b;
                    count += 1;
                }
            }

            const calculated_r: F = lossyCast(F, total_r) / (lossyCast(F, count) + 1.0);
            const calculated_g: F = lossyCast(F, total_g) / (lossyCast(F, count) + 1.0);
            const calculated_b: F = lossyCast(F, total_b) / (lossyCast(F, count) + 1.0);

            return if (types.isFloat(T)) .{
                lossyCast(T, calculated_r),
                lossyCast(T, calculated_g),
                lossyCast(T, calculated_b),
            } else .{
                // Round and clamp integer formats so that we can handle things like 10-bit.
                std.math.clamp(lossyCast(T, @round(calculated_r)), 0, format_max),
                std.math.clamp(lossyCast(T, @round(calculated_g)), 0, format_max),
                std.math.clamp(lossyCast(T, @round(calculated_b)), 0, format_max),
            };
        }

        // Only handles non-mirrored content, since mirroring is much more difficult to implement for vectors.
        fn ccdVector(_threshold: BUAT, points: []const Point, comptime temporal_radius: u8, weights: [MAX_TEMPORAL_DIAMETER]f32, _format_max: T, row: usize, column: usize, stride: usize, src: [MAX_TEMPORAL_DIAMETER_PLANES][]const T) struct { VT, VT, VT } {
            @setFloatMode(float_mode);

            const F = if (types.isInt(T)) @Vector(vector_len, f32) else VT;

            const threshold: VBUAT = @splat(_threshold);
            const format_max: VT = @splat(_format_max);
            const temporal_diameter = temporal_radius * 2 + 1;

            const one: @Vector(vector_len, u8) = @splat(1);
            const zero: VT = @splat(0);
            const vtemporal_diameter: VT = @splat(lossyCast(T, temporal_diameter));

            const center_r = vec.load(VT, src[temporal_radius * 3 + 0], row * stride + column);
            const center_g = vec.load(VT, src[temporal_radius * 3 + 1], row * stride + column);
            const center_b = vec.load(VT, src[temporal_radius * 3 + 2], row * stride + column);

            var total_r: VUAT = center_r;
            var total_g: VUAT = center_g;
            var total_b: VUAT = center_b;

            var count: @Vector(vector_len, u8) = @splat(0);

            for (points) |point| {
                const y: usize = @intCast(@as(isize, @intCast(row)) + point[1]);
                const x: usize = @intCast(@as(isize, @intCast(column)) + point[0]);

                const current_neighbor_r = vec.load(VT, src[temporal_radius * 3 + 0], y * stride + x);
                const current_neighbor_g = vec.load(VT, src[temporal_radius * 3 + 1], y * stride + x);
                const current_neighbor_b = vec.load(VT, src[temporal_radius * 3 + 2], y * stride + x);

                var ssd: VBUAT = @splat(0);

                for (0..temporal_diameter) |i| {
                    const temporal_neighbor_r = vec.load(VT, src[i * 3 + 0], y * stride + x);
                    const temporal_neighbor_g = vec.load(VT, src[i * 3 + 1], y * stride + x);
                    const temporal_neighbor_b = vec.load(VT, src[i * 3 + 2], y * stride + x);

                    const diff_r: VBSAT = lossyCast(VBSAT, temporal_neighbor_r) - center_r;
                    const diff_g: VBSAT = lossyCast(VBSAT, temporal_neighbor_g) - center_g;
                    const diff_b: VBSAT = lossyCast(VBSAT, temporal_neighbor_b) - center_b;

                    // sum of squared differences
                    const frame_ssd: VBUAT = lossyCast(VBUAT, diff_r * diff_r) + lossyCast(VBUAT, diff_g * diff_g) + lossyCast(VBUAT, diff_b * diff_b);

                    if (temporal_radius == 0) {
                        // optimization: Bypass weight calculation for temporal_radius 0 (spatial only),
                        // since we know that the weight is always 1. This avoids a lookup, multiplication, and casting.
                        ssd += frame_ssd;
                    } else {
                        // Add the weighted SSD to the total SSD.
                        const weight: F = @splat(@floatCast(weights[i]));
                        ssd += if (types.isFloat(T))
                            frame_ssd * weight
                        else
                            @intFromFloat(@round(@as(F, @floatFromInt(frame_ssd)) * weight));
                    }
                }

                //optimization: using a branch to avoid expensive integer division when temporal_radius = 0
                if (temporal_radius > 0) {
                    // Average the SSD across the number of frames.
                    ssd = ssd / vtemporal_diameter;
                }

                const ssd_lt_threshold = ssd < threshold;
                total_r = @select(UAT, ssd_lt_threshold, total_r + current_neighbor_r, total_r);
                total_g = @select(UAT, ssd_lt_threshold, total_g + current_neighbor_g, total_g);
                total_b = @select(UAT, ssd_lt_threshold, total_b + current_neighbor_b, total_b);
                count = @select(u8, ssd_lt_threshold, count + one, count);
            }

            const one_point_zero: F = @splat(1.0);
            const calculated_r: F = lossyCast(F, total_r) / (lossyCast(F, count) + one_point_zero);
            const calculated_g: F = lossyCast(F, total_g) / (lossyCast(F, count) + one_point_zero);
            const calculated_b: F = lossyCast(F, total_b) / (lossyCast(F, count) + one_point_zero);

            return if (types.isFloat(T)) .{
                lossyCast(VT, calculated_r),
                lossyCast(VT, calculated_g),
                lossyCast(VT, calculated_b),
            } else .{
                // Round and clamp integer formats so that we can handle things like 10-bit.
                std.math.clamp(lossyCast(VT, @round(calculated_r)), zero, format_max),
                std.math.clamp(lossyCast(VT, @round(calculated_g)), zero, format_max),
                std.math.clamp(lossyCast(VT, @round(calculated_b)), zero, format_max),
            };
        }

        // Outdated, and missing several key features like scaling, points, and temporal support.
        // But leaving for future reference.
        // fn processPlanesScalar(threshold: BUAT, format_max: T, src: [MAX_TEMPORAL_DIAMETER_PLANES][]const T, dst: [3][]T, width: usize, height: usize, stride: usize) void {
        //     // Process top rows with mirrored grid.
        //     for (0..radius) |row| {
        //         for (0..width) |column| {
        //             const result = ccdScalar(true, threshold, format_max, row, column, width, height, stride, src);
        //
        //             dst[0][(row * stride) + column] = result[0];
        //             dst[1][(row * stride) + column] = result[1];
        //             dst[2][(row * stride) + column] = result[2];
        //         }
        //     }
        //
        //     for (radius..height - radius) |row| {
        //         // Process first pixels of the row with mirrored grid.
        //         for (0..radius) |column| {
        //             const result = ccdScalar(true, threshold, format_max, row, column, width, height, stride, src);
        //
        //             dst[0][(row * stride) + column] = result[0];
        //             dst[1][(row * stride) + column] = result[1];
        //             dst[2][(row * stride) + column] = result[2];
        //         }
        //
        //         for (radius..width - radius) |column| {
        //             // Use a non-mirrored grid everywhere else for maximum performance.
        //             // We don't need the mirror effect anyways, as all pixels contain valid data.
        //             const result = ccdScalar(false, threshold, format_max, row, column, width, height, stride, src);
        //
        //             dst[0][(row * stride) + column] = result[0];
        //             dst[1][(row * stride) + column] = result[1];
        //             dst[2][(row * stride) + column] = result[2];
        //         }
        //
        //         // Process last pixel of the row with mirrored grid.
        //         for (width - radius..width) |column| {
        //             const result = ccdScalar(true, threshold, format_max, row, column, width, height, stride, src);
        //
        //             dst[0][(row * stride) + column] = result[0];
        //             dst[1][(row * stride) + column] = result[1];
        //             dst[2][(row * stride) + column] = result[2];
        //         }
        //     }
        //
        //     // Process bottom rows with mirrored grid.
        //     for (height - radius..height) |row| {
        //         for (0..width) |column| {
        //             const result = ccdScalar(true, threshold, format_max, row, column, width, height, stride, src);
        //
        //             dst[0][(row * stride) + column] = result[0];
        //             dst[1][(row * stride) + column] = result[1];
        //             dst[2][(row * stride) + column] = result[2];
        //         }
        //     }
        // }

        fn processPlanesVector(threshold: BUAT, scale: f32, points: []const Point, comptime temporal_radius: u8, weights: [MAX_TEMPORAL_DIAMETER]f32, format_max: T, src: [MAX_TEMPORAL_DIAMETER_PLANES][]const T, dst: [3][]T, width: usize, height: usize, stride: usize) void {
            const scaled_diameter: usize = @intFromFloat(@round(diameter * scale));
            const scaled_radius: usize = scaled_diameter / 2;
            const width_simd = (width - scaled_radius) / vector_len * vector_len;

            // Top rows - mirrored
            for (0..scaled_radius) |row| {
                for (0..width) |column| {
                    const result = ccdScalar(true, threshold, points, temporal_radius, weights, format_max, row, column, width, height, stride, src);

                    dst[0][(row * stride) + column] = result[0];
                    dst[1][(row * stride) + column] = result[1];
                    dst[2][(row * stride) + column] = result[2];
                }
            }

            // Middle rows
            for (scaled_radius..height - scaled_radius) |row| {
                // First columns - mirrored
                for (0..scaled_radius) |column| {
                    const result = ccdScalar(true, threshold, points, temporal_radius, weights, format_max, row, column, width, height, stride, src);

                    dst[0][(row * stride) + column] = result[0];
                    dst[1][(row * stride) + column] = result[1];
                    dst[2][(row * stride) + column] = result[2];
                }

                // Middle columns - not mirrored
                var column: usize = scaled_radius;
                while (column < width_simd + scaled_radius) : (column += vector_len) {
                    const result = ccdVector(threshold, points, temporal_radius, weights, format_max, row, column, stride, src);

                    vec.store(VT, dst[0], row * stride + column, result[0]);
                    vec.store(VT, dst[1], row * stride + column, result[1]);
                    vec.store(VT, dst[2], row * stride + column, result[2]);
                }

                // Last columns - non-mirrored
                // We do this to minimize the use of scalar mirror code.
                if (width_simd + scaled_radius < width) {
                    const adjusted_column = width - vector_len - scaled_radius;
                    const result = ccdVector(threshold, points, temporal_radius, weights, format_max, row, adjusted_column, stride, src);

                    vec.store(VT, dst[0], row * stride + adjusted_column, result[0]);
                    vec.store(VT, dst[1], row * stride + adjusted_column, result[1]);
                    vec.store(VT, dst[2], row * stride + adjusted_column, result[2]);
                }

                // Last columns - mirrored
                for (width - scaled_radius..width) |c| {
                    const result = ccdScalar(true, threshold, points, temporal_radius, weights, format_max, row, c, width, height, stride, src);

                    dst[0][(row * stride) + c] = result[0];
                    dst[1][(row * stride) + c] = result[1];
                    dst[2][(row * stride) + c] = result[2];
                }
            }

            // Bottom rows - mirrored
            for (height - scaled_radius..height) |row| {
                for (0..width) |column| {
                    const result = ccdScalar(true, threshold, points, temporal_radius, weights, format_max, row, column, width, height, stride, src);

                    dst[0][(row * stride) + column] = result[0];
                    dst[1][(row * stride) + column] = result[1];
                    dst[2][(row * stride) + column] = result[2];
                }
            }
        }

        fn processPlanes(_threshold: f32, scale: f32, points: []Point, temporal_radius: u8, weights: [MAX_TEMPORAL_DIAMETER]f32, chroma: bool, bits_per_sample: u6, srcp8: [MAX_TEMPORAL_DIAMETER_PLANES][]const u8, dstp8: [3][]u8, width: usize, height: usize, stride8: usize) void {
            const threshold: BUAT = lossyCast(BUAT, _threshold);
            const stride = stride8 / @sizeOf(T);
            const srcp: [MAX_TEMPORAL_DIAMETER_PLANES][]const T = blk: {
                const temporal_diameter = temporal_radius * 2 + 1;
                var s: [MAX_TEMPORAL_DIAMETER_PLANES][]const T = undefined;
                for (0..temporal_diameter) |i| {
                    s[i * 3 + 0] = @ptrCast(@alignCast(srcp8[i * 3 + 0]));
                    s[i * 3 + 1] = @ptrCast(@alignCast(srcp8[i * 3 + 1]));
                    s[i * 3 + 2] = @ptrCast(@alignCast(srcp8[i * 3 + 2]));
                }
                break :blk s;
            };
            const dstp: [3][]T = .{
                @ptrCast(@alignCast(dstp8[0])),
                @ptrCast(@alignCast(dstp8[1])),
                @ptrCast(@alignCast(dstp8[2])),
            };

            const format_max = vscmn.getFormatMaximum2(T, bits_per_sample, chroma);

            switch (temporal_radius) {
                inline 0...MAX_TEMPORAL_RADIUS => |r| processPlanesVector(threshold, scale, points, r, weights, format_max, srcp, dstp, width, height, stride),
                else => unreachable,
            }
        }
    };
}

fn ccdGetFrame(_n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const zapi = ZAPI.init(vsapi, core);
    const d: *CCDData = @ptrCast(@alignCast(instance_data));

    const n: usize = lossyCast(usize, _n);
    const first: usize = n -| d.temporal_radius;
    const last: usize = @min(n + d.temporal_radius, lossyCast(usize, d.vi.numFrames - 1));

    if (activation_reason == ar.Initial) {
        for (first..last + 1) |f| {
            zapi.requestFrameFilter(@intCast(f), d.node, frame_ctx);
        }
    } else if (activation_reason == ar.AllFramesReady) {
        // Skip first and last frames that lie inside the temporal radius,
        // since we don't have enough information to process them.
        // This might be a lazy approach...
        if (n < d.temporal_radius or n > d.vi.numFrames - 1 - d.temporal_radius) {
            return zapi.getFrameFilter(_n, d.node, frame_ctx);
        }

        const temporal_diameter = d.temporal_radius * 2 + 1;

        var src_frames: [MAX_TEMPORAL_DIAMETER]ZAPI.ZFrame(*const vs.Frame) = undefined;
        for (0..temporal_diameter) |i| {
            src_frames[i] = zapi.initZFrame(d.node, @intCast(n - d.temporal_radius + i), frame_ctx);
        }
        defer for (0..temporal_diameter) |i| src_frames[i].deinit();

        const dst = src_frames[d.temporal_radius].newVideoFrame();

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
        const srcp8: [MAX_TEMPORAL_DIAMETER_PLANES][]const u8 = blk: {
            var s: [MAX_TEMPORAL_DIAMETER_PLANES][]const u8 = undefined;
            for (0..temporal_diameter) |i| {
                s[i * 3 + 0] = src_frames[i].getReadSlice(0);
                s[i * 3 + 1] = src_frames[i].getReadSlice(1);
                s[i * 3 + 2] = src_frames[i].getReadSlice(2);
            }
            break :blk s;
        };
        const dstp8: [3][]u8 = .{
            dst.getWriteSlice(0),
            dst.getWriteSlice(1),
            dst.getWriteSlice(2),
        };
        const chroma = vscmn.isChromaPlane(d.vi.format.colorFamily, 0);
        const bits_per_sample: u6 = @intCast(d.vi.format.bitsPerSample);

        processPlanes(d.threshold, d.scale, d.points, d.temporal_radius, d.weights, chroma, bits_per_sample, srcp8, dstp8, width, height, stride8);

        return dst.frame;
    }

    return null;
}

export fn ccdFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *CCDData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.free(d.points);
    allocator.destroy(d);
}

export fn ccdCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    const zapi = ZAPI.init(vsapi, core);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);

    var d: CCDData = undefined;

    d.node, d.vi = inz.getNodeVi("clip").?;

    if (d.vi.format.colorFamily != vs.ColorFamily.RGB) {
        outz.setError("CCD: only RGB color formats are supported");
        zapi.freeNode(d.node);
        return;
    }

    const format_max = vscmn.getFormatMaximum(f32, d.vi.format, false);

    d.threshold = inz.getFloat(f32, "threshold") orelse 4;
    d.threshold = d.threshold * format_max; // Scale to input bit depth for consitency across inputs.
    d.threshold = (d.threshold * d.threshold) / (255 * 255 * 3); // squared euclidian, scaled to sum of sqaured differences for float.

    d.temporal_radius = inz.getInt(u8, "temporal_radius") orelse 0;

    if (d.temporal_radius > MAX_TEMPORAL_RADIUS) {
        outz.setError("CCD: temporal radius must be less than 10");
        zapi.freeNode(d.node);
        return;
    }

    // Weight temporal neighbors.
    // https://github.com/Jaded-Encoding-Thaumaturgy/vs-jetpack/blob/b524ceb8760b03fd13bad2bf08ca42369459f788/vsdenoise/ccd.py#L241
    for (0..d.temporal_radius) |r| {
        const tr: f32 = @floatFromInt(d.temporal_radius);
        const fr: f32 = @floatFromInt(r);
        d.weights[d.temporal_radius - 1 - r] = @sqrt((tr + 1 - fr) / ((tr + 1) * 2));
        d.weights[d.temporal_radius + 1 + r] = @sin((tr + 2 - fr) / ((tr + 1) * 2));
    }
    // Ensure current/center frame is maximally weighted at 1.0;
    d.weights[d.temporal_radius] = 1.0;
    // std.debug.print("weights: {any}\n", .{d.weights});

    d.scale = inz.getFloat(f32, "scale") orelse @as(f32, @floatFromInt(d.vi.height)) / 240.0;

    if (d.scale < 1.0) {
        outz.setError("CCD: scale must be greater than or equal to 1.0");
        zapi.freeNode(d.node);
        return;
    }

    if ((inz.numElements("points") orelse 3) != 3) {
        outz.setError("CCD: The points array must have 3 boolean elements.");
        zapi.freeNode(d.node);
        return;
    }

    const low, const medium, const high = .{
        inz.getBool2("points", 0) orelse true, // low
        inz.getBool2("points", 1) orelse true, // medium
        inz.getBool2("points", 2) orelse false, // high
    };

    const points_len = (if (low) low_points.len else 0) + (if (medium) medium_points.len else 0) + (if (high) high_points.len else 0);

    if (points_len == 0) {
        outz.setError("CCD: A minimum of one set of points must be used.");
        zapi.freeNode(d.node);
        return;
    }

    d.points = allocator.alloc(Point, points_len) catch unreachable;

    {
        // append points
        var i: usize = 0;
        if (low) {
            @memcpy(d.points[i .. i + low_points.len], &low_points);
            i += low_points.len;
        }
        if (medium) {
            @memcpy(d.points[i .. i + medium_points.len], &medium_points);
            i += medium_points.len;
        }
        if (high) {
            @memcpy(d.points[i .. i + high_points.len], &high_points);
            i += high_points.len;
        }
    }

    // Sort points to ensure optimal (cache aware) lookups.
    std.sort.insertion(Point, d.points, {}, less_than_points);

    // scale points
    for (d.points) |*point| {
        point[0] = @intFromFloat(@round(@as(f32, @floatFromInt(point[0])) * d.scale));
        point[1] = @intFromFloat(@round(@as(f32, @floatFromInt(point[1])) * d.scale));
    }

    const data: *CCDData = allocator.create(CCDData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.General,
        },
    };

    zapi.createVideoFilter(out, "CCD", d.vi, ccdGetFrame, ccdFree, fm.Parallel, &deps, data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("CCD", "clip:vnode;threshold:float:opt;temporal_radius:int:opt;points:int[]:opt;scale:float:opt;", "clip:vnode;", ccdCreate, null, plugin);
}
