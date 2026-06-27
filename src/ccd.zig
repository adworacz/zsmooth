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
const vsh = vapoursynth.vshelper;

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
    node_ref: ?*vs.Node,

    vi: *const vs.VideoInfo,

    threshold: f32,
    temporal_radius: u8,
    weights: [MAX_TEMPORAL_DIAMETER]f32,
    scale: f32,
    points: []Point,
    diameter: u8,
};

fn CCD(comptime T: type) type {
    const vector_len = vec.getVecSize(T);
    const VT = @Vector(vector_len, T);
    const BSAT = types.BigSignedArithmeticType(T);
    const VBSAT = @Vector(vector_len, BSAT);
    const UAT = types.UnsignedArithmeticType(T);
    const VUAT = @Vector(vector_len, UAT);
    const BUAT = types.BigUnsignedArithmeticType(T);
    const VBUAT = @Vector(vector_len, BUAT);

    return struct {
        const CCDOptions = struct {
            width: usize,
            height: usize,
            stride: usize,
            threshold: BUAT,
            format_max: T,
            points: []const Point,
            weights: []const f32,
        };

        fn ccdScalar(comptime mirror: bool, comptime temporal_radius: u8, row: usize, column: usize, noalias src: []const []const T, noalias ref: []const []const T, opt: CCDOptions) struct { T, T, T } {
            @setFloatMode(float_mode);

            const F = if (types.isInt(T)) f32 else T;

            const temporal_diameter = temporal_radius * 2 + 1;

            var total_r: UAT = src[temporal_radius * 3 + 0][row * opt.stride + column];
            var total_g: UAT = src[temporal_radius * 3 + 1][row * opt.stride + column];
            var total_b: UAT = src[temporal_radius * 3 + 2][row * opt.stride + column];

            const center_ref_r = ref[temporal_radius * 3 + 0][row * opt.stride + column];
            const center_ref_g = ref[temporal_radius * 3 + 1][row * opt.stride + column];
            const center_ref_b = ref[temporal_radius * 3 + 2][row * opt.stride + column];

            var count: u8 = 0;

            for (opt.points) |point| {
                const y: isize = @as(isize, @intCast(row)) + point[1];
                const x: isize = @as(isize, @intCast(column)) + point[0];

                const absolute_y: usize = if (mirror) math.mirrorIndex(y, opt.height) else @intCast(y);
                const absolute_x: usize = if (mirror) math.mirrorIndex(x, opt.width) else @intCast(x);

                // Current frame
                const point_r = src[temporal_radius * 3 + 0][absolute_y * opt.stride + absolute_x];
                const point_g = src[temporal_radius * 3 + 1][absolute_y * opt.stride + absolute_x];
                const point_b = src[temporal_radius * 3 + 2][absolute_y * opt.stride + absolute_x];

                const point_ref_r = ref[temporal_radius * 3 + 0][absolute_y * opt.stride + absolute_x];
                const point_ref_g = ref[temporal_radius * 3 + 1][absolute_y * opt.stride + absolute_x];
                const point_ref_b = ref[temporal_radius * 3 + 2][absolute_y * opt.stride + absolute_x];

                const diff_r: BSAT = lossyCast(BSAT, point_ref_r) - center_ref_r;
                const diff_g: BSAT = lossyCast(BSAT, point_ref_g) - center_ref_g;
                const diff_b: BSAT = lossyCast(BSAT, point_ref_b) - center_ref_b;

                // sum of squared differences
                var ssd: BUAT = lossyCast(BUAT, diff_r * diff_r) + lossyCast(BUAT, diff_g * diff_g) + lossyCast(BUAT, diff_b * diff_b);

                // Temporal neighbors
                for (0..temporal_radius) |i| {
                    const prev_idx = temporal_radius - 1 - i;
                    const next_idx = temporal_radius + 1 + i;

                    const point_prev_ref_r = ref[prev_idx * 3 + 0][absolute_y * opt.stride + absolute_x];
                    const point_prev_ref_g = ref[prev_idx * 3 + 1][absolute_y * opt.stride + absolute_x];
                    const point_prev_ref_b = ref[prev_idx * 3 + 2][absolute_y * opt.stride + absolute_x];

                    const point_next_ref_r = ref[next_idx * 3 + 0][absolute_y * opt.stride + absolute_x];
                    const point_next_ref_g = ref[next_idx * 3 + 1][absolute_y * opt.stride + absolute_x];
                    const point_next_ref_b = ref[next_idx * 3 + 2][absolute_y * opt.stride + absolute_x];

                    const diff_prev_r: BSAT = lossyCast(BSAT, point_prev_ref_r) - center_ref_r;
                    const diff_prev_g: BSAT = lossyCast(BSAT, point_prev_ref_g) - center_ref_g;
                    const diff_prev_b: BSAT = lossyCast(BSAT, point_prev_ref_b) - center_ref_b;

                    const diff_next_r: BSAT = lossyCast(BSAT, point_next_ref_r) - center_ref_r;
                    const diff_next_g: BSAT = lossyCast(BSAT, point_next_ref_g) - center_ref_g;
                    const diff_next_b: BSAT = lossyCast(BSAT, point_next_ref_b) - center_ref_b;

                    const frame_ssd_prev: BUAT = lossyCast(BUAT, diff_prev_r * diff_prev_r) + lossyCast(BUAT, diff_prev_g * diff_prev_g) + lossyCast(BUAT, diff_prev_b * diff_prev_b);
                    const frame_ssd_next: BUAT = lossyCast(BUAT, diff_next_r * diff_next_r) + lossyCast(BUAT, diff_next_g * diff_next_g) + lossyCast(BUAT, diff_next_b * diff_next_b);

                    // Prev/next frames have different weights (sqrt vs sin)
                    const weight_prev = lossyCast(F, opt.weights[prev_idx]);
                    const weight_next = lossyCast(F, opt.weights[next_idx]);

                    ssd += if (types.isFloat(T))
                        (frame_ssd_prev * weight_prev) + (frame_ssd_next * weight_next)
                    else
                        @intFromFloat(@round(lossyCast(f32, frame_ssd_prev) * weight_prev + lossyCast(f32, frame_ssd_next) * weight_next));
                }

                // optimization: using a branch to avoid expensive integer division when temporal_radius = 0
                // TODO: This branching might not be needed any more, since temporal diameter is comptime known now,
                // so the compiler should remove it... test without the branch, speeds should be identical.
                if (temporal_radius > 0) {
                    // Average the SSD across the number of frames.
                    ssd = if (types.isFloat(T))
                        ssd / temporal_diameter
                    else
                        // + (temporal_diameter / 2) to round integers properly.
                        (ssd + (temporal_diameter / 2)) / temporal_diameter;
                }

                if (ssd < opt.threshold) {
                    total_r += point_r;
                    total_g += point_g;
                    total_b += point_b;
                    count += 1;
                }
            }

            const calculated_r: F = lossyCast(F, total_r) / lossyCast(F, count + 1);
            const calculated_g: F = lossyCast(F, total_g) / lossyCast(F, count + 1);
            const calculated_b: F = lossyCast(F, total_b) / lossyCast(F, count + 1);

            return switch (T) {
                u8 => .{
                    @intFromFloat(@round(calculated_r)),
                    @intFromFloat(@round(calculated_g)),
                    @intFromFloat(@round(calculated_b)),
                },
                u16 => .{
                    // Round and clamp integer formats so that we can handle things like 10-bit.
                    std.math.clamp(lossyCast(T, @round(calculated_r)), 0, opt.format_max),
                    std.math.clamp(lossyCast(T, @round(calculated_g)), 0, opt.format_max),
                    std.math.clamp(lossyCast(T, @round(calculated_b)), 0, opt.format_max),
                },
                else => .{
                    calculated_r,
                    calculated_g,
                    calculated_b,
                },
            };
        }

        // Only handles non-mirrored content, since mirroring is much more difficult to implement for vectors.
        fn ccdVector(comptime temporal_radius: u8, row: usize, column: usize, noalias src: []const []const T, noalias ref: []const []const T, opt: CCDOptions) struct { VT, VT, VT } {
            @setFloatMode(float_mode);

            const F = if (types.isInt(T)) @Vector(vector_len, f32) else VT;

            const threshold: VBUAT = @splat(opt.threshold);
            const format_max: VT = @splat(opt.format_max);
            const temporal_diameter = temporal_radius * 2 + 1;

            const one: @Vector(vector_len, u8) = @splat(1);
            const zero: VT = @splat(0);
            const vtemporal_diameter: VT = @splat(temporal_diameter);
            const vhalf_temporal_diameter: VT = @splat(temporal_diameter / 2);

            var total_r: VUAT = vec.load(VT, src[temporal_radius * 3 + 0], row * opt.stride + column);
            var total_g: VUAT = vec.load(VT, src[temporal_radius * 3 + 1], row * opt.stride + column);
            var total_b: VUAT = vec.load(VT, src[temporal_radius * 3 + 2], row * opt.stride + column);

            const center_ref_r = vec.load(VT, ref[temporal_radius * 3 + 0], row * opt.stride + column);
            const center_ref_g = vec.load(VT, ref[temporal_radius * 3 + 1], row * opt.stride + column);
            const center_ref_b = vec.load(VT, ref[temporal_radius * 3 + 2], row * opt.stride + column);

            var count: @Vector(vector_len, u8) = @splat(0);

            for (opt.points) |point| {
                const y: usize = @intCast(@as(isize, @intCast(row)) + point[1]);
                const x: usize = @intCast(@as(isize, @intCast(column)) + point[0]);

                const point_r = vec.load(VT, src[temporal_radius * 3 + 0], y * opt.stride + x);
                const point_g = vec.load(VT, src[temporal_radius * 3 + 1], y * opt.stride + x);
                const point_b = vec.load(VT, src[temporal_radius * 3 + 2], y * opt.stride + x);

                // Current frame
                const point_ref_r = vec.load(VT, ref[temporal_radius * 3 + 0], y * opt.stride + x);
                const point_ref_g = vec.load(VT, ref[temporal_radius * 3 + 1], y * opt.stride + x);
                const point_ref_b = vec.load(VT, ref[temporal_radius * 3 + 2], y * opt.stride + x);

                const diff_r: VBSAT = lossyCast(VBSAT, point_ref_r) - center_ref_r;
                const diff_g: VBSAT = lossyCast(VBSAT, point_ref_g) - center_ref_g;
                const diff_b: VBSAT = lossyCast(VBSAT, point_ref_b) - center_ref_b;

                // sum of squared differences
                var ssd: VBUAT = lossyCast(VBUAT, diff_r * diff_r) + lossyCast(VBUAT, diff_g * diff_g) + lossyCast(VBUAT, diff_b * diff_b);

                // Temporal neighbors
                // By calculating both prev and next frames in one iteration,
                // we see ~20% performance increase. Likely due to better
                // memory access parallelization, among other things.
                for (0..temporal_radius) |i| {
                    // Center frame is in the middle, so other frames start +/- 1 on either side.
                    const prev_idx = temporal_radius - 1 - i;
                    const next_idx = temporal_radius + 1 + i;

                    const point_ref_prev_r = vec.load(VT, ref[prev_idx * 3 + 0], y * opt.stride + x);
                    const point_ref_prev_g = vec.load(VT, ref[prev_idx * 3 + 1], y * opt.stride + x);
                    const point_ref_prev_b = vec.load(VT, ref[prev_idx * 3 + 2], y * opt.stride + x);

                    const point_ref_next_r = vec.load(VT, ref[next_idx * 3 + 0], y * opt.stride + x);
                    const point_ref_next_g = vec.load(VT, ref[next_idx * 3 + 1], y * opt.stride + x);
                    const point_ref_next_b = vec.load(VT, ref[next_idx * 3 + 2], y * opt.stride + x);

                    const diff_prev_r = lossyCast(VBSAT, point_ref_prev_r) - center_ref_r;
                    const diff_prev_g = lossyCast(VBSAT, point_ref_prev_g) - center_ref_g;
                    const diff_prev_b = lossyCast(VBSAT, point_ref_prev_b) - center_ref_b;

                    const diff_next_r = lossyCast(VBSAT, point_ref_next_r) - center_ref_r;
                    const diff_next_g = lossyCast(VBSAT, point_ref_next_g) - center_ref_g;
                    const diff_next_b = lossyCast(VBSAT, point_ref_next_b) - center_ref_b;

                    const frame_ssd_prev: VBUAT = lossyCast(VBUAT, diff_prev_r * diff_prev_r) + lossyCast(VBUAT, diff_prev_g * diff_prev_g) + lossyCast(VBUAT, diff_prev_b * diff_prev_b);
                    const frame_ssd_next: VBUAT = lossyCast(VBUAT, diff_next_r * diff_next_r) + lossyCast(VBUAT, diff_next_g * diff_next_g) + lossyCast(VBUAT, diff_next_b * diff_next_b);

                    // Add the weighted SSD to the total SSD.
                    const weight_prev: F = @splat(@floatCast(opt.weights[prev_idx]));
                    const weight_next: F = @splat(@floatCast(opt.weights[next_idx]));
                    ssd += if (types.isFloat(T))
                        (frame_ssd_prev * weight_prev) + (frame_ssd_next * weight_next)
                    else
                        @intFromFloat(@round(@as(F, @floatFromInt(frame_ssd_prev)) * weight_prev + @as(F, @floatFromInt(frame_ssd_next)) * weight_next));
                }

                //optimization: using a branch to avoid expensive integer division when temporal_radius = 0
                if (temporal_radius > 0) {
                    // Average the SSD across the number of frames.
                    ssd = if (types.isFloat(T))
                        ssd / vtemporal_diameter
                    else
                        // + (temporal_diameter / 2) for proper integer rounding
                        (ssd + vhalf_temporal_diameter) / vtemporal_diameter;
                }

                const ssd_lt_threshold = ssd < threshold;
                total_r = @select(UAT, ssd_lt_threshold, total_r + point_r, total_r);
                total_g = @select(UAT, ssd_lt_threshold, total_g + point_g, total_g);
                total_b = @select(UAT, ssd_lt_threshold, total_b + point_b, total_b);
                count = @select(u8, ssd_lt_threshold, count + one, count);
            }

            const calculated_r: F = lossyCast(F, total_r) / lossyCast(F, count + one);
            const calculated_g: F = lossyCast(F, total_g) / lossyCast(F, count + one);
            const calculated_b: F = lossyCast(F, total_b) / lossyCast(F, count + one);

            return switch (T) {
                u8 => .{
                    @intFromFloat(@round(calculated_r)),
                    @intFromFloat(@round(calculated_g)),
                    @intFromFloat(@round(calculated_b)),
                },
                u16 => .{
                    // Round and clamp integer formats so that we can handle things like 10-bit.
                    std.math.clamp(lossyCast(VT, @round(calculated_r)), zero, format_max),
                    std.math.clamp(lossyCast(VT, @round(calculated_g)), zero, format_max),
                    std.math.clamp(lossyCast(VT, @round(calculated_b)), zero, format_max),
                },
                else => .{
                    calculated_r,
                    calculated_g,
                    calculated_b,
                },
            };
        }

        // Use separate dst slices for each plane so we can use 'noalias'
        fn processPlanesVector(comptime temporal_radius: u8, noalias src: []const []const T, noalias ref: []const []const T, noalias dst_r: []T, noalias dst_g: []T, noalias dst_b: []T, opt: struct {
            width: usize,
            height: usize,
            stride: usize,
            threshold: BUAT,
            scale: f32,
            points: []const Point,
            diameter: u8,
            weights: []const f32,
            format_max: T,
        }) void {
            const scaled_diameter: usize = @intFromFloat(@round(@as(f32, @floatFromInt(opt.diameter)) * opt.scale));
            const scaled_radius: usize = scaled_diameter / 2;
            const width_simd = (opt.width - scaled_radius) / vector_len * vector_len;
            const options: CCDOptions = .{
                .width = opt.width,
                .height = opt.height,

                .format_max = opt.format_max,
                .points = opt.points,
                .stride = opt.stride,
                .threshold = opt.threshold,
                .weights = opt.weights,
            };

            // Top rows - mirrored
            for (0..scaled_radius) |row| {
                for (0..opt.width) |column| {
                    const result = ccdScalar(true, temporal_radius, row, column, src, ref, options);

                    dst_r[(row * opt.stride) + column] = result[0];
                    dst_g[(row * opt.stride) + column] = result[1];
                    dst_b[(row * opt.stride) + column] = result[2];
                }
            }

            // Middle rows
            for (scaled_radius..opt.height - scaled_radius) |row| {
                // First columns - mirrored
                for (0..scaled_radius) |column| {
                    const result = ccdScalar(true, temporal_radius, row, column, src, ref, options);

                    dst_r[(row * opt.stride) + column] = result[0];
                    dst_g[(row * opt.stride) + column] = result[1];
                    dst_b[(row * opt.stride) + column] = result[2];
                }

                // Middle columns - not mirrored
                var column: usize = scaled_radius;
                while (column < width_simd) : (column += vector_len) {
                    const result = ccdVector(temporal_radius, row, column, src, ref, options);

                    vec.store(VT, dst_r, row * opt.stride + column, result[0]);
                    vec.store(VT, dst_g, row * opt.stride + column, result[1]);
                    vec.store(VT, dst_b, row * opt.stride + column, result[2]);
                }

                // Last columns - non-mirrored
                // We do this to minimize the use of scalar mirror code.
                if (width_simd + scaled_radius < opt.width) {
                    const adjusted_column = opt.width - vector_len - scaled_radius;
                    const result = ccdVector(temporal_radius, row, adjusted_column, src, ref, options);

                    vec.store(VT, dst_r, row * opt.stride + adjusted_column, result[0]);
                    vec.store(VT, dst_g, row * opt.stride + adjusted_column, result[1]);
                    vec.store(VT, dst_b, row * opt.stride + adjusted_column, result[2]);
                }

                // Last columns - mirrored
                for (opt.width - scaled_radius..opt.width) |c| {
                    const result = ccdScalar(true, temporal_radius, row, c, src, ref, options);

                    dst_r[(row * opt.stride) + c] = result[0];
                    dst_g[(row * opt.stride) + c] = result[1];
                    dst_b[(row * opt.stride) + c] = result[2];
                }
            }

            // Bottom rows - mirrored
            for (opt.height - scaled_radius..opt.height) |row| {
                for (0..opt.width) |column| {
                    const result = ccdScalar(true, temporal_radius, row, column, src, ref, options);

                    dst_r[(row * opt.stride) + column] = result[0];
                    dst_g[(row * opt.stride) + column] = result[1];
                    dst_b[(row * opt.stride) + column] = result[2];
                }
            }
        }

        fn processPlanes(noalias src8: []const []const u8, noalias ref8: []const []const u8, noalias dstp_r8: []u8, noalias dstp_g8: []u8, noalias dstp_b8: []u8, opt: struct {
            width: usize,
            height: usize,
            stride8: usize,
            threshold: f32,
            scale: f32,
            points: []Point,
            diameter: u8,
            temporal_radius: u8,
            weights: []const f32,
            chroma: bool,
            bits_per_sample: u6,
        }) void {
            const threshold: BUAT = lossyCast(BUAT, opt.threshold);
            const stride = opt.stride8 / @sizeOf(T);
            const src: []const []const T = @ptrCast(@alignCast(src8));
            const ref: []const []const T = @ptrCast(@alignCast(ref8));

            const dstp_r: []T = @ptrCast(@alignCast(dstp_r8));
            const dstp_g: []T = @ptrCast(@alignCast(dstp_g8));
            const dstp_b: []T = @ptrCast(@alignCast(dstp_b8));

            const format_max = vscmn.getFormatMaximum2(T, opt.bits_per_sample, opt.chroma);

            switch (opt.temporal_radius) {
                inline 0...MAX_TEMPORAL_RADIUS => |r| processPlanesVector(r, src, ref, dstp_r, dstp_g, dstp_b, .{
                    .threshold = threshold,
                    .scale = opt.scale,
                    .points = opt.points,
                    .diameter = opt.diameter,
                    .weights = opt.weights,
                    .format_max = format_max,
                    .width = opt.width,
                    .height = opt.height,
                    .stride = stride,
                }),
                else => unreachable,
            }
        }
    };
}

fn ccdGetFrame(_n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const zapi = ZAPI.init(vsapi, core, frame_ctx);
    const d: *CCDData = @ptrCast(@alignCast(instance_data));

    const n: usize = lossyCast(usize, _n);
    const first: usize = n -| d.temporal_radius;
    const last: usize = @min(n + d.temporal_radius, lossyCast(usize, d.vi.numFrames - 1));

    if (activation_reason == ar.Initial) {
        for (first..last + 1) |f| {
            zapi.requestFrameFilter(@intCast(f), d.node);
            if (d.node_ref) |_| {
                zapi.requestFrameFilter(@intCast(f), d.node_ref);
            }
        }
    } else if (activation_reason == ar.AllFramesReady) {
        // Skip first and last frames that lie inside the temporal radius,
        // since we don't have enough information to process them.
        // This might be a lazy approach...
        if (n < d.temporal_radius or n > d.vi.numFrames - 1 - d.temporal_radius) {
            return zapi.getFrameFilter(_n, d.node);
        }

        const temporal_diameter = d.temporal_radius * 2 + 1;

        var src_frames: [MAX_TEMPORAL_DIAMETER]ZAPI.ZFrame(*const vs.Frame) = undefined;
        var ref_frames: [MAX_TEMPORAL_DIAMETER]ZAPI.ZFrame(*const vs.Frame) = undefined;
        for (0..temporal_diameter) |i| {
            src_frames[i] = zapi.initZFrame(d.node, @intCast(n - d.temporal_radius + i));
            if (d.node_ref) |_| {
                ref_frames[i] = zapi.initZFrame(d.node_ref, @intCast(n - d.temporal_radius + i));
            }
        }
        defer for (0..temporal_diameter) |i| {
            src_frames[i].deinit();
            if (d.node_ref) |_| {
                ref_frames[i].deinit();
            }
        };

        const dst = src_frames[d.temporal_radius].newVideoFrame();

        const processPlanes = switch (vscmn.FormatType.getDataType(d.vi.format)) {
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
        const ref8: [MAX_TEMPORAL_DIAMETER_PLANES][]const u8 = blk: {
            var r: [MAX_TEMPORAL_DIAMETER_PLANES][]const u8 = undefined;
            for (0..temporal_diameter) |i| {
                r[i * 3 + 0] = if (d.node_ref) |_| ref_frames[i].getReadSlice(0) else src_frames[i].getReadSlice(0);
                r[i * 3 + 1] = if (d.node_ref) |_| ref_frames[i].getReadSlice(1) else src_frames[i].getReadSlice(1);
                r[i * 3 + 2] = if (d.node_ref) |_| ref_frames[i].getReadSlice(2) else src_frames[i].getReadSlice(2);
            }
            break :blk r;
        };
        const chroma = vscmn.isChromaPlane(d.vi.format.colorFamily, 0);
        const bits_per_sample: u6 = @intCast(d.vi.format.bitsPerSample);

        processPlanes(srcp8[0 .. temporal_diameter * 3], ref8[0 .. temporal_diameter * 3], dst.getWriteSlice(0), dst.getWriteSlice(1), dst.getWriteSlice(2), .{
            .threshold = d.threshold,
            .scale = d.scale,
            .points = d.points,
            .diameter = d.diameter,
            .temporal_radius = d.temporal_radius,
            .weights = d.weights[0..temporal_diameter],
            .chroma = chroma,
            .bits_per_sample = bits_per_sample,
            .width = width,
            .height = height,
            .stride8 = stride8,
        });

        return dst.frame;
    }

    return null;
}

export fn ccdFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = core;
    const d: *CCDData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    vsapi.?.freeNode.?(d.node_ref);
    allocator.free(d.points);
    allocator.destroy(d);
}

export fn ccdCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = user_data;
    const zapi = ZAPI.init(vsapi, core, null);
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
            d.diameter = 9; // 4 + 4 + 1 (center)
        }
        if (medium) {
            @memcpy(d.points[i .. i + medium_points.len], &medium_points);
            i += medium_points.len;
            d.diameter = 17; // 8 + 8 + 1 (center)
        }
        if (high) {
            @memcpy(d.points[i .. i + high_points.len], &high_points);
            i += high_points.len;
            d.diameter = 25; // 12 + 12 + 1 (center)
        }
    }

    const scaled_diameter: u32 = @intFromFloat(@round(@as(f32, @floatFromInt(d.diameter)) * d.scale));
    if (scaled_diameter > d.vi.width or scaled_diameter > d.vi.height) {
        outz.setError(string.printf(allocator, "CCD: Scale {} produces a scaled filter diameter of {}, which is beyond the width {} or height {}. Reduce the scale amount.", .{ d.scale, scaled_diameter, d.vi.width, d.vi.height }));
        zapi.freeNode(d.node);
        allocator.free(d.points);
        return;
    }

    // Sort points to ensure optimal (cache aware) lookups.
    std.sort.insertion(Point, d.points, {}, less_than_points);

    // scale points
    for (d.points) |*point| {
        point[0] = @intFromFloat(@round(@as(f32, @floatFromInt(point[0])) * d.scale));
        point[1] = @intFromFloat(@round(@as(f32, @floatFromInt(point[1])) * d.scale));
    }

    d.node_ref = null;
    if (inz.getNodeVi2("ref")) |refvi| {
        if (!vsh.isSameVideoInfo(d.vi, refvi.vi)) {
            outz.setError("CCD: ref and source clip format, width, and height must match.");
            zapi.freeNode(d.node);
            zapi.freeNode(refvi.node);
            return;
        }
        d.node_ref = refvi.node;
    }

    const data: *CCDData = allocator.create(CCDData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.General,
        },
        vs.FilterDependency{
            .source = d.node_ref,
            .requestPattern = rp.General,
        },
    };
    const num_deps: u8 = if (d.node_ref) |_| 2 else 1;

    zapi.createVideoFilter(out, "CCD", d.vi, ccdGetFrame, ccdFree, fm.Parallel, deps[0..num_deps], data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("CCD", "clip:vnode;" ++
        "threshold:float:opt;" ++
        "temporal_radius:int:opt;" ++
        "points:int[]:opt;" ++
        "scale:float:opt;" ++
        "ref:vnode:opt;", "clip:vnode;", ccdCreate, null, plugin);
}
