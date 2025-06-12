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

// https://ziglang.org/documentation/master/#Choosing-an-Allocator
//
// Using the C allocator since we're passing pointers to allocated memory between Zig and C code,
// specifically the filter data between the Create and GetFrame functions.
const allocator = std.heap.c_allocator;

const MedianData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,

    vi: *const vs.VideoInfo,

    // The radius for each plane we will process.
    radius: [3]u5,

    // Which planes to process.
    process: [3]bool,
};

fn Median(comptime T: type) type {
    const vector_len = vec.getVecSize(T);
    const VT = @Vector(vector_len, T);

    return struct {
        const UAT = types.UnsignedArithmeticType(T);
        const UATV = @Vector(vector_len, UAT);

        const Grid3 = gridcmn.ArrayGrid(3, T);
        const Grid5 = gridcmn.ArrayGrid(5, T);
        const Grid7 = gridcmn.ArrayGrid(7, T);

        const GridV3 = gridcmn.ArrayGrid(3, VT);
        const GridV5 = gridcmn.ArrayGrid(5, VT);
        const GridV7 = gridcmn.ArrayGrid(7, VT);

        fn median(grid: anytype) @typeInfo(@TypeOf(grid.values)).array.child {
            return grid.medianWithCenter();
        }

        fn processPlaneScalar(radius: comptime_int, noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
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
                    dstp[(row * stride) + column] = median(&grid);
                }
            }

            for (radius..height - radius) |row| {
                // Process first pixels of the row with mirrored grid.
                for (0..radius) |column| {
                    var gridFirst = Grid.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = median(&gridFirst);
                }

                for (radius..width - radius) |column| {
                    const top_left = ((row - radius) * stride) + column - radius;

                    // Use a non-mirrored grid everywhere else for maximum performance.
                    // We don't need the mirror effect anyways, as all pixels contain valid data.
                    var grid = Grid.init(T, srcp[top_left..], stride);

                    dstp[(row * stride) + column] = median(&grid);
                }

                // Process last pixel of the row with mirrored grid.
                for (width - radius..width) |column| {
                    var gridLast = Grid.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = median(&gridLast);
                }
            }

            // Process bottom rows with mirrored grid.
            for (height - radius..height) |row| {
                for (0..width) |column| {
                    var grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = median(&grid);
                }
            }
        }

        fn processPlaneVector(radius: comptime_int, noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
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
                    dstp[(row * stride) + column] = median(&grid);
                }
            }

            // Middle rows
            for (radius..height - radius) |row| {
                // First columns - mirrored
                for (0..radius) |column| {
                    var gridFirst = GridS.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = median(&gridFirst);
                }

                // Middle columns - not mirrored
                var column: usize = radius;
                while (column < width_simd) : (column += vector_len) {
                    var grid = GridV.initFromCenter(T, row, column, srcp, stride);
                    const result = median(&grid);
                    vec.storeAt(VT, dstp, row, column, stride, result);
                }

                // Last columns - non-mirrored
                // We do this to minimize the use of scalar mirror code.
                if (width_simd < width) {
                    const adjusted_column = width - vector_len - radius;
                    var grid = GridV.initFromCenter(T, row, adjusted_column, srcp, stride);
                    const result = median(&grid);
                    vec.storeAt(VT, dstp, row, adjusted_column, stride, result);
                }

                // Last columns - mirrored
                for (width - radius..width) |c| {
                    var gridLast = GridS.initFromCenterMirrored(T, row, c, width, height, srcp, stride);
                    dstp[(row * stride) + c] = median(&gridLast);
                }
            }

            // Bottom rows - mirrored
            for (height - radius..height) |row| {
                for (0..width) |column| {
                    var grid = GridS.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
                    dstp[(row * stride) + column] = median(&grid);
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

fn medianGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const zapi = ZAPI.init(vsapi, core);
    const d: *MedianData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        zapi.requestFrameFilter(n, d.node, frame_ctx);
    } else if (activation_reason == ar.AllFramesReady) {
        const src_frame = zapi.initZFrame(d.node, n, frame_ctx);
        defer src_frame.deinit();

        const dst = src_frame.newVideoFrame2(d.process);

        const processPlane: @TypeOf(&Median(u8).processPlane) = switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &Median(u8).processPlane,
            .U16 => &Median(u16).processPlane,
            .F16 => &Median(f16).processPlane,
            .F32 => &Median(f32).processPlane,
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

export fn medianFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *MedianData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn medianCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    const zapi = ZAPI.init(vsapi, core);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);

    var d: MedianData = undefined;

    d.node, d.vi = inz.getNodeVi("clip").?;

    const numRadius: c_int = @intCast(inz.numElements("radius") orelse 0);
    if (numRadius > d.vi.format.numPlanes) {
        outz.setError("Median: Element count of radius must be less than or equal to the number of input planes.");
        zapi.freeNode(d.node);
        return;
    }

    if (numRadius > 0) {
        for (0..3) |i| {
            if (i < numRadius) {
                if (inz.getInt(i32, "radius")) |radius| {
                    if (radius < 0 or radius > 3) {
                        outz.setError("Median: Invalid radius specified, only radius 0-3 supported.");
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
        vsapi.?.freeNode.?(d.node);

        switch (e) {
            vscmn.PlanesError.IndexOutOfRange => outz.setError("Median: Plane index out of range."),
            vscmn.PlanesError.SpecifiedTwice => outz.setError("Median: Plane specified twice."),
        }
        return;
    };

    d.process = [3]bool{
        planes[0] and d.radius[0] > 0,
        planes[1] and d.radius[1] > 0,
        planes[2] and d.radius[2] > 0,
    };

    const data: *MedianData = allocator.create(MedianData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
    };

    zapi.createVideoFilter(out, "Median", d.vi, medianGetFrame, medianFree, fm.Parallel, &deps, data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("Median", "clip:vnode;radius:int[]:opt;planes:int[]:opt;", "clip:vnode;", medianCreate, null, plugin);
}
