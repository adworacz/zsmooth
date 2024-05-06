const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;

const cmn = @import("common.zig");
const vscmn = @import("common/vapoursynth.zig");
const vec = @import("common/vector.zig");
const sort = @import("common/sorting_networks.zig");

const math = std.math;
const vs = vapoursynth.vapoursynth4;
const vsh = vapoursynth.vshelper;

const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;
const st = vs.SampleType;

const allocator = std.heap.c_allocator;

const DegrainMedianData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    vi: *const vs.VideoInfo,

    // Limit of the allowed pixel change.
    limit: [3]f32,
    // Processing mode, 0-5.
    mode: [3]u8,

    // Which planes we will process.
    process: [3]bool,
};

fn DegrainMedian(comptime T: type) type {
    // const vec_size = vec.getVecSize(T);
    // const VecType = @Vector(vec_size, T);

    return struct {

        // 0 1 2
        // 3 4 5
        // 6 7 8
        // const Positions = enum(u8) {
        //     top_left,
        //     top_center,
        //     top_right,
        //     center_left,
        //     center_center,
        //     center_right,
        //     bottom_left,
        //     bottom_center,
        //     bottom_right,
        // };
        const top_left = 0;
        const top_center = 1;
        const top_right = 2;
        const center_left = 3;
        const center_center = 4;
        const center_right = 5;
        const bottom_left = 6;
        const bottom_center = 7;
        const bottom_right = 8;

        test "Ensure positions match expected" {
            try std.testing.expectEqual(0, top_left);
            try std.testing.expectEqual(1, top_center);
            try std.testing.expectEqual(2, top_right);
            try std.testing.expectEqual(3, center_left);
            try std.testing.expectEqual(4, center_center);
            try std.testing.expectEqual(5, center_right);
            try std.testing.expectEqual(6, bottom_left);
            try std.testing.expectEqual(7, bottom_center);
            try std.testing.expectEqual(8, bottom_right);
            // try std.testing.expectEqual(0, .top_left);
            // try std.testing.expectEqual(1, .top_center);
            // try std.testing.expectEqual(2, .top_right);
            // try std.testing.expectEqual(3, .center_right);
            // try std.testing.expectEqual(4, .center_center);
            // try std.testing.expectEqual(5, .center_left);
            // try std.testing.expectEqual(6, .bottom_left);
            // try std.testing.expectEqual(7, .bottom_center);
            // try std.testing.expectEqual(8, .bottom_right);
        }

        /// Limits the change (difference) of a pixel to be no greater or less than limit,
        /// and no greater than pixel_max or less than pixel_min.
        fn limitPixelCorrectionScalar(old_pixel: T, new_pixel: T, limit: T, pixel_min: T, pixel_max: T) T {
            const lower = if (cmn.isInt(T))
                // Integer formats never go below zero
                // so we an use saturating subtraction.
                old_pixel -| limit
            else
                // Float formats can go to -0.5, for YUV
                // so we clamp to pixel_min.
                @max(pixel_min, old_pixel - limit);

            const upper = if (cmn.isInt(T))
                @min(old_pixel +| limit, pixel_max)
            else
                @min(old_pixel + limit, pixel_max);

            return @max(lower, @min(new_pixel, upper));
        }

        test limitPixelCorrectionScalar {

            // New pixel is lesser - within limit
            try std.testing.expectEqual(8, limitPixelCorrectionScalar(10, 8, 3, 0, 255));

            // New pixel is lesser - beyond limit (clamped)
            try std.testing.expectEqual(9, limitPixelCorrectionScalar(10, 8, 1, 0, 255));

            // New pixel is lesser - below pixel_min (clamped)
            if (cmn.isFloat(T)) {
                try std.testing.expectEqual(9, limitPixelCorrectionScalar(10, 8, 255, 9, 255));
            }

            // New pixel is greater - within limit
            try std.testing.expectEqual(12, limitPixelCorrectionScalar(10, 12, 3, 0, 255));

            // New pixel is greater - beyond limit (clamped)
            try std.testing.expectEqual(11, limitPixelCorrectionScalar(10, 12, 1, 0, 255));

            // New pixel is greater - above pixel_max (clamped)
            try std.testing.expectEqual(11, limitPixelCorrectionScalar(10, 12, 255, 0, 11));
        }

        /// Computes the absolute difference of two pixels, and if the
        /// difference is less than the provided diff param, it updates
        /// the diff param, as well as the min and max params with their
        /// corresponding values of the two pixels.
        fn checkBetterNeighorsScalar(a: T, b: T, diff: *T, min: *T, max: *T) void {
            const newdiff = if (cmn.isFloat(T))
                @abs(a - b)
            else
                @max(a, b) - @min(a, b);

            if (newdiff <= diff.*) {
                diff.* = newdiff;
                min.* = @min(a, b);
                max.* = @max(a, b);
            }
        }

        test checkBetterNeighorsScalar {
            var diff: T = 255;
            var max: T = 255;
            var min: T = 0;

            checkBetterNeighorsScalar(10, 7, &diff, &min, &max);
            try std.testing.expectEqualDeep(.{ 3, 7, 10 }, .{ diff, min, max });

            diff = 255;
            max = 255;
            min = 0;

            // Ensure pixel value order doesn't matter, which ensures we use @abs
            checkBetterNeighorsScalar(7, 10, &diff, &min, &max);
            try std.testing.expectEqualDeep(.{ 3, 7, 10 }, .{ diff, min, max });

            diff = 5;
            max = 255;
            min = 0;

            // Ensure that if the difference is greater than diff param,
            // nothing gets updated.
            checkBetterNeighorsScalar(0, 255, &diff, &min, &max);
            try std.testing.expectEqualDeep(.{ 5, 0, 255 }, .{ diff, min, max });
        }

        fn mode0Scalar(prev: [9]T, current: [9]T, next: [9]T, limit: T, pixel_min: T, pixel_max: T) T {
            var diff: T = pixel_max;
            var max: T = pixel_max;
            var min: T = 0;

            // Check the diagonals of the temporal neighbors.
            checkBetterNeighorsScalar(next[top_left], prev[bottom_right], &diff, &min, &max);
            checkBetterNeighorsScalar(next[top_right], prev[bottom_left], &diff, &min, &max);
            checkBetterNeighorsScalar(next[bottom_left], prev[top_right], &diff, &min, &max);
            checkBetterNeighorsScalar(next[bottom_right], prev[top_left], &diff, &min, &max);

            // Check the verticals of the temporal neighbors.
            checkBetterNeighorsScalar(next[bottom_center], prev[top_center], &diff, &min, &max);
            checkBetterNeighorsScalar(next[top_center], prev[bottom_center], &diff, &min, &max);

            // Check the horizontals of the temporal neighbors.
            checkBetterNeighorsScalar(next[center_left], prev[center_right], &diff, &min, &max);
            checkBetterNeighorsScalar(next[center_right], prev[center_left], &diff, &min, &max);

            // Check the center of the temporal neighbors.
            checkBetterNeighorsScalar(next[center_center], prev[center_center], &diff, &min, &max);

            // Check the diagonals of the current frame.
            checkBetterNeighorsScalar(current[top_left], current[bottom_right], &diff, &min, &max);
            checkBetterNeighorsScalar(current[top_right], current[bottom_left], &diff, &min, &max);

            // Check the vertical of the current frame.
            checkBetterNeighorsScalar(current[top_center], current[bottom_center], &diff, &min, &max);

            // if !norow
            checkBetterNeighorsScalar(current[center_left], current[center_right], &diff, &min, &max);

            const result = std.math.clamp(current[center_center], min, max);

            return limitPixelCorrectionScalar(current[center_center], result, limit, pixel_min, pixel_max);
        }

        fn processPlaneScalar(comptime mode: u8, srcp: [3][]const T, dstp: []T, width: u32, height: u32, stride: u32, limit: T, pixel_min: T, pixel_max: T) void {

            // Copy the first line
            @memcpy(dstp[0..width], srcp[1][0..width]);

            for (1..height - 1) |row| {
                // Copy the pixel at the beginning of the line.
                dstp[(row * stride)] = srcp[1][(row * stride)];

                for (1..width - 1) |column| {
                    const current_pixel = row * stride + column;

                    // Load pixels in 3x3 block from previous frame.
                    const prev = [9]T{
                        // Previous line
                        srcp[0][current_pixel - stride - 1],
                        srcp[0][current_pixel - stride],
                        srcp[0][current_pixel - stride + 1],

                        // Current line
                        srcp[0][current_pixel - 1],
                        srcp[0][current_pixel],
                        srcp[0][current_pixel + 1],

                        // Next line
                        srcp[0][current_pixel + stride - 1],
                        srcp[0][current_pixel + stride],
                        srcp[0][current_pixel + stride + 1],
                    };

                    // Load pixels in 3x3 block from current frame.
                    const current = [9]T{
                        // Previous line
                        srcp[1][current_pixel - stride - 1],
                        srcp[1][current_pixel - stride],
                        srcp[1][current_pixel - stride + 1],

                        // Current line
                        srcp[1][current_pixel - 1],
                        srcp[1][current_pixel],
                        srcp[1][current_pixel + 1],

                        // Next line
                        srcp[1][current_pixel + stride - 1],
                        srcp[1][current_pixel + stride],
                        srcp[1][current_pixel + stride + 1],
                    };

                    // Load pixels in 3x3 block from next frame.
                    const next = [9]T{
                        // Previous line
                        srcp[2][current_pixel - stride - 1],
                        srcp[2][current_pixel - stride],
                        srcp[2][current_pixel - stride + 1],

                        // Current line
                        srcp[2][current_pixel - 1],
                        srcp[2][current_pixel],
                        srcp[2][current_pixel + 1],

                        // Next line
                        srcp[2][current_pixel + stride - 1],
                        srcp[2][current_pixel + stride],
                        srcp[2][current_pixel + stride + 1],
                    };

                    dstp[current_pixel] = switch (mode) {
                        0 => mode0Scalar(prev, current, next, limit, pixel_min, pixel_max),
                        else => unreachable,
                    };
                }

                // Copy the pixel at the end of the line.
                dstp[(row * stride) + (width - 1)] = srcp[1][(row * stride) + (width - 1)];
            }

            // Copy the last line
            const lastLine = ((height - 1) * stride);
            @memcpy(dstp[lastLine..], srcp[1][lastLine..(lastLine + width)]);
        }
        //
        // fn processPlaneVector(comptime diameter: u8, srcp: [][]const T, dstp: []T, width: usize, height: usize, stride: usize) void {
        //     const width_simd = width / vec_size * vec_size;
        //
        //     for (0..height) |row| {
        //         var column: usize = 0;
        //         while (column < width_simd) : (column += vec_size) {
        //             const offset = row * stride + column;
        //             medianVector(diameter, srcp, dstp, offset);
        //         }
        //
        //         // If the video width is not perfectly aligned with the vector width, do one
        //         // last operation at the end of the plane to cover what's leftover from the loop above.
        //         if (width_simd < width) {
        //             medianVector(diameter, srcp, dstp, (row * stride) + width - vec_size);
        //         }
        //     }
        // }
        //
        // test "processPlane should find the median value" {
        //     const height = 2;
        //     const width = 56;
        //     const stride = width + 8 + 32;
        //     const size = height * stride;
        //
        //     const radius = 4;
        //     const diameter = radius * 2 + 1;
        //     const expectedMedian = ([_]T{radius + 1} ** size)[0..];
        //
        //     var src: [diameter][]const T = undefined;
        //     for (0..diameter) |i| {
        //         const frame = try testingAllocator.alloc(T, size);
        //         @memset(frame, cmn.lossyCast(T, i + 1));
        //
        //         src[i] = frame;
        //     }
        //     defer {
        //         for (0..diameter) |i| {
        //             testingAllocator.free(src[i]);
        //         }
        //     }
        //
        //     const dstp_scalar = try testingAllocator.alloc(T, size);
        //     const dstp_vec = try testingAllocator.alloc(T, size);
        //     defer testingAllocator.free(dstp_scalar);
        //     defer testingAllocator.free(dstp_vec);
        //
        //     processPlaneScalar(diameter, &src, dstp_scalar, width, height, stride);
        //     processPlaneVector(diameter, &src, dstp_vec, width, height, stride);
        //
        //     for (0..height) |row| {
        //         const start = row * stride;
        //         const end = start + width;
        //         try testing.expectEqualDeep(expectedMedian[start..end], dstp_scalar[start..end]);
        //         try testing.expectEqualDeep(expectedMedian[start..end], dstp_vec[start..end]);
        //     }
        // }

        pub fn getFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
            // Assign frame_data to nothing to stop compiler complaints
            _ = frame_data;

            const d: *DegrainMedianData = @ptrCast(@alignCast(instance_data));

            if (activation_reason == ar.Initial) {
                // Request previous, current, and next frames.
                vsapi.?.requestFrameFilter.?(@max(0, n - 1), d.node, frame_ctx);
                vsapi.?.requestFrameFilter.?(n, d.node, frame_ctx);
                vsapi.?.requestFrameFilter.?(@min(n + 1, d.vi.numFrames - 1), d.node, frame_ctx);
            } else if (activation_reason == ar.AllFramesReady) {
                // Skip filtering on the first and last frames that lie inside the filter radius,
                // since we do not have enough information to filter them properly.
                if (n == 0 or n == d.vi.numFrames - 1) {
                    return vsapi.?.getFrameFilter.?(n, d.node, frame_ctx);
                }

                const src_frames = [3]?*const vs.Frame{
                    vsapi.?.getFrameFilter.?(n - 1, d.node, frame_ctx),
                    vsapi.?.getFrameFilter.?(n, d.node, frame_ctx),
                    vsapi.?.getFrameFilter.?(n + 1, d.node, frame_ctx),
                };
                defer for (0..3) |i| vsapi.?.freeFrame.?(src_frames[i]);

                const dst = vscmn.newVideoFrame(&d.process, src_frames[1], d.vi, core, vsapi);

                for (0..3) |_plane| {
                    const plane: c_int = @intCast(_plane);

                    // Skip planes we aren't supposed to process
                    if (!d.process[_plane]) {
                        continue;
                    }

                    const width: u32 = @intCast(vsapi.?.getFrameWidth.?(dst, plane));
                    const height: u32 = @intCast(vsapi.?.getFrameHeight.?(dst, plane));
                    const stride: u32 = @as(u32, @intCast(vsapi.?.getStride.?(dst, plane))) / @sizeOf(T);

                    const srcp = [3][]const T{
                        @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[0], plane))))[0..(height * stride)],
                        @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[1], plane))))[0..(height * stride)],
                        @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[2], plane))))[0..(height * stride)],
                    };
                    const dstp: []T = @as([*]T, @ptrCast(@alignCast(vsapi.?.getWritePtr.?(dst, plane))))[0..(height * stride)];

                    const pixel_max = cmn.getFormatMaximum(T, d.vi.format, _plane > 0);
                    const pixel_min = cmn.getFormatMinimum(T, d.vi.format, _plane > 0);

                    switch (d.mode[_plane]) {
                        inline 0...5 => |m| processPlaneScalar(m, srcp, dstp, width, height, stride, cmn.lossyCast(T, d.limit[_plane]), pixel_min, pixel_max),
                        else => unreachable,
                    }
                }

                return dst;
            }

            return null;
        }
    };
}

export fn degrainMedianFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *DegrainMedianData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn degrainMedianCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    var d: DegrainMedianData = undefined;
    var err: vs.MapPropertyError = undefined;

    d.node = vsapi.?.mapGetNode.?(in, "clip", 0, &err).?;
    d.vi = vsapi.?.getVideoInfo.?(d.node);

    if (!vsh.isConstantVideoFormat(d.vi) or
        (d.vi.format.colorFamily != vs.ColorFamily.YUV and
        d.vi.format.colorFamily != vs.ColorFamily.RGB and
        d.vi.format.colorFamily != vs.ColorFamily.Gray))
    {
        return vscmn.reportError("DegrainMedian: only constant format YUV, RGB or Grey input is supported", vsapi, out, d.node);
    }

    const scalep = vsh.mapGetN(bool, in, "scalep", 0, vsapi) orelse false;

    const num_limits = vsapi.?.mapNumElements.?(in, "limit");
    if (num_limits > d.vi.format.numPlanes) {
        return vscmn.reportError("DegrainMedian: limit has more elements than there are planes.", vsapi, out, d.node);
    }

    d.limit = [3]f32{ 4, 4, 4 };

    for (0..3) |i| {
        if (vsh.mapGetN(f32, in, "limit", @intCast(i), vsapi)) |_limit| {
            if (scalep and (_limit < 0 or _limit > 255)) {
                return vscmn.reportError(cmn.printf(allocator, "DegrainMedian: Using parameter scaling (scalep), but limit value of {d} is outside the range of 0-255", .{_limit}), vsapi, out, d.node);
            }

            const limit = if (scalep)
                cmn.scaleToFormat(f32, d.vi.format, @intFromFloat(_limit), 0)
            else
                _limit;

            const formatMaximum = cmn.getFormatMaximum(f32, d.vi.format, i > 0);
            const formatMinimum = cmn.getFormatMinimum(f32, d.vi.format, i > 0);

            if ((limit < formatMinimum or limit > formatMaximum)) {
                return vscmn.reportError(cmn.printf(allocator, "DegrainMedian: Index {d} limit '{d}' must be between {d} and {d} (inclusive)", .{ i, limit, formatMinimum, formatMaximum }), vsapi, out, d.node);
            }

            d.limit[i] = limit;
        } else {
            // No limit specified for this plane
            if (i > 0) {
                d.limit[i] = d.limit[i - 1];
            }
        }
    }

    if (d.limit[0] == 0 and d.limit[1] == 0 and d.limit[2] == 0) {
        return vscmn.reportError("DegrainMedian: All limits cannot be 0.", vsapi, out, d.node);
    }

    d.process = [_]bool{
        d.limit[0] > 0,
        d.limit[1] > 0,
        d.limit[2] > 0,
    };

    const num_modes = vsapi.?.mapNumElements.?(in, "mode");
    if (num_modes > d.vi.format.numPlanes) {
        return vscmn.reportError("DegrainMedian: mode has more elements than there are planes.", vsapi, out, d.node);
    }

    d.mode = [3]u8{ 1, 1, 1 };

    for (0..3) |i| {
        if (vsh.mapGetN(i32, in, "mode", @intCast(i), vsapi)) |mode| {
            if (mode < 0 or mode > 5) {
                return vscmn.reportError("DegrainMedian: Mode cannot be less than 0 or greater than 5.", vsapi, out, d.node);
            }
            d.mode[i] = @intCast(mode);
        } else {
            // No mode specified for this plane.
            if (i > 0) {
                d.mode[i] = d.mode[i - 1];
            }
        }
    }

    const data: *DegrainMedianData = allocator.create(DegrainMedianData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.General,
        },
    };

    const getFrame = switch (d.vi.format.bytesPerSample) {
        1 => &DegrainMedian(u8).getFrame,
        2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &DegrainMedian(u16).getFrame else &DegrainMedian(f16).getFrame,
        4 => &DegrainMedian(f32).getFrame,
        else => unreachable,
    };

    vsapi.?.createVideoFilter.?(out, "DegrainMedian", d.vi, getFrame, degrainMedianFree, fm.Parallel, &deps, deps.len, data, core);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    //TODO: rename norow to incrow, and flip the meaning.
    _ = vsapi.registerFunction.?("DegrainMedian", "clip:vnode;limit:float[]:opt;mode:int[]:opt;interlaced:int:opt;norow:int:opt;scalep:int:opt", "clip:vnode;", degrainMedianCreate, null, plugin);
}
