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

const WeightMode = enum {
    inverse_difference,
    temporal,
};

const TTempSmoothData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    vi: *const vs.VideoInfo,

    maxr: u8, //Temporal radius
    threshold: [3]u9, // threshold in 8-bit scale (max is 256, thus the use of u16). Scaled in getFrame to pertinent format.
    fp: bool,
    pfclip: ?*vs.Node,

    weight_mode: WeightMode,
    temporal_difference_weights: [3][][]f32,
    temporal_weights: [3][]f32,
    center_weight: [3]f32,

    // Which planes we will process.
    process: [3]bool,
};

fn TTempSmooth(comptime T: type) type {
    return struct {
        fn processPlaneScalar(srcp: []const []const T, pfp: []const []const T, noalias dstp: []T, width: usize, height: usize, stride: usize, maxr: u8, threshold: T, shift: u8, center_weight: f32, comptime weight_mode: WeightMode, temporal_weights: []const f32, temporal_difference_weights: []const []const f32) void {
            // TODO: Make these params.
            const from_frame_idx = -1;
            const to_frame_idx = maxr * 2 + 1;

            for (0..height) |row| {
                for (0..width) |column| {
                    const pixel_idx = row * stride + column;
                    const current_pixel = pfp[maxr][pixel_idx];
                    var weight_sum = center_weight; // sum of weights
                    var sum = lossyCast(f32, srcp[maxr][pixel_idx]) * center_weight; // sum of weighted pixels.

                    // Check previous frames, starting with the frame closest to the center
                    // and then walking backwards.
                    var frame_idx: usize = maxr - 1;

                    if (frame_idx > from_frame_idx) {
                        var temporal_pixel1 = pfp[frame_idx][pixel_idx];
                        var diff = if (types.isInt(T))
                            math.absDiff(current_pixel, temporal_pixel1)
                        else
                            @min(math.absDiff(current_pixel, temporal_pixel1), 1.0);

                        if (diff < threshold) {
                            var weight = switch (comptime weight_mode) {
                                .temporal => temporal_weights[frame_idx],
                                .inverse_difference => temporal_difference_weights[maxr - 1 - frame_idx][if (types.isInt(T)) diff >> @intCast(shift) else @intFromFloat(@trunc(diff * 255.0))],
                                //                                                 ^ temporal_difference_weights stores only radius (not diameter) number of frames,
                                //                                                 so we subtract in order to correct the lookup.
                                //                                                 Note that temporal_difference_weights[0] contains the weights for
                                //                                                 the frames on either side of the center, so maxr - 1 and maxr + 1.
                            };
                            weight_sum += weight;
                            sum += lossyCast(f32, srcp[frame_idx][pixel_idx]) * weight;

                            //wrapping subtraction to make working with usize
                            //and "beyond zero" easier, vs using isize and a
                            //bunch of casting.
                            frame_idx -%= 1;

                            //check against maxInt of usize to see if we've wrapped around.
                            //If we have, then it means that we've gone beyond zero and thus already processed the
                            //last frame.
                            while (frame_idx != std.math.maxInt(usize) and frame_idx > from_frame_idx) {
                                const temporal_pixel2 = temporal_pixel1;
                                temporal_pixel1 = pfp[frame_idx][pixel_idx];

                                // diff = abs(current_pixel - temporal_pixel1)
                                diff = if (types.isInt(T))
                                    math.absDiff(current_pixel, temporal_pixel1)
                                else
                                    @min(math.absDiff(current_pixel, temporal_pixel1), 1.0);

                                // temporal_diff = abs(temporal_pixel1 - temporal_pixel2)
                                const temporal_diff = if (types.isInt(T))
                                    math.absDiff(temporal_pixel1, temporal_pixel2)
                                else
                                    @min(math.absDiff(temporal_pixel1, temporal_pixel2), 1.0);

                                if (diff < threshold and temporal_diff < threshold) {
                                    weight = switch (comptime weight_mode) {
                                        .temporal => temporal_weights[frame_idx],
                                        .inverse_difference => temporal_difference_weights[maxr - 1 - frame_idx][if (types.isInt(T)) diff >> @intCast(shift) else @intFromFloat(@trunc(diff * 255.0))],
                                    };
                                    weight_sum += weight;
                                    sum += lossyCast(f32, srcp[frame_idx][pixel_idx]) * weight;

                                    //wrapping subtraction to make working with usize
                                    //and "beyond zero" easier, vs using isize and a
                                    //bunch of casting.
                                    frame_idx -%= 1;
                                } else {
                                    break;
                                }
                            }
                        }
                    }

                    // Check next frames, starting with the frame closest to the center
                    // and then walking forwards.
                    frame_idx = maxr + 1;

                    if (frame_idx < to_frame_idx) {
                        // Same code as above, only frame_idx += 1 instead of frame_idx -= 1
                        // and frame_idx < to_frame_idx instead of frame_idx > from_frame_idx
                        var temporal_pixel1 = pfp[frame_idx][pixel_idx];

                        var diff = if (types.isInt(T))
                            math.absDiff(current_pixel, temporal_pixel1)
                        else
                            @min(math.absDiff(current_pixel, temporal_pixel1), 1.0);

                        if (diff < threshold) {
                            var weight = switch (comptime weight_mode) {
                                .temporal => temporal_weights[frame_idx],
                                .inverse_difference => temporal_difference_weights[frame_idx - maxr - 1][if (types.isInt(T)) diff >> @intCast(shift) else @intFromFloat(@trunc(diff * 255.0))],
                                //                                                 ^ temporal_difference_weights stores only radius (not diameter) number of frames,
                                //                                                 so we subtract in order to correct the lookup.
                                //                                                 Note that temporal_difference_weights[0] contains the weights for
                                //                                                 the frames on either side of the center, so maxr - 1 and maxr + 1.
                            };
                            weight_sum += weight;
                            sum += lossyCast(f32, srcp[frame_idx][pixel_idx]) * weight;

                            frame_idx += 1;

                            while (frame_idx < to_frame_idx) {
                                const temporal_pixel2 = temporal_pixel1;
                                temporal_pixel1 = pfp[frame_idx][pixel_idx];

                                // diff = abs(current_pixel - temporal_pixel1)
                                diff = if (types.isInt(T))
                                    math.absDiff(current_pixel, temporal_pixel1)
                                else
                                    @min(math.absDiff(current_pixel, temporal_pixel1), 1.0);

                                // temporal_diff = abs(temporal_pixel1 - temporal_pixel2)
                                const temporal_diff = if (types.isInt(T))
                                    math.absDiff(temporal_pixel1, temporal_pixel2)
                                else
                                    @min(math.absDiff(temporal_pixel1, temporal_pixel2), 1.0);

                                if (diff < threshold and temporal_diff < threshold) {
                                    weight = switch (comptime weight_mode) {
                                        .temporal => temporal_weights[frame_idx],
                                        .inverse_difference => temporal_difference_weights[frame_idx - maxr - 1][if (types.isInt(T)) diff >> @intCast(shift) else @intFromFloat(@trunc(diff * 255.0))],
                                    };
                                    weight_sum += weight;
                                    sum += lossyCast(f32, srcp[frame_idx][pixel_idx]) * weight;

                                    frame_idx += 1;
                                } else {
                                    break;
                                }
                            }
                        }
                    }

                    //TODO: support fp (possibly as comptime if performance is hit.
                    if (true) {
                        dstp[pixel_idx] = if (types.isInt(T))
                            @intFromFloat(@round(lossyCast(f32, srcp[maxr][pixel_idx]) * (1.0 - weight_sum) + sum))
                        else
                            srcp[maxr][pixel_idx] * (1.0 - weight_sum) + sum;
                    } else {
                        dstp[pixel_idx] = if (types.isInt(T))
                            @intFromFloat(@round(sum / weight_sum))
                        else
                            sum / weight_sum;
                    }
                }
            }
        }

        pub fn getFrame(_n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
            // Assign frame_data to nothing to stop compiler complaints
            _ = frame_data;

            const d: *TTempSmoothData = @ptrCast(@alignCast(instance_data));
            const zapi: ZAPI = ZAPI.init(vsapi, core);

            const n: usize = lossyCast(usize, _n);
            const first: usize = n -| d.maxr;
            const last: usize = @min(n + d.maxr, lossyCast(usize, d.vi.numFrames - 1));

            if (activation_reason == ar.Initial) {
                for (first..(last + 1)) |i| {
                    zapi.requestFrameFilter(@intCast(i), d.node, frame_ctx);

                    if (d.pfclip != null) {
                        zapi.requestFrameFilter(@intCast(n), d.pfclip, frame_ctx);
                    }
                }
            } else if (activation_reason == ar.AllFramesReady) {
                var src_frames: [MAX_DIAMETER]?*const vs.Frame = undefined;
                var pf_frames: [MAX_DIAMETER]?*const vs.Frame = undefined;
                const diameter = d.maxr * 2 + 1;

                {
                    var i = -lossyCast(i8, d.maxr); // -d.maxr
                    while (i <= d.maxr) : (i += 1) {
                        const frame_number: i32 = std.math.clamp(lossyCast(i32, n) + i, 0, d.vi.numFrames - 1);
                        const index: usize = @intCast(i + lossyCast(i8, d.maxr)); // i + d.maxr

                        src_frames[index] = zapi.getFrameFilter(frame_number, d.node, frame_ctx);

                        if (d.pfclip != null) {
                            pf_frames[index] = zapi.getFrameFilter(frame_number, d.node, frame_ctx);
                        }
                    }
                }
                defer for (0..diameter) |i| {
                    zapi.freeFrame(src_frames[i]);
                    if (d.pfclip != null) {
                        zapi.freeFrame(pf_frames[i]);
                    }
                };

                const dst = vscmn.newVideoFrame(&d.process, src_frames[d.maxr], d.vi, core, vsapi);

                for (0..@intCast(d.vi.format.numPlanes)) |uplane| {
                    if (!d.process[uplane]) {
                        continue;
                    }

                    const iplane: c_int = @intCast(uplane);

                    const width: usize = @intCast(zapi.getFrameWidth(dst, iplane));
                    const height: usize = @intCast(zapi.getFrameHeight(dst, iplane));
                    const stride: usize = @as(usize, @intCast(zapi.getStride(dst, iplane))) / @sizeOf(T);

                    var srcp: [MAX_DIAMETER][]const T = undefined;
                    for (0..diameter) |i| {
                        srcp[i] = @as([*]const T, @ptrCast(@alignCast(zapi.getReadPtr(src_frames[i], iplane))))[0..(height * stride)];
                    }

                    var pfp: [MAX_DIAMETER][]const T = undefined;
                    if (d.pfclip != null) {
                        for (0..diameter) |i| {
                            pfp[i] = @as([*]const T, @ptrCast(@alignCast(zapi.getReadPtr(pf_frames[i], iplane))))[0..(height * stride)];
                        }
                    }

                    const dstp: []T = @as([*]T, @ptrCast(@alignCast(zapi.getWritePtr(dst, iplane))))[0..(height * stride)];

                    // const threshold: T = if (types.isInt(T)) @intCast(d.threshold[uplane]) else @floatFromInt(d.threshold[uplane]);
                    const threshold: T = vscmn.scaleToFormat(T, d.vi.format, d.threshold[uplane], 0);
                    const shift = lossyCast(u8, d.vi.format.bitsPerSample) - 8;

                    switch (d.weight_mode) {
                        inline else => |wm| processPlaneScalar(srcp[0..diameter], if (d.pfclip != null) pfp[0..diameter] else srcp[0..diameter], dstp, width, height, stride, d.maxr, threshold, shift, d.center_weight[uplane], wm, d.temporal_weights[uplane], d.temporal_difference_weights[uplane]),
                    }
                }

                return dst;
            }

            return null;
        }
    };
}

export fn ttempSmoothFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *TTempSmoothData = @ptrCast(@alignCast(instance_data));

    vsapi.?.freeNode.?(d.node);

    for (0..3) |plane| {
        if (d.weight_mode == .inverse_difference) {
            for (0..d.temporal_difference_weights[plane].len) |radius| {
                allocator.free(d.temporal_difference_weights[plane][radius]);
            }
            allocator.free(d.temporal_difference_weights[plane]);
        } else {
            allocator.free(d.temporal_weights[plane]);
        }
    }

    allocator.destroy(d);
}

fn calculateTemporalWeights(maxr: u8, strength: u8, temporal_weights: *[]f32, center_weight: *f32) void {
    const diameter = maxr * 2 + 1;
    var weights: []f32 = temporal_weights.*;

    var sum: f32 = 0;

    // Symmetric distribution of temporal weights from the center outwards.
    for (0..maxr + 1) |radius| {
        weights[maxr - radius] = if (radius < strength) 1.0 else 1.0 / @as(f32, @floatFromInt(radius - strength + 2));
        weights[maxr + radius] = weights[maxr - radius];
    }

    for (0..diameter) |i| {
        sum += weights[i];
    }

    for (0..diameter) |i| {
        weights[i] /= sum;
    }

    // There was a bug here in the C version of TTempsmooth, wherein
    // there was only a single center weight value, instead of one per plane,
    // so the value for the center weight that was actually used in the filter
    // was the result of the last plane calculation, even if said plane used vastly different thresholds.
    center_weight.* = weights[maxr];
}

test calculateTemporalWeights {
    var temporal_weights: []f32 = try testingAllocator.alloc(f32, 15);
    defer testingAllocator.free(temporal_weights);

    var center_weight: f32 = 0;

    // Strength is greater than maxr, so all frames are equally weighted
    calculateTemporalWeights(7, 8, &temporal_weights, &center_weight);
    try std.testing.expectEqualDeep(&[15]f32{
        1.0 / 15.0, 1.0 / 15.0, 1.0 / 15.0, 1.0 / 15.0, 1.0 / 15.0, //
        1.0 / 15.0, 1.0 / 15.0, 1.0 / 15.0, 1.0 / 15.0, 1.0 / 15.0, //
        1.0 / 15.0, 1.0 / 15.0, 1.0 / 15.0, 1.0 / 15.0, 1.0 / 15.0,
    }, temporal_weights);
    try std.testing.expectEqual(1.0 / 15.0, center_weight);

    @memset(temporal_weights, 0); // clear results

    // Radius 1, diameter = 3, so weight center frame highest, and prev/next frames half of center weight.
    calculateTemporalWeights(1, 1, &temporal_weights, &center_weight);
    try std.testing.expectEqualDeep(&[15]f32{
        0.25, 0.5, 0.25, 0.0, 0.0, //
        0.0, 0.0, 0.0, 0.0, 0.0, //
        0.0, 0.0, 0.0, 0.0, 0.0, //
    }, temporal_weights);
    try std.testing.expectEqual(0.5, center_weight);

    @memset(temporal_weights, 0); // clear results

    // Sum of weights is 2.66666666 (1/3 + 1/2 + 1 + 1/2 + 1/3), so center is 1.0 / 2.666666, next frames are 0.5 / 2.66666, etc etc.
    calculateTemporalWeights(2, 1, &temporal_weights, &center_weight);
    try std.testing.expectEqualDeep(&[15]f32{
        0.125, 0.1875, 0.375, 0.1875, 0.125, //
        0.0, 0.0, 0.0, 0.0, 0.0, //
        0.0, 0.0, 0.0, 0.0, 0.0, //
    }, temporal_weights);
    try std.testing.expectEqual(0.375, center_weight);
}

// Temporal difference weights.
// Center weight is kept separate (since the difference between the center pixel and itself is always 0)
// Then temporal_difference_weights holds the weights for the surrounding frames and their differences.
// Meaning that
// temporal_difference_weights[0][...] holds the weights for the frames on either side of the source frame (-1 and +1) (prev and next)
// temporal_difference_weights[1][...] holds the weights for frames 2 steps away (-2 and +2) (2nd prev and 2nd next).
// etc.
fn calculateTemporalDifferenceWeights(threshold: u9, mdiff: u8, maxr: u8, strength: u8, _temporal_difference_weights: *[][]f32, center_weight: *f32) void {
    // Inverse pixel difference waiting.
    var temporal_difference_weights: [][]f32 = _temporal_difference_weights.*;
    var temporal_weights = [_]f32{0} ** (MAX_RADIUS + 1); // Radius + 1 (center frame)
    var difference_weights = [_]f32{0} ** 256;

    for (0..maxr + 1) |i| {
        // inverse weight frames further away from the center.
        // aka the farther a frame is from the current frame, the less impact it has on the current frame's pixel.
        temporal_weights[i] = if (i < strength) 1.0 else 1.0 / @as(f32, @floatFromInt(i - strength + 2));
    }

    const step: f32 = 256.0 / @as(f32, @floatFromInt(threshold - @min(mdiff, threshold - 1)));
    var base: f32 = 256.0;

    // Set differences between 0 and mdiff to maximum weight,
    // then reduce the weights for the differences between mdiff and threshold, where the weight at threshold is 0.
    // So weights closer to mdiff are higher and weights closer to threshold are lower.
    for (0..threshold) |diff| {
        if (diff < mdiff) {
            // Set differences less than mdiff to maximum weight;
            difference_weights[diff] = 256.0;
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

        for (0..threshold) |diff| {
            temporal_difference_weights[radius - 1][diff] = temporal_weights[radius] * difference_weights[diff] / 256.0;
        }
    }

    for (0..maxr) |radius| {
        for (0..threshold) |diff| {
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
    var temporal_difference_weights: [][]f32 = try testingAllocator.alloc([]f32, 3);
    for (0..temporal_difference_weights.len) |i| {
        temporal_difference_weights[i] = try testingAllocator.alloc(f32, 5);
        @memset(temporal_difference_weights[i], 0);
    }
    defer {
        for (0..temporal_difference_weights.len) |i| {
            testingAllocator.free(temporal_difference_weights[i]);
        }
        testingAllocator.free(temporal_difference_weights);
    }

    var center_weight: f32 = 0;

    // With threshold, mdiff, and radius of 1, center weight is 0.5,
    // the previous and next frames have a weight of 0.25 (for a total of 1.0 weight)
    calculateTemporalDifferenceWeights(1, 1, 1, 1, &temporal_difference_weights, &center_weight);
    try std.testing.expectEqual(0.25, temporal_difference_weights[0][0]);
    try std.testing.expectEqual(0, temporal_difference_weights[0][1]); // Ensure weights at threshold (1) are zero
    try std.testing.expectEqual(0, temporal_difference_weights[1][0]); // Ensure weights at next frame are 0 (not set)
    try std.testing.expectEqual(0.5, center_weight);

    // With threshold and mdiff equal (3), the difference weights are all equal,
    // and there's only a single temporal weight.
    calculateTemporalDifferenceWeights(3, 3, 1, 1, &temporal_difference_weights, &center_weight);
    try std.testing.expectEqual(0.25, temporal_difference_weights[0][0]);
    try std.testing.expectEqual(0.25, temporal_difference_weights[0][1]);
    try std.testing.expectEqual(0.25, temporal_difference_weights[0][2]);
    try std.testing.expectEqual(0, temporal_difference_weights[0][3]); // Ensure weights at threshold (3) are zero
    try std.testing.expectEqual(0, temporal_difference_weights[1][0]); // Ensure weights at next frame are 0 (not set)
    try std.testing.expectEqual(0.5, center_weight);

    // With threshold 5 and mdiff 2, maximum weight is assigned to the first 3 (0,1,2) differences, with a reducing scale
    // between mdiff and threshold.
    calculateTemporalDifferenceWeights(5, 2, 1, 1, &temporal_difference_weights, &center_weight);
    try std.testing.expectEqual(0.25, temporal_difference_weights[0][0]);
    try std.testing.expectEqual(0.25, temporal_difference_weights[0][1]);
    try std.testing.expectEqual(0.25, temporal_difference_weights[0][2]); //mdiff = 2
    try std.testing.expectEqual(0.16666666, temporal_difference_weights[0][3]);
    try std.testing.expectEqual(0.08333332, temporal_difference_weights[0][4]);
    try std.testing.expectEqual(0, temporal_difference_weights[1][0]); // Ensure weights at next frame are 0 (not set)
    try std.testing.expectEqual(0.5, center_weight);

    @memset(temporal_difference_weights[0], 0); // clear weights

    // With strength greater than maxr, all frames are given an equal weight.
    // With maxr = 3, that's 7 total frames (3 + 1 (center) + 3), so weight is 1.0 / 7.0
    calculateTemporalDifferenceWeights(1, 1, 3, 4, &temporal_difference_weights, &center_weight);
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
    calculateTemporalDifferenceWeights(1, 1, 3, 1, &temporal_difference_weights, &center_weight);
    try std.testing.expectEqual(1.0 / 2.0 / 3.16666666666666666666, temporal_difference_weights[0][0]); // next frame
    try std.testing.expectEqual(1.0 / 3.0 / 3.16666666666666666666, temporal_difference_weights[1][0]); // next next frame
    try std.testing.expectEqual(1.0 / 4.0 / 3.16666666666666666666, temporal_difference_weights[2][0]); // next next next frame
    try std.testing.expectEqual(1.0 / 3.16666666666666666666, center_weight);
}

export fn ttempSmoothCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    var d: TTempSmoothData = undefined;
    // var err: vs.MapPropertyError = undefined;

    const zapi = ZAPI.init(vsapi, core);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);

    d.node, d.vi = inz.getNodeVi("clip").?;

    if (!vsh.isConstantVideoFormat(d.vi)) {
        vsapi.?.mapSetError.?(out, "TTempSmooth: only constant format input supported");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    d.maxr = inz.getInt(u8, "maxr") orelse 3;

    if ((d.maxr < 1) or (d.maxr > MAX_RADIUS)) {
        outz.setError("TTempSmooth: maxr must be between 1 and 7 (inclusive)");
        zapi.freeNode(d.node);
        return;
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
                if (thresh < 1 or thresh > 256) {
                    zapi.freeNode(d.node);
                    outz.setError("TTempSmooth: thresh must be between 1 and 256");
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
                    outz.setError("TTempSmooth: mdiff must be between 0 and 255");
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
        outz.setError("TTempSmooth: strength must be between 1 and 8 (inclusive)");
    }

    for (0..3) |plane| {
        if (!d.process[plane]) {
            continue;
        }

        if (d.threshold[plane] > mdiff[plane] + 1) {
            d.weight_mode = .inverse_difference;

            // Dynamically allocate the slice of slices for the given plane.
            // Aka a slice for each frame, containing the lookup table of weights;
            d.temporal_difference_weights[plane] = allocator.alloc([]f32, d.maxr + 1) catch unreachable;
            for (0..d.temporal_difference_weights[plane].len) |i| {
                d.temporal_difference_weights[plane][i] = allocator.alloc(f32, d.threshold[plane]) catch unreachable;
            }

            calculateTemporalDifferenceWeights(d.threshold[plane], mdiff[plane], d.maxr, strength, &d.temporal_difference_weights[plane], &d.center_weight[plane]);
        } else {
            d.weight_mode = .temporal;
            const diameter = d.maxr * 2 + 1;

            // TODO: Temporal_weights contains the full diameter of frames, but that's unnecessary
            // duplication of data, since the weights are the same for frames on either side of the center.
            // Essentially, do the same thing as temporal_difference_weights.
            d.temporal_weights[plane] = allocator.alloc(f32, diameter) catch unreachable;
            calculateTemporalWeights(d.maxr, strength, &d.temporal_weights[plane], &d.center_weight[plane]);
        }
    }

    d.pfclip = inz.getNode("pfclip");
    if (d.pfclip != null) {
        const pfclipvi = zapi.getVideoInfo(d.pfclip);

        if (!vsh.isSameVideoFormat(&d.vi.format, &pfclipvi.format)) {
            zapi.freeNode(d.node);
            zapi.freeNode(d.pfclip);
            outz.setError("pfclip must have same format and dimensions as the main clip");
        }
    }

    const data: *TTempSmoothData = allocator.create(TTempSmoothData) catch unreachable;
    data.* = d;

    //TODO: Add pfclip support.
    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.General,
        },
    };

    const getFrame = switch (d.vi.format.bytesPerSample) {
        1 => &TTempSmooth(u8).getFrame,
        // Math.pow doesn't support f16 yet, so have to disable f16 support for the short term until the following is addressed:
        // * https://github.com/ziglang/zig/issues/23602
        // * https://github.com/ziglang/zig/pull/23631
        // 2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &TTempSmooth(u16).getFrame else &TTempSmooth(f16).getFrame,
        2 => &TTempSmooth(u16).getFrame,
        4 => &TTempSmooth(f32).getFrame,
        else => unreachable,
    };

    vsapi.?.createVideoFilter.?(out, "TTempSmooth", d.vi, getFrame, ttempSmoothFree, fm.Parallel, &deps, deps.len, data, core);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("TTempSmooth", "clip:vnode;maxr:int:opt;thresh:int[]:opt;mdiff:int[]:opt;strength:int:opt;scthresh:float:opt;fp:int:opt;pfclip:vnode:opt;planes:int[]:opt;", "clip:vnode;", ttempSmoothCreate, null, plugin);
}
