const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;

const math = @import("common/math.zig");
const lossyCast = math.lossyCast;
const vscmn = @import("common/vapoursynth.zig");
const vec = @import("common/vector.zig");
const string = @import("common/string.zig");
const types = @import("common/type.zig");
const float_mode: std.builtin.FloatMode = if (@import("config").optimize_float) .optimized else .strict;

const vs = vapoursynth.vapoursynth4;
const vsh = vapoursynth.vshelper;
const ZAPI = vapoursynth.ZAPI;

const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;
const st = vs.SampleType;

// https://ziglang.org/documentation/master/#Choosing-an-Allocator
//
// Using the C allocator since we're passing pointers to allocated memory between Zig and C code,
// specifically the filter data between the Create and GetFrame functions.
const allocator = std.heap.c_allocator;

const MAX_RADIUS = 7;
const MAX_DIAMETER = MAX_RADIUS * 2 + 1;
//Maximum number of pixel differences considered by this plugin.
//Higher bit depths have their differences scaled to an 8-bit equivalent
//in order to work with the original LUT-based weighting approach.
const MAX_NUM_DIFFERENCES = 256;

const WeightMode = enum {
    inverse_difference,
    temporal,
};

const TTempSmoothData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    node_ref: ?*vs.Node,
    vi: *const vs.VideoInfo,

    maxr: u8, //Temporal radius
    threshold: [3]u9, // threshold in 8-bit scale (max is 256 (MAX_NUM_DIFFERENCES), thus the use of u16). Scaled in getFrame to pertinent format.
    fp: bool,
    scenechange: bool,

    weight_mode: [3]WeightMode,
    temporal_difference_weights: [3][][MAX_NUM_DIFFERENCES]f32,
    temporal_weights: [3][]f32,
    center_weight: f32,

    // Which planes we will process.
    process: [3]bool,
};

fn TTempSmooth(comptime T: type) type {
    const vector_len = vec.getVecSize(T);
    const VT = @Vector(vector_len, T);

    return struct {
        fn processPlaneScalar(
            comptime weight_mode: WeightMode,
            curr: []const T,
            curr_ref: []const T,
            neighbors: [2][]const []const T,
            neighbors_ref: [2][]const []const T,
            noalias dstp: []T,
            opt: struct {
                width: usize,
                height: usize,
                stride: usize,

                center_weight: f32,
                fp: bool,
                maxr: u8,
                shift: u8,
                temporal_difference_weights: []const [MAX_NUM_DIFFERENCES]f32,
                temporal_weights: []const f32,
                threshold: T,
            },
        ) void {
            @setFloatMode(float_mode);

            for (0..opt.height) |y| {
                for (0..opt.width) |x| {
                    const pixel_idx = y * opt.stride + x;
                    const current_pixel = curr_ref[pixel_idx];
                    var weight_sum = opt.center_weight; // sum of weights
                    var sum = lossyCast(f32, curr[pixel_idx]) * opt.center_weight; // sum of weighted pixels.

                    for (neighbors, neighbors_ref) |src_planes, ref_planes| {
                        var temporal_pixel1 = ref_planes[0][pixel_idx];

                        for (src_planes, ref_planes, 0..) |src, ref, i| {
                            const temporal_pixel2 = temporal_pixel1;
                            temporal_pixel1 = ref[pixel_idx];

                            const diff = switch (types.numberType(T)) {
                                .int => math.absDiff(current_pixel, temporal_pixel1),
                                .float => @min(math.absDiff(current_pixel, temporal_pixel1), 1.0),
                            };

                            const temporal_diff = switch (types.numberType(T)) {
                                .int => math.absDiff(temporal_pixel1, temporal_pixel2),
                                .float => @min(math.absDiff(temporal_pixel1, temporal_pixel2), 1.0),
                            };

                            // Note; This 'break' wrecks autovectorization,
                            // which could be improved by simply wrapping the
                            // weight_sum and sum updates with the if. However
                            // the intent is very clear, and we're using a
                            // custom written Vector version below anyways.
                            if (diff >= opt.threshold or temporal_diff >= opt.threshold) {
                                break;
                            }

                            const weight = switch (comptime weight_mode) {
                                .temporal => opt.temporal_weights[1 + i], //temporal_weights includes center, so skip over it with 1 +.
                                .inverse_difference => opt.temporal_difference_weights[i][if (types.isInt(T)) diff >> @intCast(opt.shift) else @intFromFloat(@trunc(diff * 255.0))],
                            };
                            weight_sum += weight;
                            sum += lossyCast(f32, src[pixel_idx]) * weight;
                        }

                        if (opt.fp) {
                            dstp[pixel_idx] = if (types.isInt(T))
                                @intFromFloat(@round(lossyCast(f32, curr[pixel_idx]) * (1.0 - weight_sum) + sum))
                            else
                                curr[pixel_idx] * (1.0 - weight_sum) + sum;
                        } else {
                            dstp[pixel_idx] = if (types.isInt(T))
                                @intFromFloat(@round(sum / weight_sum))
                            else
                                sum / weight_sum;
                        }
                    }
                }
            }
        }

        const VectorOptions = struct {
            maxr: u8,
            threshold: T,
            fp: bool,
            shift: u8,
            center_weight: f32,
            temporal_weights: []const f32,
            temporal_difference_weights: []const [MAX_NUM_DIFFERENCES]f32,
        };

        fn ttempSmoothVector(comptime weight_mode: WeightMode, noalias curr: []const T, noalias curr_ref: []const T, neighbors: [2][]const []const T, neighbors_ref: [2][]const []const T, noalias dstp: []T, offset: usize, opt: VectorOptions) void {
            @setFloatMode(float_mode);

            const SVT = @Vector(vector_len, f32); // sum vector type

            const center_weight: SVT = @splat(opt.center_weight);
            const threshold: VT = @splat(opt.threshold);
            const shift: @Vector(vector_len, u8) = @splat(opt.shift);
            const one: SVT = @splat(1.0);

            const current_pixel = vec.load(VT, curr_ref, offset);
            var weight_sum: SVT = center_weight; // sum of weights
            var sum: SVT = lossyCast(SVT, vec.load(VT, curr, offset)) * center_weight; // sum of weighted pixels.

            inline for (neighbors, neighbors_ref) |src_planes, ref_planes| {
                var temporal_pixel1 = vec.load(VT, ref_planes[0], offset);

                // Optimization: Unroll first iteration of the loop, which
                // saves us another load and some math + comparisons. This and
                // the 'inline for' on the outer loop takes performance up
                // from ~300fps -> 381fps, and 1200fps -> 1300fps for the
                // inv_diff and temporal modes, respectively
                var diff = switch (types.numberType(VT)) {
                    .int => math.absDiff(current_pixel, temporal_pixel1),
                    .float => @min(math.absDiff(current_pixel, temporal_pixel1), one),
                };

                var weight_idx: @Vector(vector_len, usize) = switch (T) {
                    u8 => diff,
                    u16 => diff >> @intCast(shift),
                    else => @intFromFloat(@trunc(diff * @as(SVT, @splat(255.0)))),
                };

                var weight: SVT = switch (comptime weight_mode) {
                    .temporal => @splat(opt.temporal_weights[1]),
                    .inverse_difference => vec.gatherArray(opt.temporal_difference_weights[0], weight_idx),
                };

                var srcv = lossyCast(SVT, vec.load(VT, src_planes[0], offset));
                var lt_thresholds = (diff < threshold);
                weight_sum = @select(f32, lt_thresholds, weight_sum + weight, weight_sum);
                sum = @select(f32, lt_thresholds, sum + (srcv * weight), sum);

                for (src_planes[1..], ref_planes[1..], 1..) |src, ref, i| {
                    const temporal_pixel2 = temporal_pixel1;
                    temporal_pixel1 = vec.load(VT, ref, offset);

                    diff = switch (types.numberType(VT)) {
                        .int => math.absDiff(current_pixel, temporal_pixel1),
                        .float => @min(math.absDiff(current_pixel, temporal_pixel1), one),
                    };

                    const temporal_diff = switch (types.numberType(VT)) {
                        .int => math.absDiff(temporal_pixel1, temporal_pixel2),
                        .float => @min(math.absDiff(temporal_pixel1, temporal_pixel2), one),
                    };

                    weight_idx = switch (T) {
                        u8 => diff,
                        u16 => diff >> @intCast(shift),
                        else => @intFromFloat(@trunc(diff * @as(SVT, @splat(255.0)))),
                    };

                    weight = switch (comptime weight_mode) {
                        .temporal => @splat(opt.temporal_weights[1 + i]),
                        .inverse_difference => vec.gatherArray(opt.temporal_difference_weights[i], weight_idx),
                    };

                    srcv = lossyCast(SVT, vec.load(VT, src, offset));
                    lt_thresholds = (diff < threshold) & (temporal_diff < threshold) & lt_thresholds;
                    weight_sum = @select(f32, lt_thresholds, weight_sum + weight, weight_sum);
                    sum = @select(f32, lt_thresholds, sum + (srcv * weight), sum);
                }
            }

            if (opt.fp) {
                const currv = lossyCast(SVT, vec.load(VT, curr, offset));
                const result: VT = switch (types.numberType(VT)) {
                    .int => @intFromFloat(@round(currv * (one - weight_sum) + sum)),
                    .float => currv * (one - weight_sum) + sum,
                };

                vec.store(VT, dstp, offset, result);
            } else {
                const result: VT = switch (types.numberType(VT)) {
                    .int => @intFromFloat(@round(sum / weight_sum)),
                    .float => sum / weight_sum,
                };

                vec.store(VT, dstp, offset, result);
            }
        }

        fn processPlaneVector(comptime weight_mode: WeightMode, curr: []const T, curr_ref: []const T, neighbors: [2][]const []const T, neighbors_ref: [2][]const []const T, noalias dstp: []T, opt: struct {
            width: usize,
            height: usize,
            stride: usize,

            maxr: u8,
            threshold: T,
            fp: bool,
            shift: u8,
            center_weight: f32,
            temporal_weights: []const f32,
            temporal_difference_weights: []const [MAX_NUM_DIFFERENCES]f32,
        }) void {
            const options: VectorOptions = .{
                .center_weight = opt.center_weight,
                .temporal_difference_weights = opt.temporal_difference_weights,
                .temporal_weights = opt.temporal_weights,
                .threshold = opt.threshold,
                .fp = opt.fp,
                .maxr = opt.maxr,
                .shift = opt.shift,
            };

            const width_simd = opt.width / vector_len * vector_len;
            for (0..opt.height) |y| {
                var x: usize = 0;
                while (x < width_simd) : (x += vector_len) {
                    const offset = y * opt.stride + x;
                    ttempSmoothVector(weight_mode, curr, curr_ref, neighbors, neighbors_ref, dstp, offset, options);
                }

                // If the video width is not perfectly aligned with the vector width, do one
                // last operation at the end of the plane to cover what's leftover from the loop above.
                if (width_simd < opt.width) {
                    ttempSmoothVector(weight_mode, curr, curr_ref, neighbors, neighbors_ref, dstp, (y * opt.stride) + opt.width - vector_len, options);
                }
            }
        }

        fn processPlane(curr8: []const u8, curr_ref8: []const u8, neighbors8: [2][]const []const u8, neighbors_ref8: [2][]const []const u8, noalias dstp8: []u8, opt: struct {
            width: usize,
            height: usize,
            stride8: usize,

            center_weight: f32,
            fp: bool,
            maxr: u8,
            shift: u8,
            temporal_difference_weights: []const [MAX_NUM_DIFFERENCES]f32,
            temporal_weights: []const f32,
            threshold: f32,
            weight_mode: WeightMode,
        }) void {
            const stride = opt.stride8 / @sizeOf(T);
            const curr: []const T = @ptrCast(@alignCast(curr8));
            const curr_ref: []const T = @ptrCast(@alignCast(curr_ref8));

            const neighbors: [2][]const []const T = .{
                @ptrCast(@alignCast(neighbors8[0])),
                @ptrCast(@alignCast(neighbors8[1])),
            };
            const neighbors_ref: [2][]const []const T = .{
                @ptrCast(@alignCast(neighbors_ref8[0])),
                @ptrCast(@alignCast(neighbors_ref8[1])),
            };

            const dstp: []T = @ptrCast(@alignCast(dstp8));

            const threshold = lossyCast(T, opt.threshold);

            switch (opt.weight_mode) {
                // inline else => |wm| processPlaneScalar(wm, curr, curr_ref, neighbors, neighbors_ref, dstp, .{
                //     .width = opt.width,
                //     .height = opt.height,
                //     .stride = stride,
                //
                //     .maxr = opt.maxr,
                //     .threshold = threshold,
                //     .fp = opt.fp,
                //     .shift = opt.shift,
                //     .center_weight = opt.center_weight,
                //     .temporal_weights = opt.temporal_weights,
                //     .temporal_difference_weights = opt.temporal_difference_weights,
                // }),
                inline else => |wm| processPlaneVector(wm, curr, curr_ref, neighbors, neighbors_ref, dstp, .{
                    .width = opt.width,
                    .height = opt.height,
                    .stride = stride,

                    .maxr = opt.maxr,
                    .threshold = threshold,
                    .fp = opt.fp,
                    .shift = opt.shift,
                    .center_weight = opt.center_weight,
                    .temporal_weights = opt.temporal_weights,
                    .temporal_difference_weights = opt.temporal_difference_weights,
                }),
            }
        }
    };
}

fn ttempSmoothGetFrame(_n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const d: *TTempSmoothData = @ptrCast(@alignCast(instance_data));
    const zapi: ZAPI = ZAPI.init(vsapi, core, frame_ctx);

    const n: usize = lossyCast(usize, _n);
    const first: usize = n -| d.maxr;
    const last: usize = @min(n + d.maxr, lossyCast(usize, d.vi.numFrames - 1));
    const has_ref = d.node_ref != null;

    if (activation_reason == ar.Initial) {
        for (first..(last + 1)) |i| {
            zapi.requestFrameFilter(@intCast(i), d.node);

            if (has_ref) {
                zapi.requestFrameFilter(@intCast(i), d.node_ref);
            }
        }
    } else if (activation_reason == ar.AllFramesReady) {
        var src_frames: [MAX_DIAMETER]ZAPI.ZFrame(*const vs.Frame) = undefined;
        var ref_frames: [MAX_DIAMETER]ZAPI.ZFrame(*const vs.Frame) = undefined;
        const diameter = d.maxr * 2 + 1;

        {
            var i = -lossyCast(i8, d.maxr); // -d.maxr
            while (i <= d.maxr) : (i += 1) {
                const frame_number: i32 = std.math.clamp(lossyCast(i32, n) + i, 0, d.vi.numFrames - 1);
                const index: usize = @intCast(i + lossyCast(i8, d.maxr)); // i + d.maxr

                src_frames[index] = zapi.initZFrame(d.node, frame_number);

                if (has_ref) {
                    ref_frames[index] = zapi.initZFrame(d.node_ref, frame_number);
                }
            }
        }
        defer for (0..diameter) |i| {
            src_frames[i].deinit();
            if (has_ref) {
                ref_frames[i].deinit();
            }
        };

        var from_frame_idx: usize = 0;
        var to_frame_idx: usize = diameter - 1;
        if (d.scenechange) {
            const frames = if (has_ref) ref_frames else src_frames;
            {
                var i = d.maxr;
                while (i > 0) : (i -= 1) {
                    if (frames[i].getPropertiesRO().getInt(i32, "_SceneChangePrev") == 1) {
                        from_frame_idx = i;
                        break;
                    }
                }
            }
            {
                var i = d.maxr;
                while (i < diameter - 1) : (i += 1) {
                    if (frames[i].getPropertiesRO().getInt(i32, "_SceneChangeNext") == 1) {
                        to_frame_idx = i;
                        break;
                    }
                }
            }
        }

        const dst = src_frames[d.maxr].newVideoFrame2(d.process);
        const shift = lossyCast(u8, d.vi.format.bitsPerSample) - 8;

        const processPlane = switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &TTempSmooth(u8).processPlane,
            .U16 => &TTempSmooth(u16).processPlane,
            // Math.pow doesn't support f16 yet, so have to disable f16 support for the short term until the following is addressed:
            // * https://github.com/ziglang/zig/issues/23602
            // * https://github.com/ziglang/zig/pull/23631
            // .F16 => &TTempSmooth(f16).processPlane,
            .F32 => &TTempSmooth(f32).processPlane,
            else => unreachable,
        };

        for (0..@intCast(d.vi.format.numPlanes)) |plane| {
            if (!d.process[plane]) {
                continue;
            }

            const width = dst.getWidth(plane);
            const height = dst.getHeight(plane);
            const stride8 = dst.getStride(plane);

            const curr8 = src_frames[d.maxr].getReadSlice(plane);
            const curr_ref8 = if (has_ref) ref_frames[d.maxr].getReadSlice(plane) else curr8;

            var prev8: [MAX_RADIUS][]const u8 = undefined;
            var prev_ref8: [MAX_RADIUS][]const u8 = undefined;
            var next8: [MAX_RADIUS][]const u8 = undefined;
            var next_ref8: [MAX_RADIUS][]const u8 = undefined;

            for (0..d.maxr) |i| {
                prev8[i] = src_frames[d.maxr - 1 - i].getReadSlice(plane);
                prev_ref8[i] = if (has_ref) ref_frames[d.maxr - 1 - i].getReadSlice(plane) else prev8[i];

                next8[i] = src_frames[d.maxr + 1 + i].getReadSlice(plane);
                next_ref8[i] = if (has_ref) ref_frames[d.maxr + 1 + i].getReadSlice(plane) else next8[i];
            }

            const neighbors = .{
                prev8[0 .. d.maxr - from_frame_idx],
                next8[0 .. to_frame_idx - d.maxr],
            };

            const neighbors_ref = .{
                prev_ref8[0 .. d.maxr - from_frame_idx],
                next_ref8[0 .. to_frame_idx - d.maxr],
            };

            const dstp8: []u8 = dst.getWriteSlice(plane);
            const threshold: f32 = vscmn.scaleToFormat(f32, d.vi.format, d.threshold[plane], 0);

            processPlane(curr8, curr_ref8, neighbors, neighbors_ref, dstp8, .{
                .center_weight = d.center_weight,
                .fp = d.fp,
                .maxr = d.maxr,
                .shift = shift,
                .temporal_difference_weights = d.temporal_difference_weights[plane],
                .temporal_weights = d.temporal_weights[plane],
                .threshold = threshold,
                .weight_mode = d.weight_mode[plane],

                .height = height,
                .width = width,
                .stride8 = stride8,
            });
        }

        return dst.frame;
    }

    return null;
}

export fn ttempSmoothFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = core;
    const d: *TTempSmoothData = @ptrCast(@alignCast(instance_data));

    vsapi.?.freeNode.?(d.node);
    vsapi.?.freeNode.?(d.node_ref);

    for (0..3) |plane| {
        if (!d.process[plane]) {
            continue;
        }

        if (d.weight_mode[plane] == .inverse_difference) {
            allocator.free(d.temporal_difference_weights[plane]);
        } else {
            allocator.free(d.temporal_weights[plane]);
        }
    }

    allocator.destroy(d);
}

fn calculateTemporalWeights(maxr: u8, strength: u8, weights: []f32, center_weight: *f32) void {
    for (0..maxr + 1) |i| {
        weights[i] = if (i < strength) 1.0 else 1.0 / @as(f32, @floatFromInt(i - strength + 2));
    }

    var sum: f32 = weights[0]; // center weight
    for (weights[1..]) |weight| {
        sum += (weight * 2);
    }

    for (weights) |*weight| {
        weight.* /= sum;
    }

    center_weight.* = weights[0];
}

test calculateTemporalWeights {
    const temporal_weights: []f32 = try testingAllocator.alloc(f32, 8);
    defer testingAllocator.free(temporal_weights);

    var center_weight: f32 = 0;

    // Strength is greater than maxr, so all frames are equally weighted
    calculateTemporalWeights(7, 8, temporal_weights, &center_weight);
    try std.testing.expectEqualDeep(&[_]f32{
        1.0 / 15.0, 1.0 / 15.0, 1.0 / 15.0, 1.0 / 15.0, 1.0 / 15.0, //
        1.0 / 15.0, 1.0 / 15.0, 1.0 / 15.0, //
    }, temporal_weights);
    try std.testing.expectEqual(1.0 / 15.0, center_weight);

    @memset(temporal_weights, 0); // clear results

    // Radius 1, diameter = 3, so weight center frame highest, and prev/next frames half of center weight.
    calculateTemporalWeights(1, 1, temporal_weights, &center_weight);
    try std.testing.expectEqualDeep(&[_]f32{
        0.5, 0.25,
    }, temporal_weights[0..2]);
    try std.testing.expectEqual(0.5, center_weight);

    @memset(temporal_weights, 0); // clear results

    // Sum of weights is 2.66666666 (1/3 + 1/2 + 1 + 1/2 + 1/3), so center is 1.0 / 2.666666, next frames are 0.5 / 2.66666, etc etc.
    calculateTemporalWeights(2, 1, temporal_weights, &center_weight);
    try std.testing.expectEqualDeep(&[_]f32{ 0.375, 0.1875, 0.125 }, temporal_weights[0..3]);
    try std.testing.expectEqual(0.375, center_weight);
}

// Temporal difference weights.
// Center weight is kept separate (since the difference between the center pixel and itself is always 0)
// Then temporal_difference_weights holds the weights for the surrounding frames and their differences.
// Meaning that
// temporal_difference_weights[0][...] holds the weights for the frames on either side of the source frame (-1 and +1) (prev and next)
// temporal_difference_weights[1][...] holds the weights for frames 2 steps away (-2 and +2) (2nd prev and 2nd next).
// etc.
fn calculateTemporalDifferenceWeights(threshold: u9, mdiff: u8, maxr: u8, strength: u8, temporal_difference_weights: [][MAX_NUM_DIFFERENCES]f32, center_weight: *f32) void {
    // Inverse pixel difference waiting.
    var temporal_weights: [MAX_RADIUS + 1]f32 = @splat(0); // Radius + 1 (center frame)
    var difference_weights: [MAX_NUM_DIFFERENCES]f32 = @splat(0);

    for (0..maxr + 1) |i| {
        // inverse weight frames further away from the center.
        // aka the farther a frame is from the current frame, the less impact it has on the current frame's pixel.
        temporal_weights[i] = if (i < strength) 1.0 else 1.0 / @as(f32, @floatFromInt(i - strength + 2));
    }

    const step: f32 = MAX_NUM_DIFFERENCES / @as(f32, @floatFromInt(threshold - @min(mdiff, threshold - 1)));
    var base: f32 = MAX_NUM_DIFFERENCES;

    // Set differences between 0 and mdiff to maximum weight,
    // then reduce the weights for the differences between mdiff and threshold, where the weight at threshold is 0.
    // So weights closer to mdiff are higher and weights closer to threshold are lower.
    for (0..threshold) |diff| {
        if (diff < mdiff) {
            // Set differences less than mdiff to maximum weight;
            difference_weights[diff] = MAX_NUM_DIFFERENCES;
        } else {
            if (base > 0.0) {
                difference_weights[diff] = base;
            } else {
                break;
            }
            base -= step;
        }
    }

    var temporal_sum: f32 = temporal_weights[0];

    for (1..maxr + 1) |radius| {
        temporal_sum += temporal_weights[radius] * 2.0;

        for (0..MAX_NUM_DIFFERENCES) |diff| {
            temporal_difference_weights[radius - 1][diff] = temporal_weights[radius] * difference_weights[diff] / MAX_NUM_DIFFERENCES;
        }
    }

    for (0..maxr) |radius| {
        for (0..MAX_NUM_DIFFERENCES) |diff| {
            temporal_difference_weights[radius][diff] /= temporal_sum;
        }
    }

    center_weight.* = temporal_weights[0] / temporal_sum;
}

test calculateTemporalDifferenceWeights {
    // Maximum radius used in tests is 3
    // Maximum threshold used in tests is 5
    // So allocate memory accordingly.
    // Tests would segfault if they write past the given allocations.
    var temporal_difference_weights: [][MAX_NUM_DIFFERENCES]f32 = try testingAllocator.alloc([MAX_NUM_DIFFERENCES]f32, 3);
    for (0..temporal_difference_weights.len) |i| {
        temporal_difference_weights[i] = @splat(0);
    }
    defer {
        testingAllocator.free(temporal_difference_weights);
    }

    var center_weight: f32 = 0;

    // With threshold, mdiff, and radius of 1, center weight is 0.5,
    // the previous and next frames have a weight of 0.25 (for a total of 1.0 weight)
    calculateTemporalDifferenceWeights(1, 1, 1, 1, temporal_difference_weights, &center_weight);
    try std.testing.expectEqual(0.25, temporal_difference_weights[0][0]);
    try std.testing.expectEqual(0, temporal_difference_weights[0][1]); // Ensure weights at threshold (1) are zero
    try std.testing.expectEqual(0, temporal_difference_weights[1][0]); // Ensure weights at next frame are 0 (not set)
    try std.testing.expectEqual(0.5, center_weight);

    // With threshold and mdiff equal (3), the difference weights are all equal,
    // and there's only a single temporal weight.
    calculateTemporalDifferenceWeights(3, 3, 1, 1, temporal_difference_weights, &center_weight);
    try std.testing.expectEqual(0.25, temporal_difference_weights[0][0]);
    try std.testing.expectEqual(0.25, temporal_difference_weights[0][1]);
    try std.testing.expectEqual(0.25, temporal_difference_weights[0][2]);
    try std.testing.expectEqual(0, temporal_difference_weights[0][3]); // Ensure weights at threshold (3) are zero
    try std.testing.expectEqual(0, temporal_difference_weights[1][0]); // Ensure weights at next frame are 0 (not set)
    try std.testing.expectEqual(0.5, center_weight);

    // With threshold 5 and mdiff 2, maximum weight is assigned to the first 3 (0,1,2) differences, with a reducing scale
    // between mdiff and threshold.
    calculateTemporalDifferenceWeights(5, 2, 1, 1, temporal_difference_weights, &center_weight);
    try std.testing.expectEqual(0.25, temporal_difference_weights[0][0]);
    try std.testing.expectEqual(0.25, temporal_difference_weights[0][1]);
    try std.testing.expectEqual(0.25, temporal_difference_weights[0][2]); //mdiff = 2
    try std.testing.expectEqual(0.16666666, temporal_difference_weights[0][3]);
    try std.testing.expectEqual(0.08333332, temporal_difference_weights[0][4]);
    try std.testing.expectEqual(0, temporal_difference_weights[1][0]); // Ensure weights at next frame are 0 (not set)
    try std.testing.expectEqual(0.5, center_weight);

    @memset(&temporal_difference_weights[0], 0); // clear weights

    // With strength greater than maxr, all frames are given an equal weight.
    // With maxr = 3, that's 7 total frames (3 + 1 (center) + 3), so weight is 1.0 / 7.0
    calculateTemporalDifferenceWeights(1, 1, 3, 4, temporal_difference_weights, &center_weight);
    try std.testing.expectEqual(1.0 / 7.0, temporal_difference_weights[0][0]); // next frame
    try std.testing.expectEqual(0, temporal_difference_weights[0][1]); //threshold = 1, zero weight
    try std.testing.expectEqual(1.0 / 7.0, temporal_difference_weights[1][0]); // next next frame
    try std.testing.expectEqual(0, temporal_difference_weights[1][1]); //threshold = 1, zero weight
    try std.testing.expectEqual(1.0 / 7.0, temporal_difference_weights[2][0]); // next next next frame (radius = 3)
    try std.testing.expectEqual(0, temporal_difference_weights[2][1]); //threshold = 1, zero weight
    try std.testing.expectEqual(1.0 / 7.0, center_weight); //even center frame gets the same weight, due to strength being greater than maxr.

    // Strength is less than maxr, so weights scale inversely the farther they are from center.
    // Temporal weights are 1, 1/2, 1/3, 1/4, which with non-center weights
    // doubled in sum is 1, 1, 2/3, 1/2, which sums to 3.16666666666666666666
    calculateTemporalDifferenceWeights(1, 1, 3, 1, temporal_difference_weights, &center_weight);
    try std.testing.expectEqual(1.0 / 2.0 / 3.16666666666666666666, temporal_difference_weights[0][0]); // next frame
    try std.testing.expectEqual(1.0 / 3.0 / 3.16666666666666666666, temporal_difference_weights[1][0]); // next next frame
    try std.testing.expectEqual(1.0 / 4.0 / 3.16666666666666666666, temporal_difference_weights[2][0]); // next next next frame
    try std.testing.expectEqual(1.0 / 3.16666666666666666666, center_weight);
}

export fn ttempSmoothCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = user_data;
    var d: TTempSmoothData = undefined;

    const zapi = ZAPI.init(vsapi, core, null);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);

    d.node, d.vi = inz.getNodeVi("clip").?;

    if (!vsh.isConstantVideoFormat(d.vi)) {
        zapi.freeNode(d.node);
        return outz.setError("TTempSmooth: only constant format input supported");
    }

    d.maxr = inz.getInt(u8, "maxr") orelse 3;

    if ((d.maxr < 1) or (d.maxr > MAX_RADIUS)) {
        zapi.freeNode(d.node);
        return outz.setError("TTempSmooth: maxr must be between 1 and 7 (inclusive)");
    }

    d.process = vscmn.normalizePlanes(d.vi.format, in, vsapi) catch |e| {
        zapi.freeNode(d.node);

        switch (e) {
            vscmn.PlanesError.IndexOutOfRange => outz.setError("TTempSmooth: Plane index out of range."),
            vscmn.PlanesError.SpecifiedTwice => outz.setError("TTempSmooth: Plane specified twice."),
        }
        return;
    };

    d.fp = inz.getBool("fp") orelse true;

    if ((inz.numElements("thresh") orelse 0) == 0) {
        d.threshold = .{ 4, 5, 5 };
    } else {
        for (0..3) |plane| {
            if (inz.getInt2(i32, "thresh", plane)) |thresh| {
                if (thresh < 1 or thresh > MAX_NUM_DIFFERENCES) {
                    zapi.freeNode(d.node);
                    return outz.setError("TTempSmooth: thresh must be between 1 and 256");
                }

                d.threshold[plane] = @intCast(thresh);
            } else {
                d.threshold[plane] = d.threshold[plane - 1];
            }
        }
    }

    var mdiff: [3]u8 = undefined;

    if ((inz.numElements("mdiff") orelse 0) == 0) {
        mdiff = .{ 2, 3, 3 };
    } else {
        for (0..3) |plane| {
            if (inz.getInt2(i32, "mdiff", plane)) |diff| {
                if (diff < 0 or diff > 255) {
                    zapi.freeNode(d.node);
                    return outz.setError("TTempSmooth: mdiff must be between 0 and 255");
                }

                mdiff[plane] = @intCast(diff);
            } else {
                mdiff[plane] = mdiff[plane - 1];
            }
        }
    }

    const strength = inz.getInt(u8, "strength") orelse 2;

    if (strength < 1 or strength > 8) {
        zapi.freeNode(d.node);
        return outz.setError("TTempSmooth: strength must be between 1 and 8 (inclusive)");
    }

    for (0..3) |plane| {
        if (!d.process[plane]) {
            continue;
        }

        if (d.threshold[plane] > mdiff[plane] + 1) {
            d.weight_mode[plane] = .inverse_difference;

            // Dynamically allocate the slice of slices for the given plane.
            // Aka a slice for each frame, containing the lookup table of weights;
            d.temporal_difference_weights[plane] = allocator.alloc([MAX_NUM_DIFFERENCES]f32, d.maxr + 1) catch unreachable;
            for (0..d.temporal_difference_weights[plane].len) |i| {
                d.temporal_difference_weights[plane][i] = @splat(0);
            }

            calculateTemporalDifferenceWeights(d.threshold[plane], mdiff[plane], d.maxr, strength, d.temporal_difference_weights[plane], &d.center_weight);
        } else {
            d.weight_mode[plane] = .temporal;

            d.temporal_weights[plane] = allocator.alloc(f32, d.maxr + 1) catch unreachable;
            calculateTemporalWeights(d.maxr, strength, d.temporal_weights[plane], &d.center_weight);
        }
    }

    const scene_change_threshold = if (inz.getFloat(f32, "scthresh")) |scthresh| blk: {
        if (scthresh < -1 or scthresh > 100) {
            zapi.freeNode(d.node);
            return outz.setError("TTempSmooth: scthresh must be between -1 and 100.0 (inclusive)");
        }
        break :blk scthresh;
    } else 12;

    d.scenechange = scene_change_threshold != 0;

    d.node_ref = inz.getNode("pfclip");
    if (d.node_ref != null) {
        const refvi = zapi.getVideoInfo(d.node_ref);

        if (!vsh.isSameVideoFormat(&d.vi.format, &refvi.format)) {
            zapi.freeNode(d.node);
            zapi.freeNode(d.node_ref);
            return outz.setError("pfclip must have same format and dimensions as the main clip");
        }
    }

    if (scene_change_threshold > 0) {
        if (d.vi.format.colorFamily == vs.ColorFamily.RGB) {
            zapi.freeNode(d.node);
            zapi.freeNode(d.node_ref);
            return outz.setError(
                \\TTempSmooth: scthresh > 0 does not work with RGB. 
                \\Invoke SCDetect (or similar) yourself with an RGB->YUV converted clip, 
                \\copy the properties (CopyFrameProps) to your input clip,
                \\and then invoke TTempSmooth with scthresh=-1 to use those properties.
            );
        }

        if (zapi.getPluginByID("com.vapoursynth.misc")) |misc_plugin| {
            const args = zapi.createZMap();
            defer args.free();

            const node = if (d.node_ref != null) d.node_ref else d.node;

            _ = args.consumeNode("clip", node, .Replace);
            args.setFloat("threshold", scene_change_threshold / 100.0, .Replace);

            const ret = zapi.initZMap(zapi.invoke(misc_plugin, "SCDetect", args.map));
            defer ret.free();

            if (ret.getNode("clip")) |n| {
                if (d.node_ref != null) {
                    d.node_ref = n;
                } else {
                    d.node = n;
                }
            } else {
                zapi.freeNode(d.node);
                zapi.freeNode(d.node_ref);
                return outz.setError("TTempSmooth: Unexpected error while invoking SCDetect");
            }
        } else {
            zapi.freeNode(d.node);
            zapi.freeNode(d.node_ref);
            return outz.setError("TTempSmooth: Miscellaneous filters (https://github.com/vapoursynth/vs-miscfilters-obsolete) plugin is required in order to use scene change detection.");
        }
    }

    const data: *TTempSmoothData = allocator.create(TTempSmoothData) catch unreachable;
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
    const num_deps: u8 = if (d.node_ref != null) 2 else 1;

    zapi.createVideoFilter(out, "TTempSmooth", d.vi, ttempSmoothGetFrame, ttempSmoothFree, fm.Parallel, deps[0..num_deps], data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("TTempSmooth", "clip:vnode;maxr:int:opt;thresh:int[]:opt;mdiff:int[]:opt;strength:int:opt;scthresh:float:opt;fp:int:opt;pfclip:vnode:opt;planes:int[]:opt;", "clip:vnode;", ttempSmoothCreate, null, plugin);
}
