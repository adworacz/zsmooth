const std = @import("std");
const vapoursynth = @import("vapoursynth");
const ZAPI = vapoursynth.ZAPI;
const testing = @import("std").testing;

const types = @import("common/type.zig");
const vscmn = @import("common/vapoursynth.zig");
const gridcmn = @import("common/array_grid.zig");
const vec = @import("common/vector.zig");
const math = @import("common/math.zig");

const string = @import("common/string.zig");
const float_mode: std.builtin.FloatMode = if (@import("config").optimize_float) .optimized else .strict;

const vs = vapoursynth.vapoursynth4;

const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;
const st = vs.SampleType;

const allocator = std.heap.c_allocator;

const MinMaxOp = enum {
    min,
};

const MinMaxData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,

    vi: *const vs.VideoInfo,

    // The radius for each plane we will process.
    radius: [3]u5,

    // Which planes to process.
    process: [3]bool,
};

fn MinMax(comptime T: type) type {
    const vector_len = vec.getVecSize(T);
    const VT = @Vector(vector_len, T);

    return struct {
        fn minmax(grid: anytype) @typeInfo(@TypeOf(grid.values)).array.child {
            return grid.minmaxWithCenter();
        }

        fn op(comptime clamped: bool, radius: comptime_int, _y: usize, _x: usize, noalias srcp: []const T, width: usize, height: usize, stride: usize) T {
            var val: T = srcp[_y * stride + _x]; 

            const y: isize = @intCast(_y);
            const x: isize = @intCast(_x);
            comptime var ry: isize = -radius;
            inline while (ry <= radius) : (ry += 1) {
                comptime var rx: isize = -radius;
                inline while (rx <= radius) : (rx += 1) {
                    if (ry == 0 and rx == 0) {
                        // skip the center pixel since we loaded it already.
                        continue;
                    }

                    const idx = if (clamped)
                        @as(usize, @intCast(std.math.clamp(y + ry, 0, height - 1))) * stride + @as(usize, @intCast(std.math.clamp(x + rx, 0, width - 1)))
                    else
                        @as(usize, @intCast(y + ry)) * stride + @as(usize, @intCast(x + rx));

                    val = @min(srcp[idx], val);
                }
            }

            return val;
        }

        fn opVec(radius: comptime_int, _y: usize, _x: usize, noalias srcp: []const T, stride: usize) VT {
            var val: VT = vec.loadAt(VT, srcp, _y, _x, stride);

            const y: isize = @intCast(_y);
            const x: isize = @intCast(_x);

            //These inline whiles are necessary - the compiler doesn't seem to 
            //optimize things properly in my tests without them.
            //
            //I was getting 40fps without them, and 1200fps with them
            comptime var ry: isize = -radius;
            inline while (ry <= radius) : (ry += 1) {
                comptime var rx: isize = -radius;
                inline while (rx <= radius) : (rx += 1) {
                    if (ry == 0 and rx == 0) {
                        // skip the center pixel since we loaded it already.
                        continue;
                    }
                    const c = vec.loadAt(VT, srcp, @intCast(y + ry), @intCast(x + rx), stride);

                    val = @min(c, val);
                }
            }

            return val;
        }

        fn processPlaneScalar(radius: comptime_int, noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
            // In order to minimize the use of clamped indexing (which is harder for the compiler to optimize)
            // we separate the processing steps so that we only use clamped logic where it's actually necessary.

            for (0..radius) |y| {
                // Top rows - clamped indexing to not overflow
                for (0..width) |x| {
                    dstp[y * stride + x] = op(true, radius, y, x, srcp, width, height, stride);
                }
            }

            for (radius..height - radius) |y| {
                for (0..radius) |x| {
                    // far left columns - clamped indexing to not overflow
                    dstp[y * stride + x] = op(true, radius, y, x, srcp, width, height, stride);
                }

                for (radius..width - radius) |x| {
                    // everything else - unclamped indexing since we know we're safe from overflow
                    dstp[y * stride + x] = op(false, radius, y, x, srcp, width, height, stride);
                }

                for (width - radius..width) |x| {
                    // far right columns - clamped indexing to not overflow
                    dstp[y * stride + x] = op(true, radius, y, x, srcp, width, height, stride);
                }
            }

            for (height - radius..height) |y| {
                // Bottom rows - clamped indexing to not overflow
                for (0..width) |x| {
                    dstp[y * stride + x] = op(true, radius, y, x, srcp, width, height, stride);
                }
            }
        }

        test processPlaneScalar {
            const srcp = [_]T{
                2, 3, 4,
                5, 6, 7,
                8, 9, 1,
            };

            var dstp: [srcp.len]T = undefined;
            const expectedDst = [_]T{
                2, 2, 3,
                2, 1, 1,
                5, 1, 1,
            };

            processPlaneScalar(1, &srcp, &dstp, 3, 3, 3);

            try testing.expectEqualDeep(expectedDst, dstp);
        }

        fn processPlaneVector(radius: comptime_int, noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
            // In order to minimize the use of clamped indexing (which is harder for the compiler to optimize)
            // we separate the processing steps so that we only use clamped logic where it's actually necessary.

            const width_simd = (width - radius) / vector_len * vector_len;

            for (0..radius) |y| {
                // Top rows - clamped indexing to not overflow
                for (0..width) |x| {
                    dstp[y * stride + x] = op(true, radius, y, x, srcp, width, height, stride);
                }
            }

            for (radius..height - radius) |y| {
                for (0..radius) |x| {
                    // far left columns - clamped indexing to not overflow
                    dstp[y * stride + x] = op(true, radius, y, x, srcp, width, height, stride);
                }

                // everything else - unclamped indexing since we know we're safe from overflow
                var vx: usize = radius;
                while (vx < width_simd) : (vx += vector_len) {
                    const result = opVec(radius, y, vx, srcp, stride);
                    vec.storeAt(VT, dstp, y, vx, stride, result);
                }

                // Last columns - non-mirrored
                // We do this to minimize the use of scalar mirror code.
                if (width_simd < width) {
                    vx = width - vector_len - radius;
                    const result = opVec(radius, y, vx, srcp, stride);
                    vec.storeAt(VT, dstp, y, vx, stride, result);
                }

                for (width - radius..width) |x| {
                    // far right columns - clamped indexing to not overflow
                    dstp[y * stride + x] = op(true, radius, y, x, srcp, width, height, stride);
                }
            }

            for (height - radius..height) |y| {
                // Bottom rows - clamped indexing to not overflow
                for (0..width) |x| {
                    dstp[y * stride + x] = op(true, radius, y, x, srcp, width, height, stride);
                }
            }
        }

        // fn processPlaneVector(radius: comptime_int, noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
        //     // We process the mirrored pixels using our scalar implementation, as Grid.initFromCenterMirrored
        //     // doesn't fully support vectors at this time. That's why we need both a scalar Grid and a vector Grid.
        //     const GridS = switch (comptime radius) {
        //         1 => Grid3,
        //         2 => Grid5,
        //         3 => Grid7,
        //         else => unreachable,
        //     };
        //
        //     const GridV = switch (comptime radius) {
        //         1 => GridV3,
        //         2 => GridV5,
        //         3 => GridV7,
        //         else => unreachable,
        //     };
        //
        //     // We make some assumptions in this code in order to make processing with vectors simpler.
        //     std.debug.assert(width >= vector_len);
        //     std.debug.assert(radius < vector_len);
        //
        //     const width_simd = (width - radius) / vector_len * vector_len;
        //
        //     // Top rows - mirrored
        //     for (0..radius) |row| {
        //         for (0..width) |column| {
        //             var grid = GridS.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
        //             dstp[(row * stride) + column] = minmax(&grid);
        //         }
        //     }
        //
        //     // Middle rows
        //     for (radius..height - radius) |row| {
        //         // First columns - mirrored
        //         for (0..radius) |column| {
        //             var gridFirst = GridS.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
        //             dstp[(row * stride) + column] = minmax(&gridFirst);
        //         }
        //
        //         // Middle columns - not mirrored
        //         var column: usize = radius;
        //         while (column < width_simd) : (column += vector_len) {
        //             var grid = GridV.initFromCenter(T, row, column, srcp, stride);
        //             const result = minmax(&grid);
        //             vec.storeAt(VT, dstp, row, column, stride, result);
        //         }
        //
        //         // Last columns - non-mirrored
        //         // We do this to minimize the use of scalar mirror code.
        //         if (width_simd < width) {
        //             const adjusted_column = width - vector_len - radius;
        //             var grid = GridV.initFromCenter(T, row, adjusted_column, srcp, stride);
        //             const result = minmax(&grid);
        //             vec.storeAt(VT, dstp, row, adjusted_column, stride, result);
        //         }
        //
        //         // Last columns - mirrored
        //         for (width - radius..width) |c| {
        //             var gridLast = GridS.initFromCenterMirrored(T, row, c, width, height, srcp, stride);
        //             dstp[(row * stride) + c] = minmax(&gridLast);
        //         }
        //     }
        //
        //     // Bottom rows - mirrored
        //     for (height - radius..height) |row| {
        //         for (0..width) |column| {
        //             var grid = GridS.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
        //             dstp[(row * stride) + column] = minmax(&grid);
        //         }
        //     }
        // }

        fn processPlane(radius: u8, noalias srcp8: []const u8, noalias dstp8: []u8, width: usize, height: usize, stride8: usize) void {
            const stride = stride8 / @sizeOf(T);
            const srcp: []const T = @ptrCast(@alignCast(srcp8));
            const dstp: []T = @ptrCast(@alignCast(dstp8));

            switch (radius) {
                // Custom vector version is substantially faster than auto-vectorized (scalar) version,
                // for both radius 1 and radius 2.
                // inline 1...3 => |r| processPlaneScalar(r, srcp, dstp, width, height, stride),
                inline 1...3 => |r| processPlaneVector(r, srcp, dstp, width, height, stride),
                else => unreachable,
            }
        }
    };
}

fn minmaxGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const zapi = ZAPI.init(vsapi, core, frame_ctx);
    const d: *MinMaxData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        zapi.requestFrameFilter(n, d.node);
    } else if (activation_reason == ar.AllFramesReady) {
        const src_frame = zapi.initZFrame(d.node, n);
        defer src_frame.deinit();

        const dst = src_frame.newVideoFrame2(d.process);

        const processPlane = switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &MinMax(u8).processPlane,
            .U16 => &MinMax(u16).processPlane,
            .F16 => &MinMax(f16).processPlane,
            .F32 => &MinMax(f32).processPlane,
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

export fn minmaxFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = core;
    const d: *MinMaxData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn minmaxCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = user_data;
    const zapi = ZAPI.init(vsapi, core, null);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);

    var d: MinMaxData = undefined;

    d.node, d.vi = inz.getNodeVi("clip").?;

    const numRadius: c_int = @intCast(inz.numElements("radius") orelse 0);
    if (numRadius > d.vi.format.numPlanes) {
        outz.setError("MinMax: Element count of radius must be less than or equal to the number of input planes.");
        zapi.freeNode(d.node);
        return;
    }

    if (numRadius > 0) {
        for (0..3) |i| {
            if (i < numRadius) {
                if (inz.getInt2(i32, "radius", i)) |radius| {
                    if (radius < 0 or radius > 3) {
                        outz.setError("MinMax: Invalid radius specified, only radius 0-3 supported.");
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
            vscmn.PlanesError.IndexOutOfRange => outz.setError("MinMax: Plane index out of range."),
            vscmn.PlanesError.SpecifiedTwice => outz.setError("MinMax: Plane specified twice."),
        }
        return;
    };

    d.process = [3]bool{
        planes[0] and d.radius[0] > 0,
        planes[1] and d.radius[1] > 0,
        planes[2] and d.radius[2] > 0,
    };

    const data: *MinMaxData = allocator.create(MinMaxData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
    };

    zapi.createVideoFilter(out, "Minimum", d.vi, minmaxGetFrame, minmaxFree, fm.Parallel, &deps, data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("Minimum", "clip:vnode;radius:int[]:opt;planes:int[]:opt;", "clip:vnode;", minmaxCreate, null, plugin);
}
