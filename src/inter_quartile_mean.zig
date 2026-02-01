const std = @import("std");
const vapoursynth = @import("vapoursynth");
const ZAPI = vapoursynth.ZAPI;
const testing = @import("std").testing;

const types = @import("common/type.zig");
const vscmn = @import("common/vapoursynth.zig");
const gridcmn = @import("common/array_grid.zig");
const vec = @import("common/vector.zig");

const string = @import("common/string.zig");
const float_mode: std.builtin.FloatMode = if (@import("config").optimize_float) .optimized else .strict;

const vs = vapoursynth.vapoursynth4;

const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;
const st = vs.SampleType;

const allocator = std.heap.c_allocator;

// We don't have sorting networks beyond 49 elements at this time,
// and I haven't implemented any constant time / windowed approach just yet,
// so we're limited to a radius of 3 (7x7) median.
const MAX_RADIUS = 3;

const InterQuartileMeanData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,

    vi: *const vs.VideoInfo,

    // The radius for each plane we will process.
    radius: [3]u5,
    // Which planes to process.
    process: [3]bool,
};

fn InterQuartileMean(comptime T: type) type {
    const vector_len = vec.getVecSize(T);
    const VT = @Vector(vector_len, T);
    const UAT = types.UnsignedArithmeticType(T);
    const UATV = @Vector(vector_len, UAT);

    return struct {

        // Interquartile mean of 3x3 grid, including the center.
        fn iqm3Scalar(grid: anytype) T {
            @setFloatMode(float_mode);

            grid.sortWithCenter();
            const sorted = &grid.values;

            // Trim the first and last quartile, then average the inner quartiles
            // https://en.wikipedia.org/wiki/Interquartile_mean#Dataset_size_not_divisible_by_four

            const result: T = if (types.isInt(T))
                // ~922 fps
                // ((floatFromInt(R, sorted[3]) + floatFromInt(R, sorted[4]) + floatFromInt(R, sorted[5])) +
                //     ((floatFromInt(R, sorted[2]) + floatFromInt(R, sorted[6])) * 0.75)) / 4.5
                // ~990 fps
                // @intFromFloat(@round(floatFromInt(f32, (@as(UAT, sorted[3]) + sorted[4] + sorted[5]) +
                //     ((((@as(UAT, sorted[2]) + sorted[6]) * 3) + 2) / 4)) / 4.5))
                // ~1000 fps
                // @intFromFloat(@round(floatFromInt(f32, (@as(UAT, sorted[3]) + sorted[4] + sorted[5]) +
                //     ((((@as(UAT, sorted[2]) + sorted[6]) * 3) + 2) / 4)) / 4.5))
                //
                // ~1091 fps
                // Note that the use of ".. + 2) / 4" and ".. + 4) / 9" is to ensure proper rounding in integer division.
                @intCast((((@as(UAT, sorted[3]) + sorted[4] + sorted[5]) +
                    ((((@as(UAT, sorted[2]) + sorted[6]) * 3) + 2) / 4)) * 2 + 4) / 9)
            else
                ((sorted[3] + sorted[4] + sorted[5]) + ((sorted[2] + sorted[6]) * 0.75)) / 4.5;

            // Round result for integers, take float as is.
            return result;
        }

        test iqm3Scalar {
            var data = [9]T{
                9, 8, 7,
                6, 5, 4,
                3, 2, 1,
            };

            const Grid3 = gridcmn.ArrayGrid(3, T);
            var grid = Grid3.init(T, &data, 3);

            try testing.expectEqual(5, iqm3Scalar(&grid));

            data = [9]T{
                1, 1,  3,
                3, 7,  8,
                9, 99, 99,
            };
            grid = Grid3.init(T, &data, 3);

            try testing.expectEqual(6, iqm3Scalar(&grid));
        }

        fn iqm3Vector(grid: anytype) VT {
            @setFloatMode(float_mode);

            grid.sortWithCenter();

            const sorted = &grid.values;

            const three: VT = @splat(3);
            const two: VT = @splat(2);
            const four: VT = @splat(4);
            const nine: VT = @splat(9);

            const result: VT = if (types.isInt(VT))
                // Note that the use of ".. + 2) / 4" and ".. + 4) / 9" is to ensure proper rounding in integer division.
                @intCast((((@as(UATV, sorted[3]) + sorted[4] + sorted[5]) +
                    ((((@as(UATV, sorted[2]) + sorted[6]) * three) + two) / four)) * two + four) / nine)
            else blk: {
                const point_seven_five: VT = @splat(0.75);
                const four_point_five: VT = @splat(4.5);

                break :blk ((sorted[3] + sorted[4] + sorted[5]) + ((sorted[2] + sorted[6]) * point_seven_five)) / four_point_five;
            };

            return result;
        }

        /// Interquartile mean of 5x5 grid, including the center.
        fn iqm5Scalar(grid: anytype) T {
            @setFloatMode(float_mode);

            grid.sortWithCenter();
            const sorted = &grid.values;

            const result: T = if (types.isInt(T))
                // Note that the use of ".. + 2) / 4" and ".. + 12) / 25" is to ensure proper rounding in integer division.
                @intCast((((@as(UAT, sorted[7]) + sorted[8] + sorted[9] + sorted[10] + sorted[11] + sorted[12] + sorted[13] + sorted[14] + sorted[15] + sorted[16] + sorted[17]) +
                    ((((@as(UAT, sorted[6]) + sorted[18]) * 3) + 2) / 4)) * 2 + 12) / 25)
            else
                ((sorted[7] + sorted[8] + sorted[9] + sorted[10] + sorted[11] + sorted[12] + sorted[13] + sorted[14] + sorted[15] + sorted[16] + sorted[17]) +
                    ((sorted[6] + sorted[18]) * 0.75)) / 12.5;

            return result;
        }

        test iqm5Scalar {
            const data = [25]T{
                1,  1,  1,  1,  1,
                1,  3,  3,  3,  3,
                7,  7,  7,  7,  7,
                8,  8,  8,  8,  99,
                99, 99, 99, 99, 99,
            };
            
            const Grid5 = gridcmn.ArrayGrid(5, T);
            var grid = Grid5.init(T, &data, 5);

            if (types.isInt(T)) {
                try testing.expectEqual(6, iqm5Scalar(&grid));
            } else {
                try testing.expectApproxEqAbs(6.1, iqm5Scalar(&grid), 0.0001);
            }
        }

        fn iqm5Vector(grid: anytype) VT {
            @setFloatMode(float_mode);

            grid.sortWithCenter();

            const sorted = &grid.values;

            const three: VT = @splat(3);
            const two: VT = @splat(2);
            const four: VT = @splat(4);
            const twelve: VT = @splat(12);
            const twenty_five: VT = @splat(25);

            const result: VT = if (types.isInt(VT))
                // Note that the use of ".. + 2) / 4" and ".. + 12) / 25" is to ensure proper rounding in integer division.
                @intCast((((@as(UATV, sorted[7]) + sorted[8] + sorted[9] + sorted[10] + sorted[11] + sorted[12] + sorted[13] + sorted[14] + sorted[15] + sorted[16] + sorted[17]) +
                    ((((@as(UATV, sorted[6]) + sorted[18]) * three) + two) / four)) * two + twelve) / twenty_five)
            else blk: {
                const point_seven_five: VT = @splat(0.75);
                const twelve_point_five: VT = @splat(12.5);

                break :blk ((sorted[7] + sorted[8] + sorted[9] + sorted[10] + sorted[11] + sorted[12] + sorted[13] + sorted[14] + sorted[15] + sorted[16] + sorted[17]) +
                    ((sorted[6] + sorted[18]) * point_seven_five)) / twelve_point_five;
            };

            return result;
        }

        /// Interquartile mean of 7x7 grid, including the center.
        fn iqm7Scalar(grid: anytype) T {
            @setFloatMode(float_mode);

            grid.sortWithCenter();

            const sorted = &grid.values;

            const result: T = if (types.isInt(T))
                // Note that the use of ".. + 2) / 4" and ".. + 24) / 49" is to ensure proper rounding in integer division.
                @intCast((((@as(UAT, sorted[13]) + sorted[14] + sorted[15] + sorted[16] + sorted[17] + sorted[18] + sorted[19] + sorted[20] + sorted[21] + sorted[22] + sorted[23] +
                    sorted[24] + sorted[25] + sorted[26] + sorted[27] + sorted[28] + sorted[29] + sorted[30] + sorted[31] + sorted[32] + sorted[33] + sorted[34] + sorted[35]) +
                    ((((@as(UAT, sorted[12]) + sorted[36]) * 3) + 2) / 4)) * 2 + 24) / 49)
            else
                ((sorted[13] + sorted[14] + sorted[15] + sorted[16] + sorted[17] + sorted[18] + sorted[19] + sorted[20] + sorted[21] + sorted[22] + sorted[23] +
                    sorted[24] + sorted[25] + sorted[26] + sorted[27] + sorted[28] + sorted[29] + sorted[30] + sorted[31] + sorted[32] + sorted[33] + sorted[34] + sorted[35]) +
                    ((sorted[12] + sorted[36]) * 0.75)) / 24.5;

            return result;
        }

        test iqm7Scalar {
            const data = [49]T{
                1,  1,  1,  1,  1,  1,  1,
                1,  1,  1,  1,  1,  3,  3,
                3,  3,  3,  3,  3,  3,  5,
                7,  7,  7,  7,  7,  7,  7,
                8,  8,  8,  8,  8,  8,  8,
                8,  8,  99, 99, 99, 99, 99,
                99, 99, 99, 99, 99, 99, 99,
            };

            const Grid7 = gridcmn.ArrayGrid(7, T);
            var grid = Grid7.init(T, &data, 7);

            if (types.isInt(T)) {
                try testing.expectEqual(6, iqm7Scalar(&grid));
            } else {
                try testing.expectApproxEqAbs(6.0, iqm7Scalar(&grid), 0.02);
            }
        }

        fn iqm7Vector(grid: anytype) VT {
            @setFloatMode(float_mode);

            grid.sortWithCenter();

            const sorted = &grid.values;

            const three: VT = @splat(3);
            const two: VT = @splat(2);
            const four: VT = @splat(4);
            const twenty_four: VT = @splat(24);
            const forty_nine: VT = @splat(49);

            const result: VT = if (types.isInt(T))
                // Note that the use of ".. + 2) / 4" and ".. + 24) / 49" is to ensure proper rounding in integer division.
                @intCast((((@as(UATV, sorted[13]) + sorted[14] + sorted[15] + sorted[16] + sorted[17] + sorted[18] + sorted[19] + sorted[20] + sorted[21] + sorted[22] + sorted[23] +
                    sorted[24] + sorted[25] + sorted[26] + sorted[27] + sorted[28] + sorted[29] + sorted[30] + sorted[31] + sorted[32] + sorted[33] + sorted[34] + sorted[35]) +
                    ((((@as(UATV, sorted[12]) + sorted[36]) * three) + two) / four)) * two + twenty_four) / forty_nine)
            else blk: {
                const point_seven_five: VT = @splat(0.75);
                const twenty_four_point_five: VT = @splat(24.5);

                break :blk ((sorted[13] + sorted[14] + sorted[15] + sorted[16] + sorted[17] + sorted[18] + sorted[19] + sorted[20] + sorted[21] + sorted[22] + sorted[23] +
                    sorted[24] + sorted[25] + sorted[26] + sorted[27] + sorted[28] + sorted[29] + sorted[30] + sorted[31] + sorted[32] + sorted[33] + sorted[34] + sorted[35]) +
                    ((sorted[12] + sorted[36]) * point_seven_five)) / twenty_four_point_five;
            };

            return result;
        }

        fn interQuartileMeanScalar(radius: comptime_int, grid: anytype) T {
            return switch (radius) {
                1 => iqm3Scalar(grid),
                2 => iqm5Scalar(grid),
                3 => iqm7Scalar(grid),
                else => unreachable,
            };
        }

        fn interQuartileMeanVector(radius: comptime_int, grid: anytype) VT {
            return switch (radius) {
                1 => iqm3Vector(grid),
                2 => iqm5Vector(grid),
                3 => iqm7Vector(grid),
                else => unreachable,
            };
        }

        fn processPlaneScalar(radius: comptime_int, noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
            const Grid = switch (comptime radius) {
                inline 1...MAX_RADIUS => |r| gridcmn.ArrayGrid(r * 2 + 1, T),
                else => unreachable,
            };

            // Process top rows with mirrored grid.
            for (0..radius) |row| {
                for (0..width) |column| {
                    var grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = interQuartileMeanScalar(radius, &grid);
                }
            }

            for (radius..height - radius) |row| {
                // Process first pixels of the row with mirrored grid.
                for (0..radius) |column| {
                    var gridFirst = Grid.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = interQuartileMeanScalar(radius, &gridFirst);
                }

                for (radius..width - radius) |column| {
                    const top_left = ((row - radius) * stride) + column - radius;

                    // Use a non-mirrored grid everywhere else for maximum performance.
                    // We don't need the mirror effect anyways, as all pixels contain valid data.
                    var grid = Grid.init(T, srcp[top_left..], stride);

                    dstp[(row * stride) + column] = interQuartileMeanScalar(radius, &grid);
                }

                // Process last pixel of the row with mirrored grid.
                for (width - radius..width) |column| {
                    var gridLast = Grid.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = interQuartileMeanScalar(radius, &gridLast);
                }
            }

            // Process bottom rows with mirrored grid.
            for (height - radius..height) |row| {
                for (0..width) |column| {
                    var grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = interQuartileMeanScalar(radius, &grid);
                }
            }
        }

        fn processPlaneVector(radius: comptime_int, noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
            // We process the mirrored pixels using our scalar implementation, as Grid.initFromCenterMirrored
            // doesn't fully support vectors at this time. That's why we need both a scalar Grid and a vector Grid.
            const GridS = switch (comptime radius) {
                inline 1...MAX_RADIUS => |r| gridcmn.ArrayGrid(r * 2 + 1, T),
                else => unreachable,
            };

            const GridV = switch (comptime radius) {
                inline 1...MAX_RADIUS => |r| gridcmn.ArrayGrid(r * 2 + 1, VT),
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
                    dstp[(row * stride) + column] = interQuartileMeanScalar(radius, &grid);
                }
            }

            // Middle rows
            for (radius..height - radius) |row| {
                // First columns - mirrored
                for (0..radius) |column| {
                    var gridFirst = GridS.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = interQuartileMeanScalar(radius, &gridFirst);
                }

                // Middle columns - not mirrored
                var column: usize = radius;
                while (column < width_simd) : (column += vector_len) {
                    var grid = GridV.initFromCenter(T, row, column, srcp, stride);
                    const result = interQuartileMeanVector(radius, &grid);
                    vec.storeAt(VT, dstp, row, column, stride, result);
                }

                // Last columns - non-mirrored
                // We do this to minimize the use of scalar mirror code.
                if (width_simd < width) {
                    const adjusted_column = width - vector_len - radius;
                    var grid = GridV.initFromCenter(T, row, adjusted_column, srcp, stride);
                    const result = interQuartileMeanVector(radius, &grid);
                    vec.storeAt(VT, dstp, row, adjusted_column, stride, result);
                }

                // Last columns - mirrored
                for (width - radius..width) |c| {
                    var gridLast = GridS.initFromCenterMirrored(T, row, c, width, height, srcp, stride);
                    dstp[(row * stride) + c] = interQuartileMeanScalar(radius, &gridLast);
                }
            }

            // Bottom rows - mirrored
            for (height - radius..height) |row| {
                for (0..width) |column| {
                    var grid = GridS.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = interQuartileMeanScalar(radius, &grid);
                }
            }
        }

        fn processPlane(radius: u8, noalias srcp8: []const u8, noalias dstp8: []u8, width: usize, height: usize, stride8: usize) void {
            const stride = stride8 / @sizeOf(T);
            const srcp: []const T = @ptrCast(@alignCast(srcp8));
            const dstp: []T = @ptrCast(@alignCast(dstp8));

            switch (radius) {
                // Custom vector version is substantially faster than auto-vectorized (scalar) version,
                // for both radius 1 and radius 2.
                inline 1...3 => |r| processPlaneVector(r, srcp, dstp, width, height, stride),
                else => unreachable,
            }
        }
    };
}

fn interQuartileMeanGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const zapi = ZAPI.init(vsapi, core, frame_ctx);
    const d: *InterQuartileMeanData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        zapi.requestFrameFilter(n, d.node);
    } else if (activation_reason == ar.AllFramesReady) {
        const src_frame = zapi.initZFrame(d.node, n);
        defer src_frame.deinit();

        const dst = src_frame.newVideoFrame2(d.process);

        const processPlane = switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &InterQuartileMean(u8).processPlane,
            .U16 => &InterQuartileMean(u16).processPlane,
            .F16 => &InterQuartileMean(f16).processPlane,
            .F32 => &InterQuartileMean(f32).processPlane,
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

            processPlane(d.radius[plane], srcp8, dstp8, width, height, stride8);
        }

        return dst.frame;
    }

    return null;
}

export fn interQuartileMeanFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = core;
    const d: *InterQuartileMeanData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn interQuartileMeanCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = user_data;
    const zapi = ZAPI.init(vsapi, core, null);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);
    var d: InterQuartileMeanData = undefined;

    d.node, d.vi = inz.getNodeVi("clip").?;

    const numRadius: c_int = @intCast(inz.numElements("radius") orelse 0);
    if (numRadius > d.vi.format.numPlanes) {
        outz.setError("InterQuartileMean: Element count of radius must be less than or equal to the number of input planes.");
        zapi.freeNode(d.node);
        return;
    }

    if (numRadius > 0) {
        for (0..3) |i| {
            if (i < numRadius) {
                if (inz.getInt2(i32, "radius", i)) |radius| {
                    if (radius < 0 or radius > 3) {
                        outz.setError("InterQuartileMean: Invalid radius specified, only radius 0-3 supported.");
                        zapi.freeNode(d.node);
                        return;
                    }
                    d.radius[i] = @intCast(radius);
                }
            } else {
                d.radius[i] = d.radius[i - 1];
            }
        }
    } else {
        // Default radius
        d.radius = .{ 1, 1, 1 };
    }

    const planes = vscmn.normalizePlanes(d.vi.format, in, vsapi) catch |e| {
        zapi.freeNode(d.node);

        switch (e) {
            vscmn.PlanesError.IndexOutOfRange => outz.setError("InterQuartileMean: Plane index out of range."),
            vscmn.PlanesError.SpecifiedTwice => outz.setError("InterQuartileMean: Plane specified twice."),
        }
        return;
    };

    d.process = [3]bool{
        planes[0] and d.radius[0] > 0,
        planes[1] and d.radius[1] > 0,
        planes[2] and d.radius[2] > 0,
    };

    const data: *InterQuartileMeanData = allocator.create(InterQuartileMeanData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
    };

    zapi.createVideoFilter(out, "InterQuartileMean", d.vi, interQuartileMeanGetFrame, interQuartileMeanFree, fm.Parallel, &deps, data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("InterQuartileMean", "clip:vnode;radius:int[]:opt;planes:int[]:opt;", "clip:vnode;", interQuartileMeanCreate, null, plugin);
}
