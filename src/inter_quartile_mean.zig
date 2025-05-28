const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;

const types = @import("common/type.zig");
const vscmn = @import("common/vapoursynth.zig");
const gridcmn = @import("common/grid.zig");
const string = @import("common/string.zig");
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

const InterQuartileMeanData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,

    vi: *const vs.VideoInfo,

    // The radius for each plane we will process.
    radius: [3]u5,
};

fn InterQuartileMean(comptime T: type) type {
    return struct {
        const UAT = types.UnsignedArithmeticType(T);
        const Grid = gridcmn.Grid(T);

        // Interquartile mean of 3x3 grid, including the center.
        fn iqm(grid: Grid) T {
            @setFloatMode(float_mode);

            const sorted = grid.sortWithCenter();

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

        test iqm {
            var data = [9]T{
                9, 8, 7,
                6, 5, 4,
                3, 2, 1,
            };

            var grid = Grid.init(T, &data, 3);

            try testing.expectEqual(5, iqm(grid));

            data = [9]T{
                1, 1,  3,
                3, 7,  8,
                9, 99, 99,
            };
            grid = Grid.init(T, &data, 3);

            try testing.expectEqual(6, iqm(grid));
        }

        fn interQuartileMean(radius: comptime_int, grid: Grid) T {
            return switch (radius) {
                1 => iqm(grid),
                else => unreachable,
            };
        }

        pub fn processPlaneScalar(radius: comptime_int, noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
            // Process top row with mirrored grid.
            for (0..width) |column| {
                const grid = Grid.initFromCenterMirrored(T, 0, column, width, height, srcp, stride);
                dstp[(0 * stride) + column] = interQuartileMean(radius, grid);
            }

            for (1..height - 1) |row| {
                // Process first pixel of the row with mirrored grid.
                const gridFirst = Grid.initFromCenterMirrored(T, row, 0, width, height, srcp, stride);
                dstp[(row * stride)] = interQuartileMean(radius, gridFirst);

                for (1..width - 1) |w| {
                    const rowCurr = ((row) * stride);
                    const top_left = ((row - 1) * stride) + w - 1;

                    // Use a non-mirrored grid everywhere else for maximum performance.
                    // We don't need the mirror effect anyways, as all pixels contain valid data.
                    const grid = Grid.init(T, srcp[top_left..], stride);

                    dstp[rowCurr + w] = interQuartileMean(radius, grid);
                }

                // Process last pixel of the row with mirrored grid.
                const gridLast = Grid.initFromCenterMirrored(T, row, width - 1, width, height, srcp, stride);
                dstp[(row * stride) + (width - 1)] = interQuartileMean(radius, gridLast);
            }

            // Process bottom row with mirrored grid.
            for (0..width) |column| {
                const grid = Grid.initFromCenterMirrored(T, height - 1, column, width, height, srcp, stride);
                dstp[((height - 1) * stride) + column] = interQuartileMean(radius, grid);
            }
        }

        fn getFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
            // Assign frame_data to nothing to stop compiler complaints
            _ = frame_data;

            const d: *InterQuartileMeanData = @ptrCast(@alignCast(instance_data));

            if (activation_reason == ar.Initial) {
                vsapi.?.requestFrameFilter.?(n, d.node, frame_ctx);
            } else if (activation_reason == ar.AllFramesReady) {
                const src_frame = vsapi.?.getFrameFilter.?(n, d.node, frame_ctx);

                defer vsapi.?.freeFrame.?(src_frame);

                const process = [_]bool{
                    d.radius[0] > 0,
                    d.radius[1] > 0,
                    d.radius[2] > 0,
                };

                const dst = vscmn.newVideoFrame(&process, src_frame, d.vi, core, vsapi);

                for (0..@intCast(d.vi.format.numPlanes)) |_plane| {
                    const plane: c_int = @intCast(_plane);
                    // Skip planes we aren't supposed to process
                    if (d.radius[_plane] == 0) {
                        continue;
                    }

                    const width: usize = @intCast(vsapi.?.getFrameWidth.?(dst, plane));
                    const height: usize = @intCast(vsapi.?.getFrameHeight.?(dst, plane));
                    const stride: usize = @as(usize, @intCast(vsapi.?.getStride.?(dst, plane))) / @sizeOf(T);
                    const srcp: []const T = @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frame, plane))))[0..(height * stride)];
                    const dstp: []T = @as([*]T, @ptrCast(@alignCast(vsapi.?.getWritePtr.?(dst, plane))))[0..(height * stride)];

                    switch (d.radius[_plane]) {
                        inline 1 => |radius| processPlaneScalar(radius, srcp, dstp, width, height, stride),
                        else => unreachable,
                    }
                }

                return dst;
            }

            return null;
        }
    };
}

export fn interQuartileMeanFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *InterQuartileMeanData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn interQuartileMeanCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    var d: InterQuartileMeanData = undefined;

    // TODO: Add error handling.
    var err: vs.MapPropertyError = undefined;

    d.node = vsapi.?.mapGetNode.?(in, "clip", 0, &err).?;
    d.vi = vsapi.?.getVideoInfo.?(d.node);

    const numRadius = vsapi.?.mapNumElements.?(in, "radius");
    if (numRadius > d.vi.format.numPlanes) {
        vsapi.?.mapSetError.?(out, "InterQuartileMean: Count of radius must be equal or fewer than the number of input planes.");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    for (0..3) |i| {
        if (i < numRadius) {
            if (vsh.mapGetN(i32, in, "radius", @intCast(i), vsapi)) |radius| {
                if (radius < 1 or radius > 1) {
                    vsapi.?.mapSetError.?(out, "InterQuartileMean: Invalid radius specified, only radius 1 supported.");
                    vsapi.?.freeNode.?(d.node);
                    return;
                }
                d.radius[i] = @intCast(radius);
            }
        } else {
            d.radius[i] = d.radius[i - 1];
        }
    }

    const data: *InterQuartileMeanData = allocator.create(InterQuartileMeanData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
    };

    const getFrame = switch (d.vi.format.bytesPerSample) {
        1 => &InterQuartileMean(u8).getFrame,
        2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &InterQuartileMean(u16).getFrame else &InterQuartileMean(f16).getFrame,
        4 => &InterQuartileMean(f32).getFrame,
        else => unreachable,
    };

    vsapi.?.createVideoFilter.?(out, "InterQuartileMean", d.vi, getFrame, interQuartileMeanFree, fm.Parallel, &deps, deps.len, data, core);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("InterQuartileMean", "clip:vnode;radius:int[];", "clip:vnode;", interQuartileMeanCreate, null, plugin);
}
