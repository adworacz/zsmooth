const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;

const math = @import("common/math.zig");
const vscmn = @import("common/vapoursynth.zig");
const vec = @import("common/vector.zig");
const sort = @import("common/sorting_networks.zig");
const string = @import("common/string.zig");

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

    // TODO: Support per-plane settings for these values.
    maxr: u8, //Temporal radius
    threshold: [3]u16, // threshold in 8-bit scale (max is 256, thus the use of u16). Scaled in getFrame to pertinent format.
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
    const vec_size = vec.getVecSize(T);
    const VecType = @Vector(vec_size, T);

    return struct {
        fn processPlaneScalar(comptime diameter: u8, srcp: [][]const T, dstp: []T, width: usize, height: usize, stride: usize) void {
            var temp: [diameter]T = undefined;

            for (0..height) |row| {
                for (0..width) |column| {
                    const current_pixel = row * stride + column;

                    for (0..@intCast(diameter)) |i| {
                        temp[i] = srcp[i][current_pixel];
                    }

                    // 60fps with radius 1
                    // 7 fps with radius 10
                    std.mem.sortUnstable(T, temp[0..diameter], {}, comptime std.sort.asc(T));

                    dstp[current_pixel] = temp[diameter / 2];
                }
            }
        }

        fn processPlaneVector(comptime diameter: u8, srcp: [][]const T, dstp: []T, width: usize, height: usize, stride: usize) void {
            const width_simd = width / vec_size * vec_size;

            for (0..height) |row| {
                var column: usize = 0;
                while (column < width_simd) : (column += vec_size) {
                    const offset = row * stride + column;
                    medianVector(diameter, srcp, dstp, offset);
                }

                // If the video width is not perfectly aligned with the vector width, do one
                // last operation at the end of the plane to cover what's leftover from the loop above.
                if (width_simd < width) {
                    medianVector(diameter, srcp, dstp, (row * stride) + width - vec_size);
                }
            }
        }

        test "processPlane should find the median value" {
            const height = 2;
            const width = vec_size + 24;
            const stride = width + 8 + vec_size;
            const size = height * stride;

            const radius = 4;
            const diameter = radius * 2 + 1;
            const expectedMedian = ([_]T{radius + 1} ** size)[0..];

            var src: [diameter][]const T = undefined;
            for (0..diameter) |i| {
                const frame = try testingAllocator.alloc(T, size);
                @memset(frame, math.lossyCast(T, i + 1));

                src[i] = frame;
            }
            defer {
                for (0..diameter) |i| {
                    testingAllocator.free(src[i]);
                }
            }

            const dstp_scalar = try testingAllocator.alloc(T, size);
            const dstp_vec = try testingAllocator.alloc(T, size);
            defer testingAllocator.free(dstp_scalar);
            defer testingAllocator.free(dstp_vec);

            processPlaneScalar(diameter, &src, dstp_scalar, width, height, stride);
            processPlaneVector(diameter, &src, dstp_vec, width, height, stride);

            for (0..height) |row| {
                const start = row * stride;
                const end = start + width;
                try testing.expectEqualDeep(expectedMedian[start..end], dstp_scalar[start..end]);
                try testing.expectEqualDeep(expectedMedian[start..end], dstp_vec[start..end]);
            }
        }

        fn medianVector(comptime diameter: u8, srcp: [][]const T, dstp: []T, offset: usize) void {
            var src: [diameter]VecType = undefined;

            for (0..diameter) |r| {
                src[r] = vec.load(VecType, srcp[r], offset);
            }

            const result: VecType = switch (diameter) {
                3 => sort.median(VecType, 3, src[0..3]),
                5 => sort.median(VecType, 5, src[0..5]),
                7 => sort.median(VecType, 7, src[0..7]),
                9 => sort.median(VecType, 9, src[0..9]),
                11 => sort.median(VecType, 11, src[0..11]),
                13 => sort.median(VecType, 13, src[0..13]),
                15 => sort.median(VecType, 15, src[0..15]),
                17 => sort.median(VecType, 17, src[0..17]),
                19 => sort.median(VecType, 19, src[0..19]),
                21 => sort.median(VecType, 21, src[0..21]),
                else => unreachable,
            };

            // Store
            vec.store(VecType, dstp, offset, result);
        }

        pub fn getFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
            // Assign frame_data to nothing to stop compiler complaints
            _ = frame_data;

            const d: *TTempSmoothData = @ptrCast(@alignCast(instance_data));

            if (activation_reason == ar.Initial) {
                // if (n < d.radius or n > d.vi.numFrames - 1 - d.radius) {
                vsapi.?.requestFrameFilter.?(n, d.node, frame_ctx);
                // } else {
                //     // Request previous, current, and next frames, based on the filter radius.
                //     var i = -d.radius;
                //     while (i <= d.radius) : (i += 1) {
                //         vsapi.?.requestFrameFilter.?(n + i, d.node, frame_ctx);
                //     }
                // }
            } else if (activation_reason == ar.AllFramesReady) {
                // // Skip filtering on the first and last frames that lie inside the filter radius,
                // // since we do not have enough information to filter them properly.
                // if (n < d.radius or n > d.vi.numFrames - 1 - d.radius) {
                //     return vsapi.?.getFrameFilter.?(n, d.node, frame_ctx);
                // }
                //
                // const diameter: u8 = @intCast(d.radius * 2 + 1);
                // var src_frames: [MAX_DIAMETER]?*const vs.Frame = undefined;
                //
                // // Retrieve all source frames within the filter radius.
                // {
                //     var i = -d.radius;
                //     while (i <= d.radius) : (i += 1) {
                //         src_frames[@intCast(d.radius + i)] = vsapi.?.getFrameFilter.?(n + i, d.node, frame_ctx);
                //     }
                // }
                // defer for (0..diameter) |i| vsapi.?.freeFrame.?(src_frames[i]);
                //
                // const dst = vscmn.newVideoFrame(&d.process, src_frames[@intCast(d.radius)], d.vi, core, vsapi);
                //
                // var plane: c_int = 0;
                // while (plane < d.vi.format.numPlanes) : (plane += 1) {
                //     // Skip planes we aren't supposed to process
                //     if (!d.process[@intCast(plane)]) {
                //         continue;
                //     }
                //
                //     const width: usize = @intCast(vsapi.?.getFrameWidth.?(dst, plane));
                //     const height: usize = @intCast(vsapi.?.getFrameHeight.?(dst, plane));
                //     const stride: usize = @as(usize, @intCast(vsapi.?.getStride.?(dst, plane))) / @sizeOf(T);
                //
                //     var srcp: [MAX_DIAMETER][]const T = undefined;
                //     for (0..diameter) |i| {
                //         srcp[i] = @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[i], plane))))[0..(height * stride)];
                //     }
                //     const dstp: []T = @as([*]T, @ptrCast(@alignCast(vsapi.?.getWritePtr.?(dst, plane))))[0..(height * stride)];
                //
                //     switch (d.radius) {
                //         inline 1...MAX_RADIUS => |r| processPlaneVector((r * 2 + 1), srcp[0..(r * 2 + 1)], dstp, width, height, stride),
                //         else => unreachable,
                //     }
                // }

                // return dst;
                _ = core;
                return null;
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
fn calculateTemporalDifferenceWeights(threshold: u16, mdiff: u16, maxr: u8, strength: u8, _temporal_difference_weights: *[][]f32, center_weight: *f32) void {
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
    var temporal_difference_weights: [][]f32 = try testingAllocator.alloc([]f32, 15);
    for (0..temporal_difference_weights.len) |i| {
        temporal_difference_weights[i] = try testingAllocator.alloc(f32, 5 + 1); // max threshold we use is 5, so add one to ensure we can check that values beyond said threshold are zero.
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
    try std.testing.expectEqual(0, temporal_difference_weights[0][5]); // Ensure weights at threshold (5) are zero
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
    try std.testing.expectEqual(0, temporal_difference_weights[3][0]); // Ensure weights at beyond radius are zero
    try std.testing.expectEqual(1.0 / 7.0, center_weight); //even center frame gets the same weight, due to strength being greater than maxr.

    // Strength is less than maxr, so weights scale inversely the farther they are from center.
    // Temporal weights are 1, 1/2, 1/3, 1/4, which with non-center weights
    // doubled in sum is 1, 1, 2/3, 1/2, which sums to 3.16666666666666666666
    calculateTemporalDifferenceWeights(1, 1, 3, 1, &temporal_difference_weights, &center_weight);
    try std.testing.expectEqual(1.0 / 2.0 / 3.16666666666666666666, temporal_difference_weights[0][0]); // next frame
    try std.testing.expectEqual(1.0 / 3.0 / 3.16666666666666666666, temporal_difference_weights[1][0]); // next next frame
    try std.testing.expectEqual(1.0 / 4.0 / 3.16666666666666666666, temporal_difference_weights[2][0]); // next next next frame
    try std.testing.expectEqual(0, temporal_difference_weights[3][0]); // Ensure weights at beyond radius are zero
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
        d.threshold = .{ 4.0, 5.0, 5.0 };
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

    var mdiff: [3]u16 = undefined;

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

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.General,
        },
    };

    const getFrame = switch (d.vi.format.bytesPerSample) {
        1 => &TTempSmooth(u8).getFrame,
        2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &TTempSmooth(u16).getFrame else &TTempSmooth(f16).getFrame,
        4 => &TTempSmooth(f32).getFrame,
        else => unreachable,
    };

    vsapi.?.createVideoFilter.?(out, "TTempSmooth", d.vi, getFrame, ttempSmoothFree, fm.Parallel, &deps, deps.len, data, core);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("TTempSmooth", "clip:vnode;maxr:int:opt;thresh:int[]:opt;mdiff:int[]:opt;strength:int:opt;scthresh:float:opt;fp:int:opt;pfclip:vnode:opt;planes:int[]:opt;scalep:int:opt;", "clip:vnode;", ttempSmoothCreate, null, plugin);
}
