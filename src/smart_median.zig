const std = @import("std");
const vapoursynth = @import("vapoursynth");
const ZAPI = vapoursynth.ZAPI;
const testing = @import("std").testing;

const types = @import("common/type.zig");
const vscmn = @import("common/vapoursynth.zig");
const gridcmn = @import("common/array_grid.zig");
const vec = @import("common/vector.zig");
const sort = @import("common/sorting_networks.zig");
const math = @import("common/math.zig");
const lossyCast = math.lossyCast;
const printf = @import("common/string.zig").printf;

const string = @import("common/string.zig");
const float_mode: std.builtin.FloatMode = if (@import("config").optimize_float) .optimized else .strict;

const vs = vapoursynth.vapoursynth4;

const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;
const st = vs.SampleType;

// https://ziglang.org/documentation/master/#Choosing-an-Allocator
//
// Using the C allocator since we're passing pointers to allocated memory between Zig and C code,
// specifically the filter data between the Create and GetFrame functions.
const allocator = std.heap.c_allocator;

const SmartMedianData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,

    vi: *const vs.VideoInfo,

    // The radius for each plane we will process.
    radius: [3]u5,

    threshold: [3]f32,

    // Which planes to process.
    process: [3]bool,
};

fn SmartMedian(comptime T: type) type {
    const vector_len = vec.getVecSize(T);
    const VT = @Vector(vector_len, T);
    const SAT = types.SignedArithmeticType(T);
    const SATV = @Vector(vector_len, SAT);
    const UAT = types.UnsignedArithmeticType(T);
    const UATV = @Vector(vector_len, UAT);

    return struct {
        const Grid3 = gridcmn.ArrayGrid(3, T);
        const Grid5 = gridcmn.ArrayGrid(5, T);
        const Grid7 = gridcmn.ArrayGrid(7, T);

        const GridV3 = gridcmn.ArrayGrid(3, VT);
        const GridV5 = gridcmn.ArrayGrid(5, VT);
        const GridV7 = gridcmn.ArrayGrid(7, VT);

        fn smartMedianScalar(threshold: T, grid: anytype) @typeInfo(@TypeOf(grid.values)).array.child {
            @setFloatMode(float_mode);

            var values = grid.valuesWithoutCenter();
            const center_idx = values.len / 2;

            // Ignore the return value because the input is an even-numbered array,
            // so we're going to take the two elements on either side of the center.
            _ = sort.median(T, &values);

            const median_left: SAT = values[center_idx - 1];
            const median_right: SAT = values[center_idx];

            const average: T = math.averageArray(T, values.len, &values);

            const squared_diff_left: UAT = lossyCast(UAT, (median_left - average) * (median_left - average));
            const squared_diff_right: UAT = lossyCast(UAT, (median_right - average) * (median_right - average));
            const squared_diff_sum: UAT = squared_diff_left + squared_diff_right;

            // Euclidian distance/Variance-ish.
            // Dogway did it intentionally: https://forum.doom9.org/showthread.php?s=a1d14808b0218ddbf119fe50215f666a&p=2017961#post2017961
            // https://github.com/Dogway/Avisynth-Scripts/blob/c6a837107afbf2aeffecea182d021862e9c2fc36/ExTools.avsi#L4268-L4270
            // The multiplication by 13 boosts the square root into a nice curve for a better (smoother) thresholding experience.
            const curved_variance_ish: UAT = switch (types.numberType(T)) {
                .int => lossyCast(UAT, @round(@sqrt(@as(f32, @floatFromInt(squared_diff_sum))) * 13)),
                .float => @sqrt(squared_diff_sum) * 13,
            };

            const center = grid.values[grid.values.len / 2];

            return if (curved_variance_ish <= threshold)
                lossyCast(T, std.math.clamp(center, @min(median_left, median_right), @max(median_left, median_right)))
            else
                center;
        }

        fn smartMedianVector(_threshold: T, grid: anytype) @typeInfo(@TypeOf(grid.values)).array.child {
            const threshold: VT = @splat(_threshold);

            @setFloatMode(float_mode);

            var values = grid.valuesWithoutCenter();
            const center_idx = values.len / 2;

            // Ignore the return value because the input is an even-numbered array,
            // so we're going to take the two elements on either side of the center.
            _ = sort.median(VT, &values);

            const median_left: SATV = values[center_idx - 1];
            const median_right: SATV = values[center_idx];

            const average: VT = math.averageArray(VT, values.len, &values);

            const squared_diff_left: UATV = lossyCast(UATV, (median_left - average) * (median_left - average));
            const squared_diff_right: UATV = lossyCast(UATV, (median_right - average) * (median_right - average));
            const squared_diff_sum: UATV = squared_diff_left + squared_diff_right;

            // Euclidian distance/Variance-ish.
            // Dogway did it intentionally: https://forum.doom9.org/showthread.php?s=a1d14808b0218ddbf119fe50215f666a&p=2017961#post2017961
            // https://github.com/Dogway/Avisynth-Scripts/blob/c6a837107afbf2aeffecea182d021862e9c2fc36/ExTools.avsi#L4268-L4270
            // The multiplication by 13 boosts the square root into a nice curve for a better (smoother) thresholding experience.
            const FV = @Vector(vector_len, if (types.isInt(T)) f32 else T);
            const thirteen: FV = @splat(13);

            const curved_variance_ish = switch (types.numberType(T)) {
                .int => lossyCast(UATV, @round(@sqrt(@as(FV, @floatFromInt(squared_diff_sum))) * thirteen)),
                .float => @sqrt(squared_diff_sum) * thirteen,
            };

            const center = grid.values[grid.values.len / 2];

            const lte_threshold = curved_variance_ish <= threshold;
            const median = lossyCast(VT, std.math.clamp(center, @min(median_left, median_right), @max(median_left, median_right)));
            return @select(T, lte_threshold, median, center);
        }

        fn processPlaneScalar(radius: comptime_int, threshold: T, noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
            const Grid = switch (comptime radius) {
                1 => Grid3,
                2 => Grid5,
                3 => Grid7,
                else => unreachable,
            };

            // Process top rows with mirrored grid.
            for (0..radius) |row| {
                for (0..width) |column| {
                    var grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = smartMedianScalar(threshold, &grid);
                }
            }

            for (radius..height - radius) |row| {
                // Process first pixels of the row with mirrored grid.
                for (0..radius) |column| {
                    var gridFirst = Grid.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = smartMedianScalar(threshold, &gridFirst);
                }

                for (radius..width - radius) |column| {
                    const top_left = ((row - radius) * stride) + column - radius;

                    // Use a non-mirrored grid everywhere else for maximum performance.
                    // We don't need the mirror effect anyways, as all pixels contain valid data.
                    var grid = Grid.init(T, srcp[top_left..], stride);

                    dstp[(row * stride) + column] = smartMedianScalar(threshold, &grid);
                }

                // Process last pixel of the row with mirrored grid.
                for (width - radius..width) |column| {
                    var gridLast = Grid.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = smartMedianScalar(threshold, &gridLast);
                }
            }

            // Process bottom rows with mirrored grid.
            for (height - radius..height) |row| {
                for (0..width) |column| {
                    var grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = smartMedianScalar(threshold, &grid);
                }
            }
        }

        fn processPlaneVector(radius: comptime_int, threshold: T, noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
            // We process the mirrored pixels using our scalar implementation, as Grid.initFromCenterMirrored
            // doesn't fully support vectors at this time. That's why we need both a scalar Grid and a vector Grid.
            const GridS = switch (comptime radius) {
                1 => Grid3,
                2 => Grid5,
                3 => Grid7,
                else => unreachable,
            };

            const GridV = switch (comptime radius) {
                1 => GridV3,
                2 => GridV5,
                3 => GridV7,
                else => unreachable,
            };

            // We make some assumptions in this code in order to make processing with vectors simpler.
            std.debug.assert(width >= vector_len);
            std.debug.assert(radius < vector_len);

            const width_simd = (width - radius) / vector_len * vector_len;

            // Top rows - mirrored
            for (0..radius) |row| {
                for (0..width) |column| {
                    var grid = GridS.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = smartMedianScalar(threshold, &grid);
                }
            }

            // Middle rows
            for (radius..height - radius) |row| {
                // First columns - mirrored
                for (0..radius) |column| {
                    var gridFirst = GridS.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = smartMedianScalar(threshold, &gridFirst);
                }

                // Middle columns - not mirrored
                var column: usize = radius;
                while (column < width_simd) : (column += vector_len) {
                    var grid = GridV.initFromCenter(T, row, column, srcp, stride);
                    const result = smartMedianVector(threshold, &grid);
                    vec.storeAt(VT, dstp, row, column, stride, result);
                }

                // Last columns - non-mirrored
                // We do this to minimize the use of scalar mirror code.
                if (width_simd < width) {
                    const adjusted_column = width - vector_len - radius;
                    var grid = GridV.initFromCenter(T, row, adjusted_column, srcp, stride);
                    const result = smartMedianVector(threshold, &grid);
                    vec.storeAt(VT, dstp, row, adjusted_column, stride, result);
                }

                // Last columns - mirrored
                for (width - radius..width) |c| {
                    var gridLast = GridS.initFromCenterMirrored(T, row, c, width, height, srcp, stride);
                    dstp[(row * stride) + c] = smartMedianScalar(threshold, &gridLast);
                }
            }

            // Bottom rows - mirrored
            for (height - radius..height) |row| {
                for (0..width) |column| {
                    var grid = GridS.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = smartMedianScalar(threshold, &grid);
                }
            }
        }

        fn processPlane(radius: u8, _threshold: f32, noalias srcp8: []const u8, noalias dstp8: []u8, width: usize, height: usize, stride8: usize) void {
            const threshold: T = lossyCast(T, _threshold);
            const stride = stride8 / @sizeOf(T);
            const srcp: []const T = @ptrCast(@alignCast(srcp8));
            const dstp: []T = @ptrCast(@alignCast(dstp8));

            switch (radius) {
                // Custom vector version is substantially faster than auto-vectorized (scalar) version,
                // for both radius 1 and radius 2.
                // inline 1...3 => |r| processPlaneScalar(r, threshold, srcp, dstp, width, height, stride),
                inline 1...3 => |r| processPlaneVector(r, threshold, srcp, dstp, width, height, stride),
                else => unreachable,
            }
        }
    };
}

fn smartMedianGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const zapi = ZAPI.init(vsapi, core, frame_ctx);
    const d: *SmartMedianData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        zapi.requestFrameFilter(n, d.node);
    } else if (activation_reason == ar.AllFramesReady) {
        const src_frame = zapi.initZFrame(d.node, n);
        defer src_frame.deinit();

        const dst = src_frame.newVideoFrame2(d.process);

        const processPlane = switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &SmartMedian(u8).processPlane,
            .U16 => &SmartMedian(u16).processPlane,
            .F16 => &SmartMedian(f16).processPlane,
            .F32 => &SmartMedian(f32).processPlane,
        };

        for (0..@intCast(d.vi.format.numPlanes)) |plane| {
            // Skip planes we aren't supposed to process
            if (!d.process[plane]) {
                continue;
            }

            const width: usize = dst.getWidth(plane);
            const height: usize = dst.getHeight(plane);
            const stride8: usize = dst.getStride(plane);
            const srcp8: []const u8 = src_frame.getReadSlice(plane);
            const dstp8: []u8 = dst.getWriteSlice(plane);

            processPlane(d.radius[plane], d.threshold[plane], srcp8, dstp8, width, height, stride8);
        }

        return dst.frame;
    }

    return null;
}

export fn smartMedianFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = core;
    const d: *SmartMedianData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn smartMedianCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = user_data;
    const zapi = ZAPI.init(vsapi, core, null);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);

    var d: SmartMedianData = undefined;

    d.node, d.vi = inz.getNodeVi("clip").?;

    const numRadius: c_int = @intCast(inz.numElements("radius") orelse 0);
    if (numRadius > d.vi.format.numPlanes) {
        outz.setError("SmartMedian: Element count of radius must be less than or equal to the number of input planes.");
        zapi.freeNode(d.node);
        return;
    }

    if (numRadius > 0) {
        for (0..3) |i| {
            if (inz.getInt2(i32, "radius", i)) |radius| {
                if (radius < 0 or radius > 3) {
                    outz.setError("SmartMedian: Invalid radius specified, only radius 0-3 supported.");
                    zapi.freeNode(d.node);
                    return;
                }
                d.radius[i] = @intCast(radius);
            } else {
                d.radius[i] = d.radius[i - 1];
            }
        }
    } else {
        // Default radius
        d.radius = .{ 1, 1, 1 };
    }

    const numThreshold: c_int = @intCast(inz.numElements("threshold") orelse 0);
    if (numThreshold > d.vi.format.numPlanes) {
        outz.setError("SmartMedian: Element count of threshold must be less than or equal to the number of input planes.");
        zapi.freeNode(d.node);
        return;
    }

    const scalep = inz.getBool("scalep") orelse false;

    if (numThreshold > 0) {
        for (0..3) |i| {
            if (inz.getFloat2(f32, "threshold", i)) |_threshold| {
                const format_max = if (scalep) 255 else vscmn.getFormatMaximum(f32, d.vi.format, false);
                if (_threshold < 0 or _threshold > format_max) {
                    outz.setError(printf(allocator, "SmartMedian: Invalid threshold, must be in the range of 0 - {d} with scalep = {} for this bit depth", .{ format_max, scalep }));
                    zapi.freeNode(d.node);
                    return;
                }
                d.threshold[i] = if (scalep) vscmn.scaleToFormat(f32, d.vi.format, _threshold, 0) else _threshold;
            } else {
                d.threshold[i] = d.threshold[i - 1];
            }
        }
    } else {
        // Default radius
        const fifty = vscmn.scaleToFormat(f32, d.vi.format, 50, 0);
        const one_twenty_eight = vscmn.scaleToFormat(f32, d.vi.format, 128, 0);
        d.threshold = .{
            if (d.radius[0] == 1) fifty else one_twenty_eight,
            if (d.radius[1] == 1) fifty else one_twenty_eight,
            if (d.radius[2] == 1) fifty else one_twenty_eight,
        };
    }

    const planes = vscmn.normalizePlanes(d.vi.format, in, vsapi) catch |e| {
        zapi.freeNode(d.node);

        switch (e) {
            vscmn.PlanesError.IndexOutOfRange => outz.setError("SmartMedian: Plane index out of range."),
            vscmn.PlanesError.SpecifiedTwice => outz.setError("SmartMedian: Plane specified twice."),
        }
        return;
    };

    d.process = [3]bool{
        planes[0] and d.radius[0] > 0,
        planes[1] and d.radius[1] > 0,
        planes[2] and d.radius[2] > 0,
    };

    const data: *SmartMedianData = allocator.create(SmartMedianData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
    };

    zapi.createVideoFilter(out, "SmartMedian", d.vi, smartMedianGetFrame, smartMedianFree, fm.Parallel, &deps, data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("SmartMedian", "clip:vnode;radius:int[]:opt;threshold:float[]:opt;scalep:int:opt;planes:int[]:opt;", "clip:vnode;", smartMedianCreate, null, plugin);
}
