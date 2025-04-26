const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;

const string = @import("common/string.zig");
const types = @import("common/type.zig");
const math = @import("common/math.zig");
const vscmn = @import("common/vapoursynth.zig");
const vec = @import("common/vector.zig");

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
};

fn FluxSmooth(comptime T: type, comptime mode: FluxSmoothMode) type {
    return struct {
        /// Signed Arithmetic Type - used in signed arithmetic to safely hold
        /// the values (particularly integers) without overflowing when doing
        /// signed arithmetic.
        const SAT = switch (T) {
            u8 => i16,
            u16 => i32,
            f16 => f16, //TODO: This might be more performant as f32 on some systems.
            f32 => f32,
            else => unreachable,
        };

        /// Unsigned Arithmetic Type - used in unsigned arithmetic to safely
        /// hold values (particularly integers) without overflowing when doing
        /// unsigned arithmetic.
        const UAT = switch (T) {
            u8 => u16,
            u16 => u32,
            f16 => f16, //TODO: This might be more performant as f32 on some systems.
            f32 => f32,
            else => unreachable,
        };

        fn processPlaneTemporalScalar(srcp: [3][]const T, dstp: []T, width: usize, height: usize, stride: usize, threshold: T) void {
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
            // If both pixels from the corresponding previous and next frames
            // are *brighter* or both are *darker*, then filter.
            if ((prev < curr and next < curr) or (prev > curr and next > curr)) {
                if (types.isInt(T)) {
                    const prevdiff = @max(prev, curr) - @min(prev, curr);
                    const nextdiff = @max(next, curr) - @min(next, curr);

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

            // max-min is about same perf as saturating subtraction on laptop
            // TODO: Try on desktop.
            const prevabsdiff = if (types.isInt(T))
                @max(prev, curr) - @min(prev, curr)
            else
                @abs(prev - curr);

            const nextabsdiff = if (types.isInt(T))
                @max(next, curr) - @min(next, curr)
            else
                @abs(next - curr);

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

        fn processPlaneSpatialTemporalScalar(srcp: [3][]const T, dstp: []T, width: usize, height: usize, stride: usize, temporal_threshold: SAT, spatial_threshold: SAT) void {
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
            if ((prev < curr and next < curr) or (prev > curr and next > curr)) {
                if (types.isInt(T)) {
                    const prevdiff = @max(prev, curr) - @min(prev, curr);
                    const nextdiff = @max(next, curr) - @min(next, curr);

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
                        const diff = @max(n, curr) - @min(n, curr);

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

        fn processPlaneSpatialTemporalVector(srcp: [3][]const T, dstp: []T, width: usize, height: usize, stride: usize, temporal_threshold: anytype, spatial_threshold: anytype) void {
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
        fn fluxsmoothSTVector(srcp: [3][]const T, dstp: []T, offset: usize, stride: usize, _temporal_threshold: anytype, _spatial_threshold: anytype) void {
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

            // TODO: commonize this absdiff logic, and support
            // scalars and vectors.
            const prevabsdiff = if (types.isInt(T))
                @max(prev, curr) - @min(prev, curr)
            else
                @abs(prev - curr);

            const nextabsdiff = if (types.isInt(T))
                @max(next, curr) - @min(next, curr)
            else
                @abs(next - curr);

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
                const nabsdiff = if (types.isInt(T))
                    @max(n, curr) - @min(n, curr)
                else
                    @abs(n - curr);

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

        pub fn getFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
            // Assign frame_data to nothing to stop compiler complaints
            _ = frame_data;

            const d: *FluxSmoothData = @ptrCast(@alignCast(instance_data));

            if (activation_reason == ar.Initial) {
                if (n == 0 or n == d.vi.numFrames - 1) {
                    vsapi.?.requestFrameFilter.?(n, d.node, frame_ctx);
                } else {
                    vsapi.?.requestFrameFilter.?(n - 1, d.node, frame_ctx);
                    vsapi.?.requestFrameFilter.?(n, d.node, frame_ctx);
                    vsapi.?.requestFrameFilter.?(n + 1, d.node, frame_ctx);
                }
            } else if (activation_reason == ar.AllFramesReady) {
                // Skip filtering on the first and last frames,
                // since we do not have enough information to filter them properly.
                if (n == 0 or n == d.vi.numFrames - 1) {
                    return vsapi.?.getFrameFilter.?(n, d.node, frame_ctx);
                }

                const src_frames = [3]?*const vs.Frame{
                    vsapi.?.getFrameFilter.?(n - 1, d.node, frame_ctx),
                    vsapi.?.getFrameFilter.?(n, d.node, frame_ctx),
                    vsapi.?.getFrameFilter.?(n + 1, d.node, frame_ctx),
                };
                defer for (&src_frames) |frame| vsapi.?.freeFrame.?(frame);

                const dst = vscmn.newVideoFrame(&d.process, src_frames[1], d.vi, core, vsapi);

                for (0..@intCast(d.vi.format.numPlanes)) |_plane| {
                    const plane: c_int = @intCast(_plane);

                    // Skip planes we aren't supposed to process
                    if (!d.process[_plane]) {
                        continue;
                    }

                    const width: usize = @intCast(vsapi.?.getFrameWidth.?(dst, plane));
                    const height: usize = @intCast(vsapi.?.getFrameHeight.?(dst, plane));
                    const stride: usize = @as(usize, @intCast(vsapi.?.getStride.?(dst, plane))) / @sizeOf(T);

                    const srcp = [3][]const T{
                        @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[0], plane))))[0..(height * stride)],
                        @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[1], plane))))[0..(height * stride)],
                        @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[2], plane))))[0..(height * stride)],
                    };

                    const dstp: []T = @as([*]T, @ptrCast(@alignCast(vsapi.?.getWritePtr.?(dst, plane))))[0..(height * stride)];

                    switch (mode) {
                        // .Temporal => processPlaneTemporalScalar(srcp, dstp, width, height, math.lossyCast(T, temporal_threshold)),
                        .Temporal => processPlaneTemporalVector(srcp, dstp, width, height, stride, math.lossyCast(T, d.temporal_threshold[_plane])),
                        .SpatialTemporal => {
                            // We can produce faster code if we know that a given threshold is
                            // greater then -1, since we can use unsigned types.
                            // This picks the optimal function based on the threshold values.
                            if (d.temporal_threshold[_plane] >= 0 and d.spatial_threshold[_plane] >= 0) {
                                processPlaneSpatialTemporalVector(srcp, dstp, width, height, stride, math.lossyCast(T, d.temporal_threshold[_plane]), math.lossyCast(T, d.spatial_threshold[_plane]));
                            } else if (d.spatial_threshold[_plane] >= 0) {
                                processPlaneSpatialTemporalVector(srcp, dstp, width, height, stride, math.lossyCast(SAT, d.temporal_threshold[_plane]), math.lossyCast(T, d.spatial_threshold[_plane]));
                            } else {
                                processPlaneSpatialTemporalVector(srcp, dstp, width, height, stride, math.lossyCast(SAT, d.temporal_threshold[_plane]), math.lossyCast(SAT, d.spatial_threshold[_plane]));
                            }
                        },
                    }
                }

                return dst;
            }

            return null;
        }
    };
}

export fn fluxSmoothFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *FluxSmoothData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn fluxSmoothCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    const mode: FluxSmoothMode = @as(*FluxSmoothMode, @ptrCast(user_data)).*;

    var d: FluxSmoothData = undefined;
    var err: vs.MapPropertyError = undefined;
    const func_name = if (mode == .Temporal) "FluxSmoothT" else "FluxSmoothST";

    d.node = vsapi.?.mapGetNode.?(in, "clip", 0, &err).?;
    d.vi = vsapi.?.getVideoInfo.?(d.node);

    if (!vsh.isConstantVideoFormat(d.vi)) {
        vsapi.?.mapSetError.?(out, string.printf(allocator, "{s}: only constant format input supported", .{func_name}).ptr);
        vsapi.?.freeNode.?(d.node);
        return;
    }

    // Optional parameter scaling.
    const scalep = vsh.mapGetN(bool, in, "scalep", 0, vsapi) orelse false;

    var temporal_threshold = [3]f32{ -1, -1, -1 };
    var spatial_threshold = [3]f32{ -1, -1, -1 };

    for (0..3) |i| {
        if (vsh.mapGetN(f32, in, "temporal_threshold", @intCast(i), vsapi)) |threshold| {
            temporal_threshold[i] = if (scalep and threshold >= 0) thresh: {
                if (threshold < 0 or threshold > 255) {
                    vsapi.?.mapSetError.?(out, string.printf(allocator, "{s}: Using parameter scaling (scalep), but temporal_threshold of {d} is outside the range of 0-255", .{ func_name, threshold }).ptr);
                    vsapi.?.freeNode.?(d.node);
                    return;
                }
                break :thresh vscmn.scaleToFormat(f32, d.vi.format, threshold, 0);
            } else threshold;
        } else {
            temporal_threshold[i] = if (i == 0)
                vscmn.scaleToFormat(f32, d.vi.format, 7, 0)
            else
                temporal_threshold[i - 1];
        }

        if (mode == .SpatialTemporal) {
            if (vsh.mapGetN(f32, in, "spatial_threshold", @intCast(i), vsapi)) |threshold| {
                spatial_threshold[i] = if (scalep and threshold >= 0) thresh: {
                    if (threshold < 0 or threshold > 255) {
                        vsapi.?.mapSetError.?(out, string.printf(allocator, "{s}: Using parameter scaling (scalep), but spatial_threshold of {d} is outside the range of 0-255", .{ func_name, threshold }).ptr);
                        vsapi.?.freeNode.?(d.node);
                        return;
                    }
                    break :thresh vscmn.scaleToFormat(f32, d.vi.format, threshold, 0);
                } else threshold;
            } else {
                spatial_threshold[i] = if (i == 0) vscmn.scaleToFormat(f32, d.vi.format, 7, 0) else spatial_threshold[i - 1];
            }
        }
    }

    d.temporal_threshold = temporal_threshold;
    d.spatial_threshold = spatial_threshold;
    d.process = [3]bool{
        d.temporal_threshold[0] >= 0 or d.spatial_threshold[0] >= 0,
        d.temporal_threshold[1] >= 0 or d.spatial_threshold[1] >= 0,
        d.temporal_threshold[2] >= 0 or d.spatial_threshold[2] >= 0,
    };

    const data: *FluxSmoothData = allocator.create(FluxSmoothData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.General,
        },
    };

    // Runtime/comptime jiggery pokery to select an optimized function at runtime.
    const getFrame = if (mode == .Temporal) switch (d.vi.format.bytesPerSample) {
        1 => &FluxSmooth(u8, .Temporal).getFrame,
        2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &FluxSmooth(u16, .Temporal).getFrame else &FluxSmooth(f16, .Temporal).getFrame,
        4 => &FluxSmooth(f32, .Temporal).getFrame,
        else => unreachable,
    } else switch (d.vi.format.bytesPerSample) {
        1 => &FluxSmooth(u8, .SpatialTemporal).getFrame,
        2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &FluxSmooth(u16, .SpatialTemporal).getFrame else &FluxSmooth(f16, .SpatialTemporal).getFrame,
        4 => &FluxSmooth(f32, .SpatialTemporal).getFrame,
        else => unreachable,
    };

    vsapi.?.createVideoFilter.?(out, func_name.ptr, d.vi, getFrame, fluxSmoothFree, fm.Parallel, &deps, deps.len, data, core);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("FluxSmoothT", "clip:vnode;temporal_threshold:float[]:opt;scalep:int:opt;", "clip:vnode;", fluxSmoothCreate, @constCast(@ptrCast(&FluxSmoothMode.Temporal)), plugin);
    _ = vsapi.registerFunction.?("FluxSmoothST", "clip:vnode;temporal_threshold:float[]:opt;spatial_threshold:float[]:opt;scalep:int:opt;", "clip:vnode;", fluxSmoothCreate, @constCast(@ptrCast(&FluxSmoothMode.SpatialTemporal)), plugin);
}
