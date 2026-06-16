const std = @import("std");
const vapoursynth = @import("vapoursynth");
const ZAPI = vapoursynth.ZAPI;
const testing = @import("std").testing;

const vscmn = @import("common/vapoursynth.zig");
const vec = @import("common/vector.zig");
const math = @import("common/math.zig");
const types = @import("common/type.zig");

const float_mode: std.builtin.FloatMode = if (@import("config").optimize_float) .optimized else .strict;

const vs = vapoursynth.vapoursynth4;
const vsh = vapoursynth.vshelper;

const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;

const allocator = std.heap.c_allocator;

// Align LUTs to a reasonable cache size.
// Maybe change this for Mac targets, which have larger cache sizes...
const LUT_ALIGN = 64;
const MAX_RADIUS = 10;
const MAX_DIAMETER = MAX_RADIUS * 2 + 1;
const MAX_DIAMETER_PLANES = MAX_DIAMETER * 3;

const TemporalMode = enum {
    inv_diff, //Simple temporal inverse difference weighting
    cnr2_no_src, // More temporally stable than .cnr2, albeit with more artifacts
    cnr2, // More detail retention than .cnr2_no_src, and less artifacts, with less denoising / more temporal instability.
    cnr2_dynamic_no_src, // Same as .cnr2_no_src, but using a dynamic radius (slow)
    cnr2_dynamic, // Same as .cnr2, but using dynamimc radius (slow)

    const Self = @This();

    /// Whether or not we include the center in the
    /// source frames.
    fn srcIncludesCenter(self: Self) bool {
        return switch (self) {
            .inv_diff => false,
            .cnr2_no_src, .cnr2 => true,
            .cnr2_dynamic_no_src, .cnr2_dynamic => true,
        };
    }

    /// Needs scratch frames for processing.
    fn needsScratchFrames(self: Self) bool {
        return switch (self) {
            .inv_diff => false,
            .cnr2_no_src, .cnr2 => true,
            .cnr2_dynamic_no_src, .cnr2_dynamic => true,
        };
    }

    /// Whether or not to update src frames when backcalculating.
    /// Ref frames are always updated.
    fn shouldUpdateSrc(self: Self) bool {
        return (self == .cnr2 or self == .cnr2_dynamic);
    }
};

const WeightMode = enum {
    original, // The original weighting behavior of Cnr2
    weight_abs_diff, // much better detail retention, albeit less temporal smoothing
    total_weight_div, // even better detail retention, but barely denoises.
    both, // combo of above, lightest overall effect.

    const Self = @This();

    fn processAbsDiff(self: Self) bool {
        return self == .weight_abs_diff or self == .both;
    }

    fn processWeights(self: Self) bool {
        return self == .total_weight_div or self == .both;
    }
};

const Cnr4Data = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    node_ref: ?*vs.Node,
    node_luma: ?*vs.Node,
    node_ref_luma: ?*vs.Node,

    vi: *const vs.VideoInfo,

    tmode: TemporalMode,
    wmode: WeightMode,
    radius: u8,

    table_y: []align(LUT_ALIGN) u8,
    table_u: []align(LUT_ALIGN) u8,
    table_v: []align(LUT_ALIGN) u8,

    scenechange: bool,
};

fn Cnr4(comptime T: type) type {
    const UAT = types.UnsignedArithmeticType(T);
    const BUAT = types.BigUnsignedArithmeticType(T);

    return struct {
        // Calculates weights for the temporal neighbors
        // Calculation is slightly tricky since the array we operate
        // on does *not* include the center frame.
        fn calculateTemporalWeights(radius: comptime_int) [radius * 2]T {
            var weights: [radius * 2]T = undefined;

            for (0..radius * 2) |i| {
                // Weight frames further away more heavily.
                weights[i] = @intCast(if (i < radius) radius - i + 1 else i - radius + 2);
            }

            return weights;
        }

        test calculateTemporalWeights {
            try std.testing.expectEqualDeep(.{ 3, 2, 2, 3 }, calculateTemporalWeights(2));
            try std.testing.expectEqualDeep(.{ 4, 3, 2, 2, 3, 4 }, calculateTemporalWeights(3));
            try std.testing.expectEqualDeep(.{ 5, 4, 3, 2, 2, 3, 4, 5 }, calculateTemporalWeights(4));
        }

        const ProcessOpts = struct {
            wmode: WeightMode,

            depth: u6,

            width_y: usize,
            height_y: usize,
            width_uv: usize,
            height_uv: usize,

            stride_y: usize,
            stride_uv: usize,

            subsampling_h: u2,
            subsampling_w: u2,
        };

        fn processFrameScalar(radius: comptime_int, curr: [3][]const T, curr_ref: [3][]const T, src: []const [3][]const T, ref: []const [3][]const T, noalias dst_u: []T, noalias dst_v: []T, tables: [3][]align(LUT_ALIGN) const u8, opt: ProcessOpts) void {
            const curr_u = curr[1];
            const curr_v = curr[2];

            const curr_ref_y = curr_ref[0];
            const curr_ref_u = curr_ref[1];
            const curr_ref_v = curr_ref[2];

            const table_y = tables[0];
            const table_u = tables[1];
            const table_v = tables[2];

            const abs_diff_weights: [radius * 2]T = if (opt.wmode.processAbsDiff()) calculateTemporalWeights(radius) else @splat(1);

            // Division by reciprocal multiplication.
            // Shifting depends on integer sizes, not bit depth of input,
            // because it's focused on calculation accuracy.
            const mul_shift = @bitSizeOf(BUAT) / 2;
            const round_mul_shift = 1 << (mul_shift - 1);
            var weight_multipliers: [radius * 2]BUAT = @splat(1 << mul_shift);

            if (opt.wmode.processWeights()) {
                const weights = calculateTemporalWeights(radius);
                for (&weight_multipliers, weights) |*wm, weight| {
                    wm.* = wm.* / weight;
                }
            }

            var results_u: [radius * 2]UAT = @splat(0);
            var results_v: [radius * 2]UAT = @splat(0);
            var abs_diffs_yu: [radius * 2]UAT = @splat(0);
            var abs_diffs_yv: [radius * 2]UAT = @splat(0);

            const shift = opt.depth << 1;
            const weight_shift = (opt.depth - 8) * 2;
            const max = @as(BUAT, 1) << @intCast(shift);
            const round = max / 2;

            const divisor = @as(BUAT, max) * (radius * 2);
            const round2 = divisor / 2;

            for (0..opt.height_uv) |y| {
                for (0..opt.width_uv) |x| {
                    const y_index = y * opt.stride_y + x;
                    const uv_index = y * opt.stride_uv + x;

                    for (0..radius * 2, src, ref, abs_diff_weights, weight_multipliers) |i, other, other_ref, aweight, wmul| {
                        const other_u = other[1];
                        const other_v = other[2];

                        const other_ref_y = other_ref[0];
                        const other_ref_u = other_ref[1];
                        const other_ref_v = other_ref[2];

                        const abs_diff_y = math.absDiff(curr_ref_y[y_index], other_ref_y[y_index]);
                        const abs_diff_u = math.absDiff(curr_ref_u[uv_index], other_ref_u[uv_index]);
                        const abs_diff_v = math.absDiff(curr_ref_v[uv_index], other_ref_v[uv_index]);

                        const table_idx_y: usize = switch (T) {
                            u8 => abs_diff_y,
                            u16 => abs_diff_y >> @intCast(opt.depth - 8),
                            else => @trunc(@min(abs_diff_y, 1.0) * 255.0),
                        };
                        const table_idx_u: usize = switch (T) {
                            u8 => abs_diff_u,
                            u16 => abs_diff_u >> @intCast(opt.depth - 8),
                            else => @trunc(@min(abs_diff_u, 1.0) * 255.0),
                        };
                        const table_idx_v: usize = switch (T) {
                            u8 => abs_diff_v,
                            u16 => abs_diff_v >> @intCast(opt.depth - 8),
                            else => @trunc(@min(abs_diff_v, 1.0) * 255.0),
                        };

                        // Increase the weight of temporally distant neighbors
                        // Avoids (some) artifacts (also can create a few)
                        // and increases detail retention, with some denoising reduction.
                        const weighted_table_idx_y = @min(table_idx_y * aweight, 255);
                        const weighted_table_idx_u = @min(table_idx_u * aweight, 255);
                        const weighted_table_idx_v = @min(table_idx_v * aweight, 255);

                        var weight_u: BUAT = (@as(UAT, table_y[weighted_table_idx_y]) * table_u[weighted_table_idx_u]) << @intCast(weight_shift);
                        var weight_v: BUAT = (@as(UAT, table_y[weighted_table_idx_y]) * table_v[weighted_table_idx_v]) << @intCast(weight_shift);

                        weight_u = (weight_u * wmul + round_mul_shift) >> mul_shift;
                        weight_v = (weight_v * wmul + round_mul_shift) >> mul_shift;

                        const result_u = ((weight_u * other_u[uv_index] + (max - weight_u) * curr_u[uv_index] + round) >> @intCast(shift));
                        const result_v = ((weight_v * other_v[uv_index] + (max - weight_v) * curr_v[uv_index] + round) >> @intCast(shift));

                        results_u[i] = @intCast(result_u);
                        results_v[i] = @intCast(result_v);
                        abs_diffs_yu[i] = @as(UAT, abs_diff_y) + abs_diff_u;
                        abs_diffs_yv[i] = @as(UAT, abs_diff_y) + abs_diff_v;
                    }

                    // Inverse weight the results so that results derived
                    // from large difference frames have a lower weight, and vice versa.
                    var result_u: BUAT = 0;
                    var result_v: BUAT = 0;

                    for (0..radius * 2) |i| {
                        result_u += (max - abs_diffs_yu[i]) * results_u[i];
                        result_v += (max - abs_diffs_yv[i]) * results_v[i];
                    }

                    dst_u[uv_index] = @intCast((result_u + round2) / divisor);
                    dst_v[uv_index] = @intCast((result_v + round2) / divisor);
                }
            }
        }

        // Use separate dstp pointers so we can use `noalias`,
        // which leads to a *substantial speedup*: ~290fps -> 513 fps
        fn processFrame(curr8: [3][]const u8, curr_ref8: [3][]const u8, src8: []const [3][]const u8, ref8: []const [3][]const u8, noalias dst8_u: []u8, noalias dst8_v: []u8, scratch: [4][]u8, tables: [3][]align(LUT_ALIGN) const u8, opt: struct {
            tmode: TemporalMode,
            wmode: WeightMode,
            radius: u8,

            depth: u6,

            width_y: usize,
            height_y: usize,
            width_uv: usize,
            height_uv: usize,

            stride_y: usize,
            stride_uv: usize,

            subsampling_h: u2,
            subsampling_w: u2,
        }) void {
            const curr: [3][]const T = .{
                @ptrCast(@alignCast(curr8[0])),
                @ptrCast(@alignCast(curr8[1])),
                @ptrCast(@alignCast(curr8[2])),
            };

            const curr_ref: [3][]const T = .{
                @ptrCast(@alignCast(curr_ref8[0])),
                @ptrCast(@alignCast(curr_ref8[1])),
                @ptrCast(@alignCast(curr_ref8[2])),
            };

            const src: []const [3][]const T = @ptrCast(@alignCast(src8));
            const ref: []const [3][]const T = @ptrCast(@alignCast(ref8));

            const dst_u: []T = @ptrCast(@alignCast(dst8_u));
            const dst_v: []T = @ptrCast(@alignCast(dst8_v));

            const opts: ProcessOpts = .{
                .wmode = opt.wmode,

                .depth = opt.depth,

                .width_y = opt.width_y,
                .height_y = opt.height_y,
                .width_uv = opt.width_uv,
                .height_uv = opt.height_uv,

                .stride_y = opt.stride_uv / @sizeOf(T),
                .stride_uv = opt.stride_uv / @sizeOf(T),

                .subsampling_h = opt.subsampling_h,
                .subsampling_w = opt.subsampling_w,
            };

            if (opt.tmode == .inv_diff) {
                // Inverse difference weight
                switch (opt.radius) {
                    inline 1...MAX_RADIUS => |r| processFrameScalar(r, curr, curr_ref, src, ref, dst_u, dst_v, tables, opts),
                    else => unreachable,
                }
            } else {
                //CNR2

                // Create mutable slice so we can swap in filtered frames as we go.
                const srcs: [][3][]const T = @constCast(src);
                const refs: [][3][]const T = @constCast(ref);
                const left_u: []T = @ptrCast(@alignCast(scratch[0]));
                const left_v: []T = @ptrCast(@alignCast(scratch[1]));
                const right_u: []T = @ptrCast(@alignCast(scratch[2]));
                const right_v: []T = @ptrCast(@alignCast(scratch[3]));

                var tmp_srcs: [MAX_RADIUS * 2][3][]const T = undefined;
                var tmp_refs: [MAX_RADIUS * 2][3][]const T = undefined;
                var tmp_count: usize = 0;

                for (1..opt.radius) |i| {
                    const l_idx = i;
                    const r_idx = srcs.len - 1 - i;
                    const radius = @min(opt.radius, l_idx);

                    // Left frames
                    if (opt.tmode == .cnr2 or opt.tmode == .cnr2_no_src) {
                        // Radius 1 backcalculating
                        processFrameScalar(1, srcs[l_idx], refs[l_idx], &.{ srcs[l_idx - 1], srcs[l_idx + 1] }, &.{ refs[l_idx - 1], refs[l_idx + 1] }, left_u, left_v, tables, opts);
                    } else {
                        // Dyanmic radius backcalculating
                        tmp_count = 0;
                        for (0..radius) |j| {
                            // past frames
                            tmp_srcs[tmp_count] = srcs[l_idx - radius + j];
                            tmp_refs[tmp_count] = refs[l_idx - radius + j];

                            //future frames
                            tmp_srcs[radius * 2 - 1 - tmp_count] = srcs[l_idx + radius - j];
                            tmp_refs[radius * 2 - 1 - tmp_count] = refs[l_idx + radius - j];

                            tmp_count += 1;
                        }

                        switch (radius) {
                            inline 1...MAX_RADIUS => |r| processFrameScalar(r, srcs[l_idx], refs[l_idx], tmp_srcs[0 .. radius * 2], tmp_refs[0 .. radius * 2], left_u, left_v, tables, opts),
                            else => unreachable,
                        }
                    }
                    srcs[l_idx] = .{
                        srcs[l_idx][0],
                        if (opt.tmode.shouldUpdateSrc()) left_u else srcs[l_idx][1],
                        if (opt.tmode.shouldUpdateSrc()) left_v else srcs[l_idx][2],
                    };
                    refs[l_idx] = .{
                        refs[l_idx][0],
                        left_u,
                        left_v,
                    };

                    // Right frames
                    if (opt.tmode == .cnr2 or opt.tmode == .cnr2_no_src) {
                        // Radius 1 backcalculating
                        processFrameScalar(1, srcs[r_idx], refs[r_idx], &.{ srcs[r_idx - 1], srcs[r_idx + 1] }, &.{ refs[r_idx - 1], refs[r_idx + 1] }, right_u, right_v, tables, opts);
                    } else {
                        // Dyanmic radius backcalculating
                        tmp_count = 0;
                        for (0..radius) |j| {
                            // past frames
                            tmp_srcs[tmp_count] = srcs[r_idx - radius + j];
                            tmp_refs[tmp_count] = refs[r_idx - radius + j];

                            //future frames
                            tmp_srcs[radius * 2 - 1 - tmp_count] = srcs[r_idx + radius - j];
                            tmp_refs[radius * 2 - 1 - tmp_count] = refs[r_idx + radius - j];

                            tmp_count += 1;
                        }
                        switch (radius) {
                            inline 1...MAX_RADIUS => |r| processFrameScalar(r, srcs[r_idx], refs[r_idx], tmp_srcs[0 .. radius * 2], tmp_refs[0 .. radius * 2], right_u, right_v, tables, opts),
                            else => unreachable,
                        }
                    }
                    srcs[r_idx] = .{
                        srcs[r_idx][0],
                        if (opt.tmode.shouldUpdateSrc()) right_u else srcs[r_idx][1],
                        if (opt.tmode.shouldUpdateSrc()) right_v else srcs[r_idx][2],
                    };
                    refs[r_idx] = .{
                        refs[r_idx][0],
                        right_u,
                        right_v,
                    };
                }

                //combine the results for the current frame.
                tmp_count = 0;
                for (0..opt.radius) |j| {
                    // past frames
                    tmp_srcs[tmp_count] = srcs[j];
                    tmp_refs[tmp_count] = refs[j];

                    //future frames
                    tmp_srcs[opt.radius * 2 - 1 - tmp_count] = srcs[srcs.len - 1 - j];
                    tmp_refs[opt.radius * 2 - 1 - tmp_count] = refs[refs.len - 1 - j];

                    tmp_count += 1;
                }

                switch (opt.radius) {
                    inline 1...MAX_RADIUS => |r| processFrameScalar(r, curr, curr_ref, tmp_srcs[0 .. opt.radius * 2], tmp_refs[0 .. opt.radius * 2], dst_u, dst_v, tables, opts),
                    else => unreachable,
                }
            }
        }
    };
}

fn cnr4GetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const zapi = ZAPI.init(vsapi, core, frame_ctx);
    const d: *Cnr4Data = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        var i: i8 = -@as(i8, @intCast(d.radius));
        while (i <= d.radius) : (i += 1) {
            zapi.requestFrameFilter(std.math.clamp(n + i, 0, d.vi.numFrames - 1), d.node);
            zapi.requestFrameFilter(std.math.clamp(n + i, 0, d.vi.numFrames - 1), d.node_luma);
            if (d.node_ref) |_| {
                zapi.requestFrameFilter(std.math.clamp(n + i, 0, d.vi.numFrames - 1), d.node_ref);
                zapi.requestFrameFilter(std.math.clamp(n + i, 0, d.vi.numFrames - 1), d.node_ref_luma);
            }
        }
    } else if (activation_reason == ar.AllFramesReady) {
        var src_frames: [MAX_DIAMETER]ZAPI.ZFrame(*const vs.Frame) = undefined;
        var luma_frames: [MAX_DIAMETER]ZAPI.ZFrame(*const vs.Frame) = undefined;
        var ref_frames: [MAX_DIAMETER]ZAPI.ZFrame(*const vs.Frame) = undefined;
        var ref_luma_frames: [MAX_DIAMETER]ZAPI.ZFrame(*const vs.Frame) = undefined;
        var frame_count: u8 = 0;

        {
            var i: i8 = -@as(i8, @intCast(d.radius));
            while (i <= d.radius) : (i += 1) {
                if (!d.tmode.srcIncludesCenter() and i == 0) {
                    //Grab all frames *except* the current frame, which we retrieve separately later.
                    //.cnr2 mode needs all frames
                    continue;
                }
                src_frames[frame_count] = zapi.initZFrame(d.node, std.math.clamp(n + i, 0, d.vi.numFrames - 1));
                luma_frames[frame_count] = zapi.initZFrame(d.node_luma, std.math.clamp(n + i, 0, d.vi.numFrames - 1));
                if (d.node_ref) |_| {
                    ref_frames[frame_count] = zapi.initZFrame(d.node_ref, std.math.clamp(n + i, 0, d.vi.numFrames - 1));
                    ref_luma_frames[frame_count] = zapi.initZFrame(d.node_ref_luma, std.math.clamp(n + i, 0, d.vi.numFrames - 1));
                }
                frame_count += 1;
            }
        }

        // Cleanup
        defer for (0..frame_count) |i| {
            src_frames[i].deinit();
            luma_frames[i].deinit();
            if (d.node_ref) |_| {
                ref_frames[i].deinit();
                ref_luma_frames[i].deinit();
            }
        };

        const curr = zapi.initZFrame(d.node, n);
        const curr_luma = zapi.initZFrame(d.node_luma, n);
        defer curr.deinit();
        defer curr_luma.deinit();

        const curr_ref = if (d.node_ref) |_| zapi.initZFrame(d.node_ref, n) else curr.addFrameRef();
        const curr_ref_luma = if (d.node_ref) |_| zapi.initZFrame(d.node_ref_luma, n) else curr_luma.addFrameRef();
        defer curr_ref.deinit();
        defer curr_ref_luma.deinit();

        // copy the luma plane only
        const dst = curr.newVideoFrame2(.{ false, true, true });

        var start_idx: usize = 0;
        var end_idx: usize = frame_count - 1;

        if (d.scenechange) {
            // Quick check to ensure that the scenechange properties are present.
            const props = src_frames[0].getPropertiesRO();
            if (props.getSceneChangePrev() == null or props.getSceneChangeNext() == null) {
                zapi.setFilterError("Cnr4: Scene change handling enabled, but input frame is missing scene change properties. " ++
                    "Either set scenechange=False or run scene change detection on your input clip.");
                dst.deinit();
                return null;
            }

            // Start in the left (prev) and walk backwards
            {
                var i = if (d.tmode.srcIncludesCenter()) frame_count / 2 else frame_count / 2 - 1;
                while (i > 0) : (i -= 1) {
                    if (src_frames[i].getPropertiesRO().getSceneChangePrev() == true) {
                        start_idx = i;
                        break;
                    }
                }
            }

            //Start in the right (next) and walk forwards
            {
                var i = frame_count / 2;
                while (i < frame_count - 1) : (i += 1) {
                    if (src_frames[i].getPropertiesRO().getSceneChangeNext() == true) {
                        end_idx = i;
                        break;
                    }
                }
            }

            if (!d.tmode.srcIncludesCenter()) {
                // Process current frame separately in inv_diff mode since
                // the current frame isn't in the src_frames array.
                if (curr.getPropertiesRO().getSceneChangePrev() == true) {
                    start_idx = frame_count / 2;
                }
                if (curr.getPropertiesRO().getSceneChangeNext() == true) {
                    end_idx = frame_count / 2 - 1;
                }
            }
        }

        // Replace unusable frames with center frame.
        // Using the center frame instead of frames on either end (start_idx or end_idx)
        // produces less ghosting artifacts on scene changes in my tests.
        // They are still there, but much less offensive.
        for (0..start_idx) |i| {
            src_frames[i].deinit();
            luma_frames[i].deinit();
            if (d.node_ref) |_| {
                ref_frames[i].deinit();
                ref_luma_frames[i].deinit();
            }

            src_frames[i] = curr.addFrameRef();
            luma_frames[i] = curr_luma.addFrameRef();
            if (d.node_ref) |_| {
                ref_frames[i] = curr_ref.addFrameRef();
                ref_luma_frames[i] = curr_ref_luma.addFrameRef();
            }
        }
        for (end_idx + 1..frame_count) |i| {
            src_frames[i].deinit();
            luma_frames[i].deinit();
            if (d.node_ref) |_| {
                ref_frames[i].deinit();
                ref_luma_frames[i].deinit();
            }

            src_frames[i] = curr.addFrameRef();
            luma_frames[i] = curr_luma.addFrameRef();
            if (d.node_ref) |_| {
                ref_frames[i] = curr_ref.addFrameRef();
                ref_luma_frames[i] = curr_ref_luma.addFrameRef();
            }
        }

        // Get read slices and setup scratch buffers.
        var src_planes: [MAX_DIAMETER][3][]const u8 = undefined;
        var ref_planes: [MAX_DIAMETER][3][]const u8 = undefined;
        for (0..frame_count) |i| {
            src_planes[i][0] = luma_frames[i].getReadSlice(0);
            src_planes[i][1] = src_frames[i].getReadSlice(1);
            src_planes[i][2] = src_frames[i].getReadSlice(2);
            ref_planes[i][0] = if (d.node_ref) |_| ref_luma_frames[i].getReadSlice(0) else luma_frames[i].getReadSlice(0);
            ref_planes[i][1] = if (d.node_ref) |_| ref_frames[i].getReadSlice(1) else src_frames[i].getReadSlice(1);
            ref_planes[i][2] = if (d.node_ref) |_| ref_frames[i].getReadSlice(2) else src_frames[i].getReadSlice(2);
        }

        // Allocate scratch buffers for CNR2 mode to hold temporary frames.
        var scratch_frames: [4]ZAPI.ZFrame(*vs.Frame) = undefined;
        var scratch_planes: [4][]u8 = undefined;
        var grey_format: vs.VideoFormat = undefined;
        _ = zapi.queryVideoFormat(&grey_format, .Gray, d.vi.format.sampleType, d.vi.format.bitsPerSample, 0, 0);
        if (d.tmode.needsScratchFrames()) {
            for (0..4) |i| {
                scratch_frames[i] = ZAPI.ZFrame(*vs.Frame).init(&zapi, zapi.newVideoFrame(&grey_format, d.vi.width >> @intCast(d.vi.format.subSamplingW), d.vi.height >> @intCast(d.vi.format.subSamplingH), null).?);
                scratch_planes[i] = scratch_frames[i].getWriteSlice(0);
            }
        }
        defer if (d.tmode.needsScratchFrames()) for (scratch_frames) |f| f.deinit();

        const processFrame = switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &Cnr4(u8).processFrame,
            .U16 => &Cnr4(u16).processFrame,
            else => unreachable,
            // .F16 => &Cnr4(f16).processPlane,
            // .F32 => &Cnr4(f32).processPlane,
        };

        processFrame(.{
            curr_luma.getReadSlice(0),
            curr.getReadSlice(1),
            curr.getReadSlice(2),
        }, .{
            if (d.node_ref) |_| curr_ref_luma.getReadSlice(0) else curr_luma.getReadSlice(0),
            if (d.node_ref) |_| curr_ref.getReadSlice(1) else curr.getReadSlice(1),
            if (d.node_ref) |_| curr_ref.getReadSlice(2) else curr.getReadSlice(2),
        }, src_planes[0..frame_count], ref_planes[0..frame_count], dst.getWriteSlice(1), dst.getWriteSlice(2), scratch_planes, .{
            d.table_y,
            d.table_u,
            d.table_v,
        }, .{
            .tmode = d.tmode,
            .wmode = d.wmode,

            .radius = d.radius,

            .depth = @intCast(d.vi.format.bitsPerSample),

            .width_y = curr.getWidth(0),
            .width_uv = curr.getWidth(1),

            .height_y = curr.getHeight(0),
            .height_uv = curr.getHeight(1),

            .stride_y = curr_luma.getStride(0),
            .stride_uv = curr.getStride(1),

            .subsampling_w = @intCast(d.vi.format.subSamplingW),
            .subsampling_h = @intCast(d.vi.format.subSamplingH),
        });

        return dst.frame;
    }

    return null;
}

export fn cnr4Free(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = core;
    const d: *Cnr4Data = @ptrCast(@alignCast(instance_data));

    vsapi.?.freeNode.?(d.node);
    vsapi.?.freeNode.?(d.node_luma);
    vsapi.?.freeNode.?(d.node_ref);
    vsapi.?.freeNode.?(d.node_ref_luma);

    allocator.free(d.table_y);
    allocator.free(d.table_u);
    allocator.free(d.table_v);

    allocator.destroy(d);
}

export fn cnr4Create(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = user_data;
    const zapi = ZAPI.init(vsapi, core, null);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);

    var d: Cnr4Data = undefined;

    d.node, d.vi = inz.getNodeVi("clip").?;

    if (!vsh.isConstantVideoFormat(d.vi) or
        d.vi.format.colorFamily != .YUV or
        d.vi.format.sampleType != .Integer or
        d.vi.format.bitsPerSample < 8 or d.vi.format.bitsPerSample > 16 or
        d.vi.format.subSamplingW > 1 or
        d.vi.format.subSamplingH > 1)
    {
        outz.setError("Cnr4: clip must have constant format and dimensions, and it must be integer YUV420, YUV422, YUV440, or YUV444.");
        zapi.freeNode(d.node);
        return;
    }

    const mode: []const u8 = if (inz.getData("mode", 0)) |mode| blk: {
        if (mode.len != 3) {
            outz.setError("Cnr4: mode must have 3 characters");
            zapi.freeNode(d.node);
            return;
        }
        break :blk mode;
    } else "oxx";

    d.radius = if (inz.getInt(i32, "radius")) |radius| blk: {
        if (radius < 1 or radius > MAX_RADIUS) {
            outz.setError("Cnr4: radius must be between 1 and 10");
            zapi.freeNode(d.node);
            return;
        }

        break :blk @intCast(radius);
    } else 2;

    d.tmode = if (inz.getInt(i32, "tmode")) |tmode| blk: {
        if (tmode < 0 or tmode > 4) {
            outz.setError("Cnr4: tmode can only be between 0 and 4");
            zapi.freeNode(d.node);
            return;
        }

        break :blk @enumFromInt(tmode);
    } else .inv_diff;

    // The effect is identical between temporal modes
    // if the radius is 1, so just force it to the faster one.
    if (d.radius == 1) {
        d.tmode = .inv_diff;
    }

    d.wmode = if (inz.getInt(i32, "wmode")) |wmode| blk: {
        if (wmode < 0 or wmode > 3) {
            outz.setError("Cnr4: wmode can only be between 0 and 3");
            zapi.freeNode(d.node);
            return;
        }

        break :blk @enumFromInt(wmode);
    } else .original;

    d.scenechange = inz.getBool("scenechange") orelse true;

    // Sensitivies
    if (inz.numElements("sense")) |n| {
        if (n != 3) {
            outz.setError("Cnr4: sense must have 3 elements");
            zapi.freeNode(d.node);
            return;
        }
    }

    const l_sense: u8 = if (inz.getInt2(i32, "sense", 0)) |l_sense| blk: {
        if (l_sense < -1 or l_sense > 255) {
            outz.setError("Cnr4: sense must be between -1 and 255");
            zapi.freeNode(d.node);
            return;
        }

        break :blk if (l_sense == -1) 35 else @intCast(l_sense);
    } else 35;

    const u_sense: u8 = if (inz.getInt2(i32, "sense", 1)) |u_sense| blk: {
        if (u_sense < -1 or u_sense > 255) {
            outz.setError("Cnr4: sense must be between -1 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk if (u_sense == -1) 47 else @intCast(u_sense);
    } else 47;

    const v_sense: u8 = if (inz.getInt2(i32, "sense", 2)) |v_sense| blk: {
        if (v_sense < -1 or v_sense > 255) {
            outz.setError("Cnr4: sense must be between -1 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk if (v_sense == -1) 47 else @intCast(v_sense);
    } else 47;

    // Strengths
    if (inz.numElements("str")) |n| {
        if (n != 3) {
            outz.setError("Cnr4: str must have 3 elements");
            zapi.freeNode(d.node);
            return;
        }
    }

    const l_str: u8 = if (inz.getInt2(i32, "str", 0)) |l_str| blk: {
        if (l_str < -1 or l_str > 255) {
            outz.setError("Cnr4: l_str must be between -1 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk if (l_str == -1) 192 else @intCast(l_str);
    } else 192;

    const u_str: u8 = if (inz.getInt2(i32, "str", 1)) |u_str| blk: {
        if (u_str < -1 or u_str > 255) {
            outz.setError("Cnr4: u_str must be between -1 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk if (u_str == -1) 255 else @intCast(u_str);
    } else 255;

    const v_str: u8 = if (inz.getInt2(i32, "str", 2)) |v_str| blk: {
        if (v_str < -1 or v_str > 255) {
            outz.setError("Cnr4: v_str must be between -1 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk if (v_str == -1) 255 else @intCast(v_str);
    } else 255;

    // Using an aligned alloc for potential SIMD/autovec friendliness
    // Might not make any difference, but it doesn't hurt
    const table_size = 256;
    d.table_y = allocator.alignedAlloc(u8, std.mem.Alignment.fromByteUnits(LUT_ALIGN), table_size) catch {
        outz.setError("Cnr4: Unable to allocate memory for internal tables");
        zapi.freeNode(d.node);
        return;
    };
    d.table_u = allocator.alignedAlloc(u8, std.mem.Alignment.fromByteUnits(LUT_ALIGN), table_size) catch {
        outz.setError("Cnr4: Unable to allocate memory for internal tables");
        zapi.freeNode(d.node);
        return;
    };
    d.table_v = allocator.alignedAlloc(u8, std.mem.Alignment.fromByteUnits(LUT_ALIGN), table_size) catch {
        outz.setError("Cnr4: Unable to allocate memory for internal tables");
        zapi.freeNode(d.node);
        return;
    };

    // Zero out all weights
    @memset(d.table_y, 0);
    @memset(d.table_u, 0);
    @memset(d.table_v, 0);

    // Create separate scopes to reduce chance of bugs from variable reuse (which happened)
    {
        //TODO: inline casts once we're using Zig 0.16.0+
        const l_strf: f32 = @floatFromInt(l_str);
        const l_sensef: f32 = @floatFromInt(l_sense);
        var l: u9 = 0;
        while (l <= l_str) : (l += 1) {
            const lf: f32 = @floatFromInt(l);
            d.table_y[l] = switch (mode[0]) {
                'o' => @intFromFloat(l_strf / 2 * (1 + @cos(lf * lf * std.math.pi / (l_sensef * l_sensef)))),
                'x' => @intFromFloat(l_strf / 2 * (1 + @cos(lf * std.math.pi / l_sensef))),
                else => {
                    outz.setError("Cnr4: Only 'o' and 'x' are recognized characters in mode");
                    zapi.freeNode(d.node);
                    return;
                },
            };
        }
    }

    {
        const u_strf: f32 = @floatFromInt(u_str);
        const u_sensef: f32 = @floatFromInt(u_sense);
        var u: u9 = 0;
        while (u <= u_str) : (u += 1) {
            const uf: f32 = @floatFromInt(u);
            d.table_u[u] = switch (mode[1]) {
                'o' => @intFromFloat(u_strf / 2 * (1 + @cos(uf * uf * std.math.pi / (u_sensef * u_sensef)))),
                'x' => @intFromFloat(u_strf / 2 * (1 + @cos(uf * std.math.pi / u_sensef))),
                else => {
                    outz.setError("Cnr4: Only 'o' and 'x' are recognized characters in mode");
                    zapi.freeNode(d.node);
                    return;
                },
            };
        }
    }

    {
        const v_strf: f32 = @floatFromInt(v_str);
        const v_sensef: f32 = @floatFromInt(v_sense);
        var v: u9 = 0;
        while (v <= v_str) : (v += 1) {
            const vf: f32 = @floatFromInt(v);
            d.table_v[v] = switch (mode[2]) {
                'o' => @intFromFloat(v_strf / 2 * (1 + @cos(vf * vf * std.math.pi / (v_sensef * v_sensef)))),
                'x' => @intFromFloat(v_strf / 2 * (1 + @cos(vf * std.math.pi / v_sensef))),
                else => {
                    outz.setError("Cnr4: Only 'o' and 'x' are recognized characters in mode");
                    zapi.freeNode(d.node);
                    return;
                },
            };
        }
    }

    d.node_ref = null;
    d.node_ref_luma = null;
    if (inz.getNodeVi2("ref")) |refvi| {
        if (!vsh.isSameVideoInfo(d.vi, refvi.vi)) {
            outz.setError("Cnr4: ref must be the same video format, width, and height as the source clip");
            zapi.freeNode(d.node);
            return;
        }
        d.node_ref = refvi.node;
    }

    // Call bilinear resize to handle the luma downscaling.
    const needs_resize = d.vi.format.subSamplingW > 0 or d.vi.format.subSamplingH > 0;

    // Extract luma plane
    {
        const NodePair = struct { node: ?*vs.Node, luma: *?*vs.Node };
        for ([_]NodePair{
            .{ .node = d.node, .luma = &d.node_luma },
            .{ .node = d.node_ref, .luma = &d.node_ref_luma },
        }) |n| {
            if (n.node == null) {
                // ref is optional, so skip it if its not set.
                continue;
            }

            const args = zapi.createZMap();
            defer args.free();

            _ = args.setNode("clips", n.node, .Append);
            args.setInt("planes", 0, .Append);
            args.setInt("colorfamily", @intFromEnum(vs.ColorFamily.Gray), .Append);

            const ret = zapi.initZMap(zapi.invoke(zapi.getPluginByID(vsh.STD_PLUGIN_ID), "ShufflePlanes", args.map));
            defer ret.free();

            if (ret.getError()) |e| {
                // Don't love this manual string length calculation, but it works for now.
                // Should probably upstream this to vapoursynth-zig
                const index = std.mem.indexOfSentinel(u8, 0, e);
                outz.setError(e[0..index :0]);
                zapi.freeNode(n.node);
                return;
            }

            n.luma.* = ret.getNode("clip").?;
        }
    }

    // Resize the luma
    if (needs_resize) {
        for ([_]*?*vs.Node{
            &d.node_luma,
            &d.node_ref_luma,
        }) |n| {
            if (n.* == null) {
                // ref is optional, so skip it if its not set.
                continue;
            }

            const args = zapi.createZMap();
            defer args.free();

            _ = args.consumeNode("clip", n.*, .Append);
            args.setInt("width", d.vi.width >> @intCast(d.vi.format.subSamplingW), .Append);
            args.setInt("height", d.vi.height >> @intCast(d.vi.format.subSamplingH), .Append);
            //TODO: Add chroma location support for sub-pixel accuracy.

            const ret = zapi.initZMap(zapi.invoke(zapi.getPluginByID(vsh.RESIZE_PLUGIN_ID), "Bilinear", args.map));
            defer ret.free();

            if (ret.getError()) |e| {
                // Don't love this manual string length calculation, but it works for now.
                // Should probably upstream this to vapoursynth-zig
                const index = std.mem.indexOfSentinel(u8, 0, e);
                outz.setError(e[0..index :0]);
                zapi.freeNode(n.*);
                return;
            }

            n.* = ret.getNode("clip").?;
        }
    }

    const data: *Cnr4Data = allocator.create(Cnr4Data) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.General,
        },
    };

    zapi.createVideoFilter(out, "Cnr4", d.vi, cnr4GetFrame, cnr4Free, fm.Parallel, &deps, data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("Cnr4", "clip:vnode;" ++
        "mode:data:opt;" ++
        "radius:int:opt;" ++
        "sense:int[]:opt;" ++
        "str:int[]:opt;" ++
        "tmode:int:opt;" ++
        "wmode:int:opt;" ++
        "scenechange:int:opt;" ++
        "ref:vnode:opt;", "clip:vnode;", cnr4Create, null, plugin);
}
