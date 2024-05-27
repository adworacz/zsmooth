const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;

const cmn = @import("common.zig");
const vscmn = @import("common/vapoursynth.zig");
const vec = @import("common/vector.zig");

const math = std.math;
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
    scenechange: u8,
    scenechange_prop_prev: []const u8,
    scenechange_prop_next: []const u8,

    process: [3]bool,
};

fn TemporalSoften(comptime T: type) type {
    return struct {
        /// Signed Arithmetic Type - used in signed arithmetic to safely hold
        /// the values (particularly integers) without overflowing when doing
        /// signed arithmetic.
        const SAT = switch (T) {
            u8 => i16,
            u16 => i32,
            f16 => f32,
            f32 => f32,
            else => unreachable,
        };

        /// Unsigned Arithmetic Type - used in unsigned arithmetic to safely
        /// hold values (particularly integers) without overflowing when doing
        /// unsigned arithmetic.
        const UAT = switch (T) {
            u8 => u16,
            u16 => u32,
            f16 => f32,
            f32 => f32,
            else => unreachable,
        };

        fn processPlaneScalar(srcp: [MAX_DIAMETER][]const T, dstp: []T, width: usize, height: usize, stride: usize, frames: u8, threshold: T) void {
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

                    dstp[current_pixel] = if (cmn.isFloat(T))
                        @floatCast(sum / @as(f32, @floatFromInt(frames)))
                    else
                        // Add half_frames to round the integer value up to the nearest integer value.
                        // So a pixel value of 2.5 will be round (and truncated) to 3, while a pixel value of 2.4 will be truncated to 2.
                        @intCast((sum + half_frames) / frames);
                }
            }
        }

        fn processPlaneVector(srcp: [MAX_DIAMETER][]const T, dstp: []T, width: usize, height: usize, stride: usize, frames: u8, threshold: T) void {
            const vec_size = vec.getVecSize(T);
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

        fn temporalSmoothVector(srcp: [MAX_DIAMETER][]const T, dstp: []T, offset: usize, frames: u8, threshold: T) void {
            const vec_size = vec.getVecSize(T);
            const VecType = @Vector(vec_size, T);

            const threshold_vec: VecType = @splat(threshold);
            const current_value_vec = vec.load(VecType, srcp[0], offset);

            var sum_vec: @Vector(vec_size, UAT) = current_value_vec;

            for (1..frames) |i| {
                const frame_value_vec = vec.load(VecType, srcp[i], offset);

                const abs_vec = if (cmn.isFloat(T))
                    @abs(@as(@Vector(vec_size, f32), current_value_vec) - frame_value_vec)
                else
                    @max(current_value_vec, frame_value_vec) - @min(current_value_vec, frame_value_vec);

                const lte_threshold_vec = abs_vec <= threshold_vec;

                sum_vec += @select(T, lte_threshold_vec, frame_value_vec, current_value_vec);
            }

            const result: VecType = if (cmn.isFloat(T))
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
            const width = 54;
            const stride = width + 8 + 32;
            const size = height * stride;

            const radius = 2;
            const diameter = radius * 2 + 1;
            const threshold: u32 = if (cmn.isInt(T)) 4 else @bitCast(@as(f32, 4));
            const expectedAverage = ([_]T{3} ** size)[0..];

            var src: [MAX_DIAMETER][]const T = undefined;
            for (0..diameter) |i| {
                const frame = try testingAllocator.alloc(T, size);
                if (cmn.isFloat(T)) {
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

        pub fn getFrame(_n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
            // Assign frame_data to nothing to stop compiler complaints
            _ = frame_data;

            const d: *TemporalSoftenData = @ptrCast(@alignCast(instance_data));
            const n: usize = math.lossyCast(usize, _n);
            const radius: usize = math.lossyCast(usize, d.radius);

            const first: usize = n -| radius;
            const last: usize = @min(n + radius, math.lossyCast(usize, d.vi.numFrames - 1));

            if (activation_reason == ar.Initial) {
                for (first..(last + 1)) |i| {
                    vsapi.?.requestFrameFilter.?(@intCast(i), d.node, frame_ctx);
                }
            } else if (activation_reason == ar.AllFramesReady) {
                var err: vs.MapPropertyError = undefined;
                var src_frames: [MAX_DIAMETER]?*const vs.Frame = undefined;
                // The current frame is always stored at the first (0) index.
                src_frames[0] = vsapi.?.getFrameFilter.?(_n, d.node, frame_ctx);
                var frames: u8 = 1;

                var sc_prev = if (d.scenechange > 0) vsapi.?.mapGetInt.?(vsapi.?.getFramePropertiesRO.?(src_frames[0]), d.scenechange_prop_prev.ptr, 0, &err) else 0;
                var sc_next = if (d.scenechange > 0) vsapi.?.mapGetInt.?(vsapi.?.getFramePropertiesRO.?(src_frames[0]), d.scenechange_prop_next.ptr, 0, &err) else 0;

                // Request previous frames, up until we hit a scene change, if using scene change detection.
                // Even though we aren't going to use all of the frames in a scene change
                // we still need to request them so that we can free those unused frames.
                for (1..(n - first + 1)) |i| {
                    src_frames[frames] = vsapi.?.getFrameFilter.?(_n - @as(c_int, @intCast(i)), d.node, frame_ctx);

                    if (sc_prev != 0) {
                        // This frame is a scene change, so let's ditch it and continue;
                        vsapi.?.freeFrame.?(src_frames[frames]);
                        continue;
                    }

                    if (d.scenechange > 0) {
                        sc_prev = vsapi.?.mapGetInt.?(vsapi.?.getFramePropertiesRO.?(src_frames[frames]), d.scenechange_prop_prev.ptr, 0, &err);
                    }

                    frames += 1;
                }

                // Retrieve next frames, up until we hit a scene change, if using scene change detection.
                for (1..(last - n + 1)) |i| {
                    src_frames[frames] = vsapi.?.getFrameFilter.?(_n + @as(c_int, @intCast(i)), d.node, frame_ctx);

                    if (sc_next != 0) {
                        // This frame is a scene change, so let's ditch it and continue;
                        vsapi.?.freeFrame.?(src_frames[frames]);
                        continue;
                    }

                    if (d.scenechange > 0) {
                        sc_next = vsapi.?.mapGetInt.?(vsapi.?.getFramePropertiesRO.?(src_frames[frames]), d.scenechange_prop_next.ptr, 0, &err);
                    }

                    frames += 1;
                }
                defer for (0..frames) |i| vsapi.?.freeFrame.?(src_frames[i]);

                const dst = vscmn.newVideoFrame(&d.process, src_frames[0], d.vi, core, vsapi);

                for (0..@intCast(d.vi.format.numPlanes)) |_plane| {
                    const plane: c_int = @intCast(_plane);

                    // Skip planes we aren't supposed to process
                    if (d.threshold[_plane] == 0) {
                        continue;
                    }

                    const width: usize = @intCast(vsapi.?.getFrameWidth.?(dst, plane));
                    const height: usize = @intCast(vsapi.?.getFrameHeight.?(dst, plane));
                    const stride: usize = @as(usize, @intCast(vsapi.?.getStride.?(dst, plane))) / @sizeOf(T);

                    var srcp: [MAX_DIAMETER][]const T = undefined;
                    for (0..frames) |i| {
                        srcp[i] = @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[i], plane))))[0..(height * stride)];
                    }
                    const dstp: []T = @as([*]T, @ptrCast(@alignCast(vsapi.?.getWritePtr.?(dst, plane))))[0..(height * stride)];

                    const threshold = cmn.lossyCast(T, d.threshold[_plane]);

                    // processPlaneScalar(srcp, @ptrCast(@alignCast(dstp)), width, height, stride, frames, threshold);
                    processPlaneVector(srcp, @ptrCast(@alignCast(dstp)), width, height, stride, frames, threshold);
                }

                return dst;
            }

            return null;
        }
    };
}

export fn temporalSoftenFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *TemporalSoftenData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn temporalSoftenCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    var d: TemporalSoftenData = undefined;

    var err: vs.MapPropertyError = undefined; // Just used for C API shimming. We use optionals for handling errors.

    if (vsapi.?.mapGetNode.?(in, "clip", 0, &err)) |node| {
        d.node = node;
    } else {
        vsapi.?.mapSetError.?(out, "TemporalSoften: Please provide a clip.");
        return;
    }

    d.vi = vsapi.?.getVideoInfo.?(d.node);

    // Check video format.
    if (!vsh.isConstantVideoFormat(d.vi) or
        (d.vi.format.colorFamily != vs.ColorFamily.YUV and
        d.vi.format.colorFamily != vs.ColorFamily.RGB and
        d.vi.format.colorFamily != vs.ColorFamily.Gray))
    {
        return vscmn.reportError("TemporalSoften: only constant format YUV, RGB or Grey input is supported", vsapi, out, d.node);
    }

    // Check radius param
    if (vsh.mapGetN(i32, in, "radius", 0, vsapi)) |radius| {
        if ((radius < 1) or (radius > MAX_RADIUS)) {
            return vscmn.reportError("TemporalSoften: Radius must be between 1 and 7 (inclusive)", vsapi, out, d.node);
        }
        d.radius = @intCast(radius);
    } else {
        d.radius = 4;
    }

    const scalep = vsh.mapGetN(bool, in, "scalep", 0, vsapi) orelse false;

    // Check threshold param
    d.threshold = if (d.vi.format.colorFamily == vs.ColorFamily.RGB)
        [_]f32{ cmn.scaleToFormat(f32, d.vi.format, 4, 0), cmn.scaleToFormat(f32, d.vi.format, 4, 0), cmn.scaleToFormat(f32, d.vi.format, 4, 0) }
    else
        [_]f32{ cmn.scaleToFormat(f32, d.vi.format, 4, 0), cmn.scaleToFormat(f32, d.vi.format, 8, 0), cmn.scaleToFormat(f32, d.vi.format, 8, 0) };

    for (0..3) |i| {
        if (vsh.mapGetN(f32, in, "threshold", @intCast(i), vsapi)) |_threshold| {
            if (scalep and (_threshold < 0 or _threshold > 255)) {
                return vscmn.reportError(cmn.printf(allocator, "TemporalSoften: Using parameter scaling (scalep), but threshold value of {d} is outside the range of 0-255", .{_threshold}), vsapi, out, d.node);
            }

            const threshold = if (scalep)
                cmn.scaleToFormat(f32, d.vi.format, @intFromFloat(_threshold), 0)
            else
                _threshold;

            const formatMaximum = cmn.getFormatMaximum(f32, d.vi.format, i > 0);
            const formatMinimum = cmn.getFormatMinimum(f32, d.vi.format, i > 0);

            if ((threshold < formatMinimum or threshold > formatMaximum)) {
                return vscmn.reportError(cmn.printf(allocator, "TemporalSoften: Index {d} threshold '{d}' must be between {d} and {d} (inclusive)", .{ i, threshold, formatMinimum, formatMaximum }), vsapi, out, d.node);
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
        return vscmn.reportError("TemporalSoften: threshold at index 0 must not be 0 when input is RGB or Gray", vsapi, out, d.node);
    }

    if (d.threshold[0] == 0 and d.threshold[1] == 0 and d.threshold[2] == 0) {
        return vscmn.reportError("TemporalSoften: All thresholds cannot be 0.", vsapi, out, d.node);
    }

    d.process = [_]bool{
        d.threshold[0] > 0,
        d.threshold[1] > 0,
        d.threshold[2] > 0,
    };

    if (vsh.mapGetN(i32, in, "scenechange", 0, vsapi)) |scenechange| {
        if (scenechange < 0 or scenechange > 254) {
            return vscmn.reportError("TemporalSoften: scenechange must be between 0 and 254 (inclusive)", vsapi, out, d.node);
        }
        d.scenechange = @intCast(scenechange);
    } else {
        d.scenechange = 0;
    }

    if (d.scenechange > 0) {
        if (d.vi.format.colorFamily == vs.ColorFamily.RGB) {
            return vscmn.reportError("TemporalSoften: Scene change support does not work with RGB.", vsapi, out, d.node);
        }

        // TODO: Support more scene change plugins via custom scene change property specification.
        if (vsapi.?.getPluginByID.?("com.vapoursynth.misc", core)) |misc_plugin| {
            const args = vsapi.?.createMap.?();
            _ = vsapi.?.mapSetNode.?(args, "clip", d.node, vs.MapAppendMode.Replace);
            vsapi.?.freeNode.?(d.node);
            _ = vsapi.?.mapSetFloat.?(args, "threshold", @as(f64, @floatFromInt(d.scenechange)) / 255.0, vs.MapAppendMode.Replace);

            const ret = vsapi.?.invoke.?(misc_plugin, "SCDetect", args);
            vsapi.?.freeMap.?(args);

            if (vsapi.?.mapGetNode.?(ret, "clip", 0, &err)) |node| {
                d.node = node;
                d.scenechange_prop_prev = "_SceneChange_Prev";
                d.scenechange_prop_next = "_SceneChange_Next";
                vsapi.?.freeMap.?(ret);
            } else {
                vsapi.?.mapSetError.?(out, vsapi.?.mapGetError.?(ret));
                vsapi.?.freeMap.?(ret);
                return;
            }
        } else {
            return vscmn.reportError("TemporalSoften: Miscellaneous filters plugin is required in order to use scene change detection.", vsapi, out, d.node);
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
