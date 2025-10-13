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

const FluxSmoothMode = enum {
    Temporal,
    SpatialTemporal,
};

const FluxSmoothData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    vi: *const vs.VideoInfo,

    temporal_threshold: [3]f32,
    spatial_threshold: [3]f32,

    process: [3]bool,

    mode: FluxSmoothMode,
};

fn FluxSmooth(comptime T: type, comptime mode: FluxSmoothMode) type {
    return struct {
        const SAT = types.SignedArithmeticType(T);
        const UAT = types.UnsignedArithmeticType(T);

        fn processPlaneTemporalScalar(srcp: [3][]const T, noalias dstp: []T, width: usize, height: usize, stride: usize, threshold: T) void {
            for (0..height) |row| {
                for (0..width) |column| {
                    const current_pixel = row * stride + column;

                    const prev = srcp[0][current_pixel];
                    const curr = srcp[1][current_pixel];
                    const next = srcp[2][current_pixel];

                    dstp[current_pixel] = fluxsmoothTemporalScalar(prev, curr, next, threshold);
                }
            }
        }

        fn fluxsmoothTemporalScalar(prev: T, curr: T, next: T, threshold: T) T {
            @setFloatMode(float_mode);

            // If both pixels from the corresponding previous and next frames
            // are *brighter* or both are *darker*, then filter.
            if ((prev < curr and next < curr) or (prev > curr and next > curr)) {
                if (types.isInt(T)) {
                    const prevdiff = math.absDiff(prev, curr);
                    const nextdiff = math.absDiff(next, curr);

                    // Turns out picking the types on
                    // these can have a major impact on performance.
                    // Using u8, u16, u32, etc has better performance
                    // than u10, u2, etc.
                    // *and* picking the smallest possible byte-sized type
                    // leads to the best performance.
                    var sum: UAT = curr;
                    var count: u8 = 1;

                    if (prevdiff <= threshold) {
                        sum += prev;
                        count += 1;
                    }

                    if (nextdiff <= threshold) {
                        sum += next;
                        count += 1;
                    }

                    // The sum is multiplied by 2 so that the division is always by an even number,
                    // thus rounding can always be done by adding half the divisor

                    // This is fast
                    // return @intCast((sum * 2 + count) / (count * 2));
                    // (uint8_t)(sum / (float)count + 0.5f);

                    // But this is even faster.
                    // TODO: Test on desktop as well.
                    // The performance is basically identical, maybe even faster
                    // than my own vectorized version.
                    return @intFromFloat((@as(f32, @floatFromInt(sum)) / @as(f32, @floatFromInt(count)) + 0.5));
                } else {
                    // Floating point
                    const prevdiff = prev - curr;
                    const nextdiff = next - curr;

                    var sum: UAT = curr;
                    var count: T = 1;

                    if (@abs(prevdiff) <= threshold) {
                        sum += prev;
                        count += 1;
                    }

                    if (@abs(nextdiff) <= threshold) {
                        sum += next;
                        count += 1;
                    }

                    return sum / count;
                }
            } else {
                return curr;
            }
        }

        test fluxsmoothTemporalScalar {
            const threshold: T = 99;

            // Pixels are not both darker or ligher, so pixel stays the same.
            try std.testing.expectEqual(1, fluxsmoothTemporalScalar(0, 1, 2, threshold));

            if (types.isInt(T)) {
                // Both pixels darker.
                try std.testing.expectEqual(4, fluxsmoothTemporalScalar(1, 11, 1, threshold));
                // Test rounding
                try std.testing.expectEqual(5, fluxsmoothTemporalScalar(1, 11, 2, threshold));

                // Both pixels brighter
                try std.testing.expectEqual(4, fluxsmoothTemporalScalar(10, 1, 2, threshold));
                // Test rounding
                try std.testing.expectEqual(5, fluxsmoothTemporalScalar(10, 1, 3, threshold));
            } else {
                // Both pixels darker.
                try std.testing.expectApproxEqAbs(4.33, fluxsmoothTemporalScalar(1, 11, 1, threshold), 0.01);
                try std.testing.expectApproxEqAbs(4.66, fluxsmoothTemporalScalar(1, 11, 2, threshold), 0.01);

                // Both pixels brigher.
                try std.testing.expectApproxEqAbs(4.33, fluxsmoothTemporalScalar(10, 1, 2, threshold), 0.01);
                try std.testing.expectApproxEqAbs(4.66, fluxsmoothTemporalScalar(10, 1, 3, threshold), 0.01);
            }
        }

        fn processPlaneTemporalVector(srcp: [3][]const T, noalias dstp: []T, width: usize, height: usize, stride: usize, threshold: T) void {
            const vec_size = vec.getVecSize(T);
            const width_simd = width / vec_size * vec_size;

            for (0..height) |row| {
                var x: usize = 0;
                while (x < width_simd) : (x += vec_size) {
                    const offset = row * stride + x;
                    fluxsmoothTVector(srcp, dstp, offset, threshold);
                }

                if (width_simd < width) {
                    fluxsmoothTVector(srcp, dstp, (row * stride) + width - vec_size, threshold);
                }
            }
        }

        // TODO: F16 is still slow (of course)
        // so try processing as f32.
        fn fluxsmoothTVector(srcp: [3][]const T, noalias dstp: []T, offset: usize, _threshold: T) void {
            @setFloatMode(float_mode);

            const vec_size = vec.getVecSize(T);
            const VecType = @Vector(vec_size, T);

            const zeroes: VecType = @splat(0);
            const ones: VecType = @splat(1);
            const threshold: VecType = @splat(_threshold);
            const prev = vec.load(VecType, srcp[0], offset);
            const curr = vec.load(VecType, srcp[1], offset);
            const next = vec.load(VecType, srcp[2], offset);

            // So this works surprisingly well.
            // Request one cache line ahead to start retrieving data before we need it.
            // Need to test this on other architectures, but it leads to a pretty signifcant speedup,
            // like going from around 430-450 fps to 480-500 fps.
            // @prefetch(srcp[0].ptr + offset + 64, .{ .locality = 2 });
            // @prefetch(srcp[1].ptr + offset + 64, .{ .locality = 2 });
            // @prefetch(srcp[2].ptr + offset + 64, .{ .locality = 2 });

            //if ((prev < curr and next < curr) or (prev > curr and next > curr))
            //
            // const prevnextless = (prev < curr) & (next < curr);
            // const prevnextmore = (prev > curr) & (next > curr);
            // const mask_either = prevnextless | prevnextmore;
            // The above should work (or using `and` instead of `&`)
            // but Zig has a known bug preventing its use:
            // https://github.com/ziglang/zig/issues/14306
            //
            // Workaround
            // (prev < curr and next < curr)
            // (prev > curr and next > curr)
            const prevnextless = vec.andB(prev < curr, next < curr);
            const prevnextmore = vec.andB(prev > curr, next > curr);

            // or
            const mask_either = vec.orB(prevnextless, prevnextmore);

            const prevabsdiff = math.absDiff(prev, curr);
            const nextabsdiff = math.absDiff(next, curr);

            var sum: @Vector(vec_size, UAT) = curr;
            var count = ones;

            // TODO: Try threshold > prevabsdiff to see if comparison makes a difference.
            // Seems about the same speed on laptop.
            sum += @select(T, prevabsdiff <= threshold, prev, zeroes);
            count += @select(T, prevabsdiff <= threshold, ones, zeroes);
            // sum += @select(T, threshold > prevabsdiff, prev, zeroes);
            // count += @select(T, threshold > prevabsdiff, ones, zeroes);

            sum += @select(T, nextabsdiff <= threshold, next, zeroes);
            count += @select(T, nextabsdiff <= threshold, ones, zeroes);
            // sum += @select(T, threshold > nextabsdiff, next, zeroes);
            // count += @select(T, threshold > nextabsdiff, ones, zeroes);

            const result: VecType = result: {
                if (types.isFloat(T)) {
                    break :result sum / count;
                }
                const sum_f: @Vector(vec_size, f32) = @floatFromInt(sum);
                const count_f: @Vector(vec_size, f32) = @floatFromInt(count);
                const round_f: @Vector(vec_size, f32) = @splat(0.5);

                break :result @intFromFloat((sum_f / count_f) + round_f);
            };

            const selected_result = @select(T, mask_either, result, curr);

            vec.store(VecType, dstp, offset, selected_result);
        }

        test fluxsmoothTVector {
            const threshold: T = 99;

            const size = vec.getVecSize(T);

            const prev = try testingAllocator.alloc(T, size);
            const curr = try testingAllocator.alloc(T, size);
            const next = try testingAllocator.alloc(T, size);
            const dstp = try testingAllocator.alloc(T, size);
            const expected = try testingAllocator.alloc(T, size);

            defer {
                testingAllocator.free(prev);
                testingAllocator.free(curr);
                testingAllocator.free(next);
                testingAllocator.free(dstp);
                testingAllocator.free(expected);
            }

            const srcp = [3][]const T{
                prev,
                curr,
                next,
            };

            // Pixels are not both darker or ligher, so pixel stays the same.
            @memset(prev, 0);
            @memset(curr, 1);
            @memset(next, 2);
            @memset(dstp, 0);
            @memset(expected, 1);
            fluxsmoothTVector(srcp, dstp, 0, threshold);
            try std.testing.expectEqualDeep(expected, dstp);

            // Both pixels darker.
            @memset(prev, 1);
            @memset(curr, 11);
            @memset(next, 1);
            @memset(dstp, 0);
            @memset(expected, if (types.isInt(T)) 4 else 13.0 / 3.0); // 4.33
            fluxsmoothTVector(srcp, dstp, 0, threshold);
            try std.testing.expectEqualDeep(expected, dstp);

            // Both pixels lighter.
            @memset(prev, 10);
            @memset(curr, 1);
            @memset(next, 2);
            @memset(dstp, 0);
            @memset(expected, if (types.isInt(T)) 4 else 13.0 / 3.0); // 4.33
            fluxsmoothTVector(srcp, dstp, 0, threshold);
            try std.testing.expectEqualDeep(expected, dstp);
        }

        fn processPlaneSpatialTemporalScalar(srcp: [3][]const T, noalias dstp: []T, width: usize, height: usize, stride: usize, temporal_threshold: SAT, spatial_threshold: SAT) void {
            // Copy the first line
            @memcpy(dstp, srcp[1][0..width]);

            for (1..height - 1) |row| {
                // Copy the pixel at the beginning of the line.
                dstp[(row * stride)] = srcp[1][(row * stride)];

                for (1..width - 1) |column| {
                    const current_pixel = row * stride + column;

                    const prev = srcp[0][current_pixel];
                    const curr = srcp[1][current_pixel];
                    const next = srcp[2][current_pixel];

                    const rowPrev = ((row - 1) * stride);
                    const rowCurr = ((row) * stride);
                    const rowNext = ((row + 1) * stride);

                    const neighbors = [_]T{
                        // Top 3 neighbors
                        srcp[1][rowPrev + column - 1],
                        srcp[1][rowPrev + column],
                        srcp[1][rowPrev + column + 1],

                        // Side neighbors
                        srcp[1][rowCurr + column - 1],
                        srcp[1][rowCurr + column + 1],

                        // Bottom 3 neighbors
                        srcp[1][rowNext + column - 1],
                        srcp[1][rowNext + column],
                        srcp[1][rowNext + column + 1],
                    };

                    dstp[current_pixel] = fluxsmoothSpatialTemporalScalar(prev, curr, next, neighbors, temporal_threshold, spatial_threshold);
                }

                // Copy the pixel at the end of the line.
                dstp[(row * stride) + (width - 1)] = srcp[1][(row * stride) + (width - 1)];
            }

            // Copy the last line.
            const lastLine = ((height - 1) * stride);
            @memcpy(dstp[lastLine..], srcp[1][lastLine..(lastLine + width)]);
        }

        // TODO: Add tests.
        fn fluxsmoothSpatialTemporalScalar(prev: T, curr: T, next: T, neighbors: [8]T, temporal_threshold: SAT, spatial_threshold: SAT) T {
            @setFloatMode(float_mode);

            if ((prev < curr and next < curr) or (prev > curr and next > curr)) {
                if (types.isInt(T)) {
                    const prevdiff = math.absDiff(prev, curr);
                    const nextdiff = math.absDiff(next, curr);

                    var sum: UAT = curr;
                    var count: u8 = 1;

                    if (prevdiff <= temporal_threshold) {
                        sum += prev;
                        count += 1;
                    }

                    if (nextdiff <= temporal_threshold) {
                        sum += next;
                        count += 1;
                    }

                    inline for (neighbors) |n| {
                        const diff = math.absDiff(n, curr);

                        if (diff <= spatial_threshold) {
                            sum += n;
                            count += 1;
                        }
                    }

                    // This is fast (faster than magic number rounding).
                    // return @intCast((sum * 2 + count) / (count * 2));
                    //dstp[x] = (uint8_t)(sum / (float)count + 0.5f);

                    // But this is faster.
                    return @intFromFloat((@as(f32, @floatFromInt(sum)) / @as(f32, @floatFromInt(count))) + 0.5);
                } else {
                    // Floating point
                    const prevdiff = prev - curr;
                    const nextdiff = next - curr;

                    var sum: UAT = curr;
                    var count: T = 1;

                    if (@abs(prevdiff) <= temporal_threshold) {
                        sum += prev;
                        count += 1;
                    }

                    if (@abs(nextdiff) <= temporal_threshold) {
                        sum += next;
                        count += 1;
                    }

                    inline for (neighbors) |n| {
                        if (@abs(n - curr) <= spatial_threshold) {
                            sum += n;
                            count += 1;
                        }
                    }

                    return sum / count;
                }
            } else {
                return curr;
            }
        }

        fn processPlaneSpatialTemporalVector(srcp: [3][]const T, noalias dstp: []T, width: usize, height: usize, stride: usize, temporal_threshold: anytype, spatial_threshold: anytype) void {
            const vec_size = vec.getVecSize(T);
            const width_simd = width / vec_size * vec_size;

            // Copy the first line
            @memcpy(dstp, srcp[1][0..width]);

            for (1..height - 1) |row| {
                var column: usize = 1;
                while (column < width_simd) : (column += vec_size) {
                    const offset = row * stride + column;
                    fluxsmoothSTVector(srcp, dstp, offset, stride, temporal_threshold, spatial_threshold);
                }

                if (width_simd < width) {
                    fluxsmoothSTVector(srcp, dstp, (row * stride) + width - vec_size, stride, temporal_threshold, spatial_threshold);
                }

                // Copy the first and last pixels.
                // We do this at the end in order to keep the vector
                // operations aligned. We just throw away 2 of the values.

                // Copy the pixel at the beginning of the line.
                dstp[(row * stride)] = srcp[1][(row * stride)];

                // Copy the pixel at the end of the line.
                dstp[(row * stride) + (width - 1)] = srcp[1][(row * stride) + (width - 1)];
            }

            // Copy the last line.
            const lastLine = ((height - 1) * stride);
            @memcpy(dstp[lastLine..], srcp[1][lastLine..(lastLine + width)]);
        }

        // TODO: Add tests for this function.
        fn fluxsmoothSTVector(srcp: [3][]const T, noalias dstp: []T, offset: usize, stride: usize, _temporal_threshold: anytype, _spatial_threshold: anytype) void {
            @setFloatMode(float_mode);

            const vec_size = vec.getVecSize(T);
            const VecType = @Vector(vec_size, T);

            const zeroes: VecType = @splat(0);
            const ones: VecType = @splat(1);
            const temporal_threshold: @Vector(vec_size, @TypeOf(_temporal_threshold)) = @splat(_temporal_threshold);
            const spatial_threshold: @Vector(vec_size, @TypeOf(_spatial_threshold)) = @splat(_spatial_threshold);
            const prev = vec.load(VecType, srcp[0], offset);
            const curr = vec.load(VecType, srcp[1], offset);
            const next = vec.load(VecType, srcp[2], offset);

            const rowPrev = offset - stride;
            const rowCurr = offset;
            const rowNext = offset + stride;

            const neighbors = [_]VecType{
                vec.load(VecType, srcp[1], rowPrev - 1),
                vec.load(VecType, srcp[1], rowPrev),
                vec.load(VecType, srcp[1], rowPrev + 1),

                vec.load(VecType, srcp[1], rowCurr - 1),
                vec.load(VecType, srcp[1], rowCurr + 1),

                vec.load(VecType, srcp[1], rowNext - 1),
                vec.load(VecType, srcp[1], rowNext),
                vec.load(VecType, srcp[1], rowNext + 1),
            };

            //if ((prev < curr and next < curr) or (prev > curr and next > curr))
            // (prev < curr and next < curr)
            // (prev > curr and next > curr)
            const prevnextless = vec.andB(prev < curr, next < curr);
            const prevnextmore = vec.andB(prev > curr, next > curr);

            // or
            const mask_either = vec.orB(prevnextless, prevnextmore);

            const prevabsdiff = math.absDiff(prev, curr);
            const nextabsdiff = math.absDiff(next, curr);

            var sum: @Vector(vec_size, UAT) = curr;
            var count = ones;

            // if prevabsdiff <= temporal_threshold; sum += prev; count += 1;
            sum += @select(T, prevabsdiff <= temporal_threshold, prev, zeroes);
            count += @select(T, prevabsdiff <= temporal_threshold, ones, zeroes);

            // if nextabsdiff <= temporal_threshold; sum += next; count += 1;
            sum += @select(T, nextabsdiff <= temporal_threshold, next, zeroes);
            count += @select(T, nextabsdiff <= temporal_threshold, ones, zeroes);

            // if neighbor <= neighbor_threshold; sum += neighbor; count += 1;
            inline for (neighbors) |n| {
                const nabsdiff = math.absDiff(n, curr);

                sum += @select(T, nabsdiff <= spatial_threshold, n, zeroes);
                count += @select(T, nabsdiff <= spatial_threshold, ones, zeroes);
            }

            const result: VecType = result: {
                if (types.isFloat(T)) {
                    break :result sum / count;
                }
                // Float division is *much* faster than integer division
                // in SIMD.
                const sum_f: @Vector(vec_size, f32) = @floatFromInt(sum);
                const count_f: @Vector(vec_size, f32) = @floatFromInt(count);
                const round_f: @Vector(vec_size, f32) = @splat(0.5);

                break :result @intFromFloat((sum_f / count_f) + round_f);
            };

            const selected_result = @select(T, mask_either, result, curr);

            vec.store(VecType, dstp, offset, selected_result);
        }

        fn processPlane(temporal_threshold: f32, spatial_threshold: f32, noalias dstp8: []u8, srcp8: [3][]const u8, width: usize, height: usize, stride8: usize) void {
            const stride = stride8 / @sizeOf(T);
            const srcp: [3][]const T = .{
                @ptrCast(@alignCast(srcp8[0])),
                @ptrCast(@alignCast(srcp8[1])),
                @ptrCast(@alignCast(srcp8[2])),
            };
            const dstp: []T = @ptrCast(@alignCast(dstp8));

            switch (mode) {
                .Temporal => processPlaneTemporalVector(srcp, dstp, width, height, stride, math.lossyCast(T, temporal_threshold)),
                .SpatialTemporal => {
                    // We can produce faster code if we know that a given threshold is
                    // greater then -1, since we can use unsigned types.
                    // This picks the optimal function based on the threshold values.
                    if (temporal_threshold >= 0 and spatial_threshold >= 0) {
                        processPlaneSpatialTemporalVector(srcp, dstp, width, height, stride, math.lossyCast(T, temporal_threshold), math.lossyCast(T, spatial_threshold));
                    } else if (spatial_threshold >= 0) {
                        processPlaneSpatialTemporalVector(srcp, dstp, width, height, stride, math.lossyCast(SAT, temporal_threshold), math.lossyCast(T, spatial_threshold));
                    } else {
                        processPlaneSpatialTemporalVector(srcp, dstp, width, height, stride, math.lossyCast(SAT, temporal_threshold), math.lossyCast(SAT, spatial_threshold));
                    }
                },
            }
        }
    };
}

fn fluxSmoothGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const zapi = ZAPI.init(vsapi, core, frame_ctx);
    const d: *FluxSmoothData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        if (n == 0 or n == d.vi.numFrames - 1) {
            zapi.requestFrameFilter(n, d.node);
        } else {
            zapi.requestFrameFilter(n - 1, d.node);
            zapi.requestFrameFilter(n, d.node);
            zapi.requestFrameFilter(n + 1, d.node);
        }
    } else if (activation_reason == ar.AllFramesReady) {
        // Skip filtering on the first and last frames,
        // since we do not have enough information to filter them properly.
        if (n == 0 or n == d.vi.numFrames - 1) {
            return zapi.getFrameFilter(n, d.node);
        }

        const src_frames = [3]ZAPI.ZFrame(*const vs.Frame){
            zapi.initZFrame(d.node, n - 1),
            zapi.initZFrame(d.node, n),
            zapi.initZFrame(d.node, n + 1),
        };
        defer for (src_frames) |frame| frame.deinit();

        const dst = src_frames[1].newVideoFrame2(d.process);

        const processPlane = if (d.mode == .Temporal) switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &FluxSmooth(u8, .Temporal).processPlane,
            .U16 => &FluxSmooth(u16, .Temporal).processPlane,
            .F16 => &FluxSmooth(f16, .Temporal).processPlane,
            .F32 => &FluxSmooth(f32, .Temporal).processPlane,
        } else switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &FluxSmooth(u8, .SpatialTemporal).processPlane,
            .U16 => &FluxSmooth(u16, .SpatialTemporal).processPlane,
            .F16 => &FluxSmooth(f16, .SpatialTemporal).processPlane,
            .F32 => &FluxSmooth(f32, .SpatialTemporal).processPlane,
        };

        for (0..@intCast(d.vi.format.numPlanes)) |plane| {
            // Skip planes we aren't supposed to process
            if (!d.process[plane]) {
                continue;
            }

            const width = dst.getWidth(plane);
            const height = dst.getHeight(plane);
            const stride8 = dst.getStride(plane);

            const srcp8 = [3][]const u8{
                src_frames[0].getReadSlice(plane),
                src_frames[1].getReadSlice(plane),
                src_frames[2].getReadSlice(plane),
            };

            const dstp8: []u8 = dst.getWriteSlice(plane);

            processPlane(d.temporal_threshold[plane], d.spatial_threshold[plane], dstp8, srcp8, width, height, stride8);
        }

        return dst.frame;
    }

    return null;
}

export fn fluxSmoothFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = core;
    const d: *FluxSmoothData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn fluxSmoothCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {

    const zapi = ZAPI.init(vsapi, core, null);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);

    var d: FluxSmoothData = undefined;
    d.mode = @as(*FluxSmoothMode, @ptrCast(user_data)).*;
    const func_name = if (d.mode == .Temporal) "FluxSmoothT" else "FluxSmoothST";

    d.node, d.vi = inz.getNodeVi("clip").?;

    if (!vsh.isConstantVideoFormat(d.vi)) {
        return vscmn.reportError2(string.printf(allocator, "{s}: only constant format input supported", .{func_name}), zapi, outz, d.node);
    }

    // Optional parameter scaling.
    const scalep = inz.getBool("scalep") orelse false;

    var temporal_threshold = [3]f32{ -1, -1, -1 };
    var spatial_threshold = [3]f32{ -1, -1, -1 };

    for (0..3) |i| {
        if (inz.getFloat2(f32, "temporal_threshold", i)) |threshold| {
            temporal_threshold[i] = if (scalep and threshold >= 0) thresh: {
                if (threshold < 0 or threshold > 255) {
                    return vscmn.reportError2(string.printf(allocator, "{s}: Using parameter scaling (scalep), but temporal_threshold of {d} is outside the range of 0-255", .{ func_name, threshold }), zapi, outz, d.node);
                }
                break :thresh vscmn.scaleToFormat(f32, d.vi.format, threshold, 0);
            } else threshold;
        } else {
            temporal_threshold[i] = if (i == 0)
                vscmn.scaleToFormat(f32, d.vi.format, 7, 0)
            else
                temporal_threshold[i - 1];
        }

        if (d.mode == .SpatialTemporal) {
            if (inz.getFloat2(f32, "spatial_threshold", i)) |threshold| {
                spatial_threshold[i] = if (scalep and threshold >= 0) thresh: {
                    if (threshold < 0 or threshold > 255) {
                        return vscmn.reportError2(string.printf(allocator, "{s}: Using parameter scaling (scalep), but spatial_threshold of {d} is outside the range of 0-255", .{ func_name, threshold }), zapi, outz, d.node);
                    }
                    break :thresh vscmn.scaleToFormat(f32, d.vi.format, threshold, 0);
                } else threshold;
            } else {
                spatial_threshold[i] = if (i == 0) vscmn.scaleToFormat(f32, d.vi.format, 7, 0) else spatial_threshold[i - 1];
            }
        }
    }

    const planes = vscmn.normalizePlanes(d.vi.format, in, vsapi) catch |e| {
        zapi.freeNode(d.node);

        switch (e) {
            vscmn.PlanesError.IndexOutOfRange => outz.setError(string.printf(allocator, "{s}: Plane index out of range.", .{func_name})),
            vscmn.PlanesError.SpecifiedTwice => outz.setError(string.printf(allocator, "{s}: Plane specified twice.", .{func_name})),
        }
        return;
    };

    d.temporal_threshold = temporal_threshold;
    d.spatial_threshold = spatial_threshold;
    d.process = [3]bool{
        planes[0] and (d.temporal_threshold[0] >= 0 or d.spatial_threshold[0] >= 0),
        planes[1] and (d.temporal_threshold[1] >= 0 or d.spatial_threshold[1] >= 0),
        planes[2] and (d.temporal_threshold[2] >= 0 or d.spatial_threshold[2] >= 0),

    };
    const data: *FluxSmoothData = allocator.create(FluxSmoothData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.General,
        },
    };

    zapi.createVideoFilter(out, func_name, d.vi, fluxSmoothGetFrame, fluxSmoothFree, fm.Parallel, &deps, data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("FluxSmoothT", "clip:vnode;temporal_threshold:float[]:opt;planes:int[]:opt;scalep:int:opt;", "clip:vnode;", fluxSmoothCreate, @ptrCast(@constCast(&FluxSmoothMode.Temporal)), plugin);
    _ = vsapi.registerFunction.?("FluxSmoothST", "clip:vnode;temporal_threshold:float[]:opt;spatial_threshold:float[]:opt;planes:int[]:opt;scalep:int:opt;", "clip:vnode;", fluxSmoothCreate, @ptrCast(@constCast(&FluxSmoothMode.SpatialTemporal)), plugin);
}
