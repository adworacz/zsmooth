const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;

const cmn = @import("common.zig");
const vscmn = @import("common/vapoursynth.zig");
const vec = @import("common/vector.zig");
const sort = @import("common/sorting_networks.zig");
const grid = @import("common/grid.zig");

const math = std.math;
const vs = vapoursynth.vapoursynth4;
const vsh = vapoursynth.vshelper;

const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;

const Grid = grid.Grid;

const allocator = std.heap.c_allocator;
const assert = std.debug.assert;

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
    const vector_len = vec.getVecSize(T);
    const VT = @Vector(vector_len, T);

    return struct {
        // Grid of scalar values
        const GridS = Grid(T);
        // Grid of vector values
        const GridV = Grid(VT);

        //TODO: Use a new generic (Kernel?) to remove the *anytype*s.

        /// Limits the change (difference) of a pixel to be no greater or less than limit,
        /// and no greater than pixel_max or less than pixel_min.
        // fn limitPixelCorrectionScalar(old_pixel: T, new_pixel: T, limit: T, pixel_min: T, pixel_max: T) T
        fn limitPixelCorrection(old_pixel: anytype, new_pixel: anytype, limit: anytype, pixel_min: anytype, pixel_max: anytype) @TypeOf(new_pixel) {
            const lower = if (cmn.isInt(T))
                // Integer formats never go below zero
                // so we an use saturating subtraction.
                old_pixel -| limit
            else
                // Float formats can go to -0.5, for YUV
                // so we clamp to pixel_min.
                @max(pixel_min, old_pixel - limit);

            const upper = if (cmn.isInt(T))
                // Using saturating addition to prevent integer overflow.
                @min(old_pixel +| limit, pixel_max)
            else
                @min(old_pixel + limit, pixel_max);

            return @max(lower, @min(new_pixel, upper));
        }

        test limitPixelCorrection {
            // New pixel is lesser - within limit
            try std.testing.expectEqual(8, limitPixelCorrection(10, 8, 3, 0, 255));
            try std.testing.expectEqual(@as(VT, @splat(8)), limitPixelCorrection(@as(VT, @splat(10)), @as(VT, @splat(8)), @as(VT, @splat(3)), @as(VT, @splat(0)), @as(VT, @splat(255))));

            // New pixel is lesser - beyond limit (clamped)
            try std.testing.expectEqual(9, limitPixelCorrection(10, 8, 1, 0, 255));
            try std.testing.expectEqual(@as(VT, @splat(9)), limitPixelCorrection(@as(VT, @splat(10)), @as(VT, @splat(8)), @as(VT, @splat(1)), @as(VT, @splat(0)), @as(VT, @splat(255))));

            // New pixel is lesser - below pixel_min (clamped)
            if (cmn.isFloat(T)) {
                try std.testing.expectEqual(9, limitPixelCorrection(10, 8, 255, 9, 255));
                try std.testing.expectEqual(@as(VT, @splat(9)), limitPixelCorrection(@as(VT, @splat(10)), @as(VT, @splat(8)), @as(VT, @splat(255)), @as(VT, @splat(9)), @as(VT, @splat(255))));
            }

            // New pixel is greater - within limit
            try std.testing.expectEqual(12, limitPixelCorrection(10, 12, 3, 0, 255));
            try std.testing.expectEqual(@as(VT, @splat(12)), limitPixelCorrection(@as(VT, @splat(10)), @as(VT, @splat(12)), @as(VT, @splat(3)), @as(VT, @splat(0)), @as(VT, @splat(255))));

            // New pixel is greater - beyond limit (clamped)
            try std.testing.expectEqual(11, limitPixelCorrection(10, 12, 1, 0, 255));
            try std.testing.expectEqual(@as(VT, @splat(11)), limitPixelCorrection(@as(VT, @splat(10)), @as(VT, @splat(12)), @as(VT, @splat(1)), @as(VT, @splat(0)), @as(VT, @splat(255))));

            // New pixel is greater - above pixel_max (clamped)
            try std.testing.expectEqual(11, limitPixelCorrection(10, 12, 255, 0, 11));
            try std.testing.expectEqual(@as(VT, @splat(11)), limitPixelCorrection(@as(VT, @splat(10)), @as(VT, @splat(12)), @as(VT, @splat(255)), @as(VT, @splat(0)), @as(VT, @splat(11))));
        }

        /// Computes the absolute difference of two pixels, and if the
        /// difference is less than the provided diff param, it updates
        /// the diff param, as well as the min and max params with their
        /// corresponding values of the two pixels.
        // fn checkBetterNeighorsScalar(a: T, b: T, diff: *T, min: *T, max: *T) void
        fn checkBetterNeighbors(a: anytype, b: anytype, diff: anytype, min: anytype, max: anytype) void {
            const newdiff = if (cmn.isFloat(T))
                @abs(a - b)
            else
                @max(a, b) - @min(a, b);

            if (cmn.isScalar(@TypeOf(a))) {
                // scalar
                if (newdiff <= diff.*) {
                    diff.* = newdiff;
                    min.* = @min(a, b);
                    max.* = @max(a, b);
                }
            } else {
                // vector
                diff.* = vec.minFast(newdiff, diff.*);
                min.* = @select(T, newdiff <= diff.*, @min(a, b), min.*);
                max.* = @select(T, newdiff <= diff.*, @max(a, b), max.*);
            }
        }

        test checkBetterNeighbors {
            var diff: T = 255;
            var diffV: VT = @splat(255);
            var max: T = 255;
            var maxV: VT = @splat(255);
            var min: T = 0;
            var minV: VT = @splat(0);

            checkBetterNeighbors(10, 7, &diff, &min, &max);
            checkBetterNeighbors(@as(VT, @splat(10)), @as(VT, @splat(7)), &diffV, &minV, &maxV);
            try std.testing.expectEqualDeep(.{ 3, 7, 10 }, .{ diff, min, max });
            try std.testing.expectEqualDeep(.{ @as(VT, @splat(3)), @as(VT, @splat(7)), @as(VT, @splat(10)) }, .{ diffV, minV, maxV });

            diff = 255;
            diffV = @splat(255);
            max = 255;
            maxV = @splat(255);
            min = 0;
            minV = @splat(0);

            // Ensure pixel value order doesn't matter, which ensures we use @abs
            checkBetterNeighbors(7, 10, &diff, &min, &max);
            checkBetterNeighbors(@as(VT, @splat(7)), @as(VT, @splat(10)), &diffV, &minV, &maxV);
            try std.testing.expectEqualDeep(.{ 3, 7, 10 }, .{ diff, min, max });
            try std.testing.expectEqualDeep(.{ @as(VT, @splat(3)), @as(VT, @splat(7)), @as(VT, @splat(10)) }, .{ diffV, minV, maxV });

            diff = 5;
            diffV = @splat(5);
            max = 255;
            maxV = @splat(255);
            min = 0;
            minV = @splat(0);

            // Ensure that if the difference is greater than diff param,
            // nothing gets updated.
            checkBetterNeighbors(0, 255, &diff, &min, &max);
            checkBetterNeighbors(@as(VT, @splat(0)), @as(VT, @splat(255)), &diffV, &minV, &maxV);
            try std.testing.expectEqualDeep(.{ 5, 0, 255 }, .{ diff, min, max });
            try std.testing.expectEqualDeep(.{ @as(VT, @splat(5)), @as(VT, @splat(0)), @as(VT, @splat(255)) }, .{ diffV, minV, maxV });
        }

        // fn mode0Scalar(prev: GridS, current: GridS, next: GridS, limit: T, pixel_min: T, pixel_max: T) T {
        fn mode0(prev: anytype, current: anytype, next: anytype, limit: anytype, pixel_min: anytype, pixel_max: anytype) @TypeOf(pixel_max) {
            const R = @TypeOf(pixel_max);
            var diff: R = pixel_max;
            var max: R = pixel_max;
            var min: R = if (cmn.isScalar(R)) 0 else @splat(0);

            // Check the diagonals of the temporal neighbors.
            checkBetterNeighbors(next.top_left, prev.bottom_right, &diff, &min, &max);
            checkBetterNeighbors(next.top_right, prev.bottom_left, &diff, &min, &max);
            checkBetterNeighbors(next.bottom_left, prev.top_right, &diff, &min, &max);
            checkBetterNeighbors(next.bottom_right, prev.top_left, &diff, &min, &max);

            // Check the verticals of the temporal neighbors.
            checkBetterNeighbors(next.bottom_center, prev.top_center, &diff, &min, &max);
            checkBetterNeighbors(next.top_center, prev.bottom_center, &diff, &min, &max);

            // Check the horizontals of the temporal neighbors.
            checkBetterNeighbors(next.center_left, prev.center_right, &diff, &min, &max);
            checkBetterNeighbors(next.center_right, prev.center_left, &diff, &min, &max);

            // Check the center of the temporal neighbors.
            checkBetterNeighbors(next.center_center, prev.center_center, &diff, &min, &max);

            // Check the diagonals of the current frame.
            checkBetterNeighbors(current.top_left, current.bottom_right, &diff, &min, &max);
            checkBetterNeighbors(current.top_right, current.bottom_left, &diff, &min, &max);

            // Check the vertical of the current frame.
            checkBetterNeighbors(current.top_center, current.bottom_center, &diff, &min, &max);

            // if !norow
            checkBetterNeighbors(current.center_left, current.center_right, &diff, &min, &max);

            const result = cmn.clamp(current.center_center, min, max);

            return limitPixelCorrection(current.center_center, result, limit, pixel_min, pixel_max);
        }

        fn processPlaneScalar(comptime mode: u8, srcp: [3][]const T, noalias dstp: []T, width: u32, height: u32, stride: u32, limit: T, pixel_min: T, pixel_max: T) void {
            // Copy the first line
            @memcpy(dstp[0..width], srcp[1][0..width]);

            for (1..height - 1) |row| {
                // Copy the pixel at the beginning of the line.
                dstp[(row * stride)] = srcp[1][(row * stride)];

                for (1..width - 1) |column| {
                    const current_pixel = row * stride + column;
                    // We're loading pixels from the top left of a 3x3 grid centered around
                    // the current pixel of interest.
                    //
                    // So we subtract the stride from the current pixel location to get the row
                    // above, and then subtract 1 to get the pixel in the top left, instead of the top center.
                    //
                    // All of this is to make loading from Grid.init easier.
                    const offset = current_pixel - stride - 1;

                    // Current LLVM prefetch implementation screws up the autovectorization
                    // of loops...
                    // https://discourse.llvm.org/t/rfc-loop-vectorization-for-builtin-prefetch/72234
                    // https://reviews.llvm.org/D156068
                    //
                    // @prefetch(srcp[0].ptr + offset + 64, .{ .locality = 1 });
                    // @prefetch(srcp[1].ptr + offset + 64, .{ .locality = 1 });
                    // @prefetch(srcp[2].ptr + offset + 64, .{ .locality = 1 });

                    // TODO: Move the current_pixel / offset calculations out of the here and up to
                    // a single variable.
                    const prev = GridS.init(T, srcp[0][offset..], stride);
                    const current = GridS.init(T, srcp[1][offset..], stride);
                    const next = GridS.init(T, srcp[2][offset..], stride);

                    dstp[current_pixel] = switch (mode) {
                        0 => mode0(prev, current, next, limit, pixel_min, pixel_max),
                        else => unreachable,
                    };
                }

                // Copy the pixel at the end of the line.
                dstp[(row * stride) + (width - 1)] = srcp[1][(row * stride) + (width - 1)];
            }

            // Copy the last line
            const lastLine = ((height - 1) * stride);
            const end = lastLine + width;
            @memcpy(dstp[lastLine..end], srcp[1][lastLine..end]);
        }

        fn processPlaneVector(comptime mode: u8, srcp: [3][]const T, noalias dstp: []T, width: u32, height: u32, stride: u32, _limit: T, _pixel_min: T, _pixel_max: T) void {
            // TODO: Consider replacing all uses of '1' with 'grid_radius', since
            // that's what it actually means.
            const grid_radius = comptime (3 / 2);
            // We need to make sure we don't read past the edge of the frame.
            // So we take into account the size of vector and the size of the grid we
            // need to load, and work backwards (subtract) from the overall frame size
            // to calculate a safe width.
            const width_simd = (width - grid_radius) / vector_len * vector_len;

            // TODO: Test if it's more performant to pass the scalar values to
            // mode0Vector instead. Likely won't matter due to inlining.
            const limit: VT = @splat(_limit);
            const pixel_min: VT = @splat(_pixel_min);
            const pixel_max: VT = @splat(_pixel_max);

            // Copy the first line
            @memcpy(dstp[0..width], srcp[1][0..width]);

            // These assertions honestly seems to lead to some nice speedups.
            // I'm seeing a difference of ~190 -> ~200fps, single core.
            // TODO: add checking in init.
            assert(width >= vector_len);
            assert(stride >= width);
            assert(stride % vector_len == 0);

            for (1..height - 1) |row| {
                // Copy the pixel at the beginning of the line.
                dstp[(row * stride)] = srcp[1][(row * stride)];

                var column: usize = 1;
                while (column < width_simd) : (column += vector_len) {
                    const current_pixel = row * stride + column;
                    // Target the offset at the pixel in the top left;
                    const grid_offset = current_pixel - stride - 1;

                    const prev = GridV.init(T, srcp[0][grid_offset..], stride);
                    const current = GridV.init(T, srcp[1][grid_offset..], stride);
                    const next = GridV.init(T, srcp[2][grid_offset..], stride);

                    // @prefetch(srcp[0].ptr + grid_offset + (vector_len * 2), .{ .locality = 3 });
                    // @prefetch(srcp[1].ptr + grid_offset + (vector_len * 2), .{ .locality = 3 });
                    // @prefetch(srcp[2].ptr + grid_offset + (vector_len * 2), .{ .locality = 3 });

                    const result = switch (mode) {
                        0 => mode0(prev, current, next, limit, pixel_min, pixel_max),
                        else => unreachable,
                    };

                    vec.store(VT, dstp, current_pixel, result);
                }

                // If the video width is not perfectly aligned with the vector width, do one
                // last operation at the end of the plane to cover what's leftover from the loop above.
                if (width_simd < width) {
                    const current_pixel = row * stride + width - vector_len - grid_radius;
                    // Target the offset at the pixel in the top left;
                    const grid_offset = current_pixel - stride - 1;

                    const prev = GridV.init(T, srcp[0][grid_offset..], stride);
                    const current = GridV.init(T, srcp[1][grid_offset..], stride);
                    const next = GridV.init(T, srcp[2][grid_offset..], stride);

                    const result = switch (mode) {
                        0 => mode0(prev, current, next, limit, pixel_min, pixel_max),
                        else => unreachable,
                    };

                    vec.store(VT, dstp, current_pixel, result);
                }

                // Copy the pixel at the end of the line.
                dstp[(row * stride) + (width - 1)] = srcp[1][(row * stride) + (width - 1)];
            }

            // Copy the last line
            const lastLine = ((height - 1) * stride);
            const end = lastLine + width;
            @memcpy(dstp[lastLine..end], srcp[1][lastLine..end]);
        }

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
                        // inline 0...5 => |m| processPlaneScalar(m, srcp, dstp, width, height, stride, cmn.lossyCast(T, d.limit[_plane]), pixel_min, pixel_max),
                        inline 0...5 => |m| processPlaneVector(m, srcp, dstp, width, height, stride, cmn.lossyCast(T, d.limit[_plane]), pixel_min, pixel_max),
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
