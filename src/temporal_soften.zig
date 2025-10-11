const std = @import("std");
const vapoursynth = @import("vapoursynth");
const ZAPI = vapoursynth.ZAPI;
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;

const string = @import("common/string.zig");
const types = @import("common/type.zig");
const math = @import("common/math.zig");
const vscmn = @import("common/vapoursynth.zig");
const vec = @import("common/vector.zig");
const float_mode: std.builtin.FloatMode = if (@import("config").optimize_float) .optimized else .strict;

const vs = vapoursynth.vapoursynth4;
const vsh = vapoursynth.vshelper;

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

const TemporalSoftenData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    vi: *const vs.VideoInfo,

    // The temporal radius from which we'll build a median.
    radius: i8,
    threshold: [3]f32,
    scenechange: bool,

    process: [3]bool,
};

fn TemporalSoften(comptime T: type) type {
    const vec_size = vec.getVecSize(T);
    const VecType = @Vector(vec_size, T);

    return struct {
        const SAT = types.SignedArithmeticType(T);
        const UAT = types.UnsignedArithmeticType(T);

        fn processPlaneScalar(srcp: [MAX_DIAMETER][]const T, noalias dstp: []T, width: usize, height: usize, stride: usize, frames: u8, threshold: T) void {
            @setFloatMode(float_mode);

            const half_frames: u8 = @divTrunc(frames, 2);

            for (0..height) |row| {
                for (0..width) |column| {
                    const current_pixel = row * stride + column;
                    const current_value = srcp[0][current_pixel];

                    var sum: UAT = current_value;

                    for (1..frames) |i| {
                        var value = current_value;
                        const frame_value = srcp[i][current_pixel];
                        if (@abs(@as(SAT, value) - frame_value) <= threshold) {
                            value = frame_value;
                        }
                        sum += value;
                    }

                    dstp[current_pixel] = if (types.isFloat(T))
                        @floatCast(sum / @as(f32, @floatFromInt(frames)))
                    else
                        // Add half_frames to round the integer value up to the nearest integer value.
                        // So a pixel value of 2.5 will be round (and truncated) to 3, while a pixel value of 2.4 will be truncated to 2.
                        @intCast((sum + half_frames) / frames);
                }
            }
        }

        fn processPlaneVector(srcp: [MAX_DIAMETER][]const T, noalias dstp: []T, width: usize, height: usize, stride: usize, frames: u8, threshold: T) void {
            const width_simd = width / vec_size * vec_size;

            for (0..height) |row| {
                var column: usize = 0;
                while (column < width_simd) : (column += vec_size) {
                    const offset = row * stride + column;
                    temporalSmoothVector(srcp, dstp, offset, frames, threshold);
                }

                if (width_simd < width) {
                    temporalSmoothVector(srcp, dstp, (row * stride) + width - vec_size, frames, threshold);
                }
            }
        }

        fn temporalSmoothVector(srcp: [MAX_DIAMETER][]const T, noalias dstp: []T, offset: usize, frames: u8, threshold: T) void {
            @setFloatMode(float_mode);

            const threshold_vec: VecType = @splat(threshold);
            const current_value_vec = vec.load(VecType, srcp[0], offset);

            var sum_vec: @Vector(vec_size, UAT) = current_value_vec;

            for (1..frames) |i| {
                const frame_value_vec = vec.load(VecType, srcp[i], offset);

                const abs_vec = if (types.isFloat(T))
                    @abs(@as(@Vector(vec_size, f32), current_value_vec) - frame_value_vec)
                else
                    @max(current_value_vec, frame_value_vec) - @min(current_value_vec, frame_value_vec);

                const lte_threshold_vec = abs_vec <= threshold_vec;

                sum_vec += @select(T, lte_threshold_vec, frame_value_vec, current_value_vec);
            }

            const result: VecType = if (types.isFloat(T))
                @floatCast(sum_vec / @as(@Vector(vec_size, f32), @splat(@floatFromInt(frames))))
            else result: {
                // As it turns out, integer division can be dog slow.
                //
                // This code uses a form of fast division
                // called division by multiplication of reciprocal.
                //
                // Effectively, it is based on the principal
                // that N/D is the same as N * (1/D), which is
                // the same as (N * (1 << Z / D)) >> Z
                //
                // We use Z to scale up the multiplier to account for integer
                // arithmetic (since normally N * (1/D) == 0 in integer land).
                //
                // So if we use a large enough Z when scaling up, then any
                // rounding error gets truncated when we shift back down by Z.
                // The trick is to use a large enough value of Z.
                //
                // In this case, I'm using half of my mutiplier type, which is
                // technically overkill for the values of N (sum of pixel
                // values) and D (frames) that we are using, but it ensures we
                // get accurate results and it's simple code to write.

                // BT = extra large (big) arithmetic type since we're going to
                // be doing multiplication that would otherwise overflow
                // smaller types for large radii or bit depths.
                const BT = if (T == u8) u32 else u64;

                const shift_size = @bitSizeOf(BT) / 2;
                const mul: @Vector(vec_size, BT) = @splat(@as(BT, 1 << shift_size) / frames);
                sum_vec += @splat(frames / 2); // Add half frames to properly round
                break :result @intCast((sum_vec * mul) >> @splat(shift_size));
            };

            vec.store(VecType, dstp, offset, result);
        }

        test "processPlane should find the average value" {
            const height = 2;
            const width = vec_size + 24;
            const stride = width + 8 + vec_size;
            const size = height * stride;

            const radius = 2;
            const diameter = radius * 2 + 1;
            const threshold: u32 = if (types.isInt(T)) 4 else @bitCast(@as(f32, 4));
            const expectedAverage = ([_]T{3} ** size)[0..];

            var src: [MAX_DIAMETER][]const T = undefined;
            for (0..diameter) |i| {
                const frame = try testingAllocator.alloc(T, size);
                if (types.isFloat(T)) {
                    @memset(frame, @floatFromInt(i + 1));
                } else {
                    @memset(frame, @intCast(i + 1));
                }
                src[i] = frame;
            }
            defer for (0..diameter) |i| testingAllocator.free(src[i][0..size]);

            const dstp_scalar = try testingAllocator.alloc(T, size);
            const dstp_vec = try testingAllocator.alloc(T, size);
            defer testingAllocator.free(dstp_scalar);
            defer testingAllocator.free(dstp_vec);

            processPlaneScalar(src, dstp_scalar, width, height, stride, diameter, threshold);
            processPlaneVector(src, dstp_vec, width, height, stride, diameter, threshold);

            for (0..height) |row| {
                const start = row * stride;
                const end = start + width;
                try testing.expectEqualDeep(expectedAverage[start..end], dstp_scalar[start..end]);
                try testing.expectEqualDeep(expectedAverage[start..end], dstp_vec[start..end]);
            }
        }

        pub fn getFrame(_n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) ?*const vs.Frame {
            // Assign frame_data to nothing to stop compiler complaints
            _ = frame_data;

            const zapi = ZAPI.init(vsapi, core, frame_ctx);

            const d: *TemporalSoftenData = @ptrCast(@alignCast(instance_data));
            const n: usize = math.lossyCast(usize, _n);
            const radius: usize = math.lossyCast(usize, d.radius);

            const first: usize = n -| radius;
            const last: usize = @min(n + radius, math.lossyCast(usize, d.vi.numFrames - 1));

            if (activation_reason == ar.Initial) {
                for (first..(last + 1)) |i| {
                    zapi.requestFrameFilter(@intCast(i), d.node);
                }
            } else if (activation_reason == ar.AllFramesReady) {
                var src_frames: [MAX_DIAMETER]ZAPI.ZFrame(*const vs.Frame) = undefined;
                // The current frame is always stored at the first (0) index.
                src_frames[0] = zapi.initZFrame(d.node, _n);
                var frames: u8 = 1;

                var sc_prev = if (d.scenechange) src_frames[0].getPropertiesRO().getInt(i32, "_SceneChangePrev") orelse 0 else 0;
                var sc_next = if (d.scenechange) src_frames[0].getPropertiesRO().getInt(i32, "_SceneChangeNext") orelse 0 else 0;

                // Request previous frames, up until we hit a scene change, if using scene change detection.
                // Even though we aren't going to use all of the frames in a scene change
                // we still need to request them so that we can free those unused frames.
                for (1..(n - first + 1)) |i| {
                    src_frames[frames] = zapi.initZFrame(d.node, _n - @as(c_int, @intCast(i)));

                    if (sc_prev != 0) {
                        // This frame is a scene change, so let's ditch it and continue;
                        src_frames[frames].deinit();
                        continue;
                    }

                    if (d.scenechange) {
                        sc_prev = src_frames[frames].getPropertiesRO().getInt(i32, "_SceneChangePrev") orelse 0;
                    }

                    frames += 1;
                }

                // Retrieve next frames, up until we hit a scene change, if using scene change detection.
                for (1..(last - n + 1)) |i| {
                    src_frames[frames] = zapi.initZFrame(d.node, _n + @as(c_int, @intCast(i)));

                    if (sc_next != 0) {
                        // This frame is a scene change, so let's ditch it and continue;
                        src_frames[frames].deinit();
                        continue;
                    }

                    if (d.scenechange) {
                        sc_next = src_frames[frames].getPropertiesRO().getInt(i32, "_SceneChangeNext") orelse 0;
                    }

                    frames += 1;
                }
                defer for (0..frames) |i| src_frames[i].deinit();

                const dst = src_frames[0].newVideoFrame2(d.process);

                for (0..@intCast(d.vi.format.numPlanes)) |plane| {

                    // Skip planes we aren't supposed to process
                    if (d.threshold[plane] == 0) {
                        continue;
                    }

                    const width: usize = dst.getWidth(plane);
                    const height: usize = dst.getHeight(plane);
                    const stride: usize = dst.getStride2(T, plane);

                    var srcp: [MAX_DIAMETER][]const T = undefined;
                    for (0..frames) |i| {
                        srcp[i] = src_frames[i].getReadSlice2(T, plane);
                    }
                    const dstp: []T = dst.getWriteSlice2(T, plane);

                    const threshold = math.lossyCast(T, d.threshold[plane]);

                    // processPlaneScalar(srcp, @ptrCast(@alignCast(dstp)), width, height, stride, frames, threshold);
                    processPlaneVector(srcp, @ptrCast(@alignCast(dstp)), width, height, stride, frames, threshold);
                }

                return dst.frame;
            }

            return null;
        }
    };
}

export fn temporalSoftenFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = core;
    const d: *TemporalSoftenData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}
export fn temporalSoftenCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = user_data;
    var d: TemporalSoftenData = undefined;

    const zapi = ZAPI.init(vsapi, core, null);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);

    d.node, d.vi = inz.getNodeVi("clip").?;

    // Check video format.
    if (!vsh.isConstantVideoFormat(d.vi) or
        (d.vi.format.colorFamily != vs.ColorFamily.YUV and
            d.vi.format.colorFamily != vs.ColorFamily.RGB and
            d.vi.format.colorFamily != vs.ColorFamily.Gray))
    {
        return vscmn.reportError2("TemporalSoften: only constant format YUV, RGB or Grey input is supported", zapi, outz, d.node);
    }

    // Check radius param
    if (inz.getInt(i32, "radius")) |radius| {
        if ((radius < 1) or (radius > MAX_RADIUS)) {
            return vscmn.reportError2("TemporalSoften: Radius must be between 1 and 7 (inclusive)", zapi, outz, d.node);
        }
        d.radius = @intCast(radius);
    } else {
        d.radius = 4;
    }

    const scalep = inz.getBool("scalep") orelse false;

    // Check threshold param
    d.threshold = if (d.vi.format.colorFamily == vs.ColorFamily.RGB)
        [_]f32{ vscmn.scaleToFormat(f32, d.vi.format, 4, 0), vscmn.scaleToFormat(f32, d.vi.format, 4, 0), vscmn.scaleToFormat(f32, d.vi.format, 4, 0) }
    else
        [_]f32{ vscmn.scaleToFormat(f32, d.vi.format, 4, 0), vscmn.scaleToFormat(f32, d.vi.format, 8, 0), vscmn.scaleToFormat(f32, d.vi.format, 8, 0) };

    for (0..3) |i| {
        if (inz.getFloat2(f32, "threshold", i)) |_threshold| {
            if (scalep and (_threshold < 0 or _threshold > 255)) {
                return vscmn.reportError2(string.printf(allocator, "TemporalSoften: Using parameter scaling (scalep), but threshold value of {d} is outside the range of 0-255", .{_threshold}), zapi, outz, d.node);
            }

            const threshold = if (scalep)
                vscmn.scaleToFormat(f32, d.vi.format, _threshold, 0)
            else
                _threshold;

            const formatMaximum = vscmn.getFormatMaximum(f32, d.vi.format, i > 0);
            const formatMinimum = vscmn.getFormatMinimum(f32, d.vi.format, i > 0);

            if ((threshold < formatMinimum or threshold > formatMaximum)) {
                return vscmn.reportError2(string.printf(allocator, "TemporalSoften: Index {d} threshold '{d}' must be between {d} and {d} (inclusive)", .{ i, threshold, formatMinimum, formatMaximum }), zapi, outz, d.node);
            }
            d.threshold[i] = threshold;
        } else {
            // No threshold value specified for this index.
            if (i > 0) {
                d.threshold[i] = d.threshold[i - 1];
            }
        }
    }

    if (d.threshold[0] == 0 and (d.vi.format.colorFamily == vs.ColorFamily.RGB or d.vi.format.colorFamily == vs.ColorFamily.Gray)) {
        return vscmn.reportError2("TemporalSoften: threshold at index 0 must not be 0 when input is RGB or Gray", zapi, outz, d.node);
    }

    if (d.threshold[0] == 0 and d.threshold[1] == 0 and d.threshold[2] == 0) {
        return vscmn.reportError2("TemporalSoften: All thresholds cannot be 0.", zapi, outz, d.node);
    }

    d.process = [_]bool{
        d.threshold[0] > 0,
        d.threshold[1] > 0,
        d.threshold[2] > 0,
    };

    const scene_change_threshold = if (inz.getInt(i32, "scenechange")) |scene_change_threshold| blk: {
        if (scene_change_threshold < -1 or scene_change_threshold > 254) {
            return vscmn.reportError2("TemporalSoften: scenechange must be between -1 and 254 (inclusive)", zapi, outz, d.node);
        }
        break :blk scene_change_threshold;
    } else 0;

    d.scenechange = scene_change_threshold != 0;

    if (scene_change_threshold > 0) {
        if (d.vi.format.colorFamily == vs.ColorFamily.RGB) {
            return vscmn.reportError2("TemporalSoften: Scene change support does not work with RGB.", zapi, outz, d.node);
        }

        if (zapi.getPluginByID("com.vapoursynth.misc")) |misc_plugin| {
            const map = zapi.createMap();
            const args = zapi.initZMap(map);

            _ = args.setNode("clip", d.node, .Replace);
            zapi.freeNode(d.node);

            args.setFloat("threshold", @as(f64, @floatFromInt(scene_change_threshold)) / 255.0, .Replace);

            const ret = zapi.initZMap(zapi.invoke(misc_plugin, "SCDetect", args.map));
            defer ret.free();

            args.free();

            if (ret.getNode("clip")) |node| {
                d.node = node;
            } else {
                outz.setError(if (ret.getError()) |err| std.mem.span(err) else "TemporalSoften: Unexpected error while invoking SCDetect.");
                return;
            }
        } else {
            return vscmn.reportError("TemporalSoften: Miscellaneous filters (https://github.com/vapoursynth/vs-miscfilters-obsolete) plugin is required in order to use scene change detection.", vsapi, out, d.node);
        }
    }

    const data: *TemporalSoftenData = allocator.create(TemporalSoftenData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.General,
        },
    };

    const getFrame = switch (d.vi.format.bytesPerSample) {
        1 => &TemporalSoften(u8).getFrame,
        2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &TemporalSoften(u16).getFrame else &TemporalSoften(f16).getFrame,
        4 => &TemporalSoften(f32).getFrame,
        else => unreachable,
    };

    vsapi.?.createVideoFilter.?(out, "TemporalSoften", d.vi, getFrame, temporalSoftenFree, fm.Parallel, &deps, deps.len, data, core);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("TemporalSoften", "clip:vnode;radius:int:opt;threshold:float[]:opt;scenechange:int:opt;scalep:int:opt;", "clip:vnode;", temporalSoftenCreate, null, plugin);
}
