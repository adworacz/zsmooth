const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;

const types = @import("common/type.zig");
const math = @import("common/math.zig");
const vscmn = @import("common/vapoursynth.zig");
const sort = @import("common/sorting_networks.zig");
const gridcmn = @import("common/grid.zig");
const string = @import("common/string.zig");

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

    // The modes for each plane we will process.
    modes: [3]u5,
    threshold: [3]f32,

    // Soft thresholding params
    threshold_low: [3]f32,
    threshold_divisor: [3]f32,
};

fn InterQuartileMean(comptime T: type) type {
    return struct {
        /// Signed Arithmetic Type - used in signed arithmetic to safely hold
        /// the values (particularly integers) without overflowing when doing
        /// signed arithmetic.
        const SAT = switch (T) {
            u8 => i16,
            u16 => i32,
            f16 => f16,
            f32 => f32,
            else => unreachable,
        };

        /// Unsigned Arithmetic Type - used in unsigned arithmetic to safely
        /// hold values (particularly integers) without overflowing when doing
        /// unsigned arithmetic.
        const UAT = switch (T) {
            u8 => u16,
            u16 => u32,
            f16 => f16,
            f32 => f32,
            else => unreachable,
        };

        const Grid = gridcmn.Grid(T);

        // Interquartile mean of 3x3 grid, including the center.
        // fn iqm(grid: Grid, threshold: T) T {
        fn iqm(grid: Grid, threshold_low: T, threshold_divisor: T, minimum: T, maximum: T) T {
            const sorted = grid.sortWithCenter();

            // Trim the first and last quartile, then average the inner quartiles
            // https://en.wikipedia.org/wiki/Interquartile_mean#Dataset_size_not_divisible_by_four

            const floatFromInt = types.floatFromInt;
            const R = if (types.isInt(T)) f32 else T;

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
            // return result;
            // Thresholding appears to have a minimal effect on preformance (rather shockingly...). I'm seeing
            // a decrease from ~1090fps -> ~1055fps on my 9950x. So just a ~3.6% performance hit for the added flexibility.
            // The autovectorizer is doing is surprisingly good job with this code...
            // return if (math.absDiff(result, grid.center_center) <= threshold) result else grid.center_center;
            // const resultR: SAT = result;
            // const center: SAT = grid.center_center;
            // const min: SAT = minimum;
            // const max: SAT = maximum;
            // const resultR: f32 = @floatFromInt(result);
            // const center: f32 = @floatFromInt(grid.center_center);
            // const min: f32 = @floatFromInt(minimum);
            // const max: f32 = @floatFromInt(maximum);
            // const thr1: f32 = @floatFromInt(threshold_low);
            // const thrd: f32 = @floatFromInt(threshold_divisor);
            // const ths = center - ((resultR - center) * (std.math.clamp((maximum - ((@abs(resultR - center) - threshold_low) * threshold_divisor)), minimum, maximum) / maximum));
            // const ths = center - ((resultR - center) * @divExact(std.math.clamp((max - ((@abs(resultR - center) - thr1) * thrd)), min, max), max));

            // return math.lossyCast(T, ths);
            //
            const B = switch (T) {
                u8 => i32,
                u16 => i64,
                f16 => f32,
                f32 => f32,
                else => unreachable,
            };
            const diff: B = @as(B, result) - grid.center_center;
            const absdiff: T = math.absDiff(result, grid.center_center);
            const clamped_numerator: B = std.math.clamp(maximum - ((@as(B, absdiff) - threshold_low) * threshold_divisor), minimum, maximum);
            const weight: R = floatFromInt(R, clamped_numerator) / floatFromInt(R, maximum);
            const weighted_diff: SAT = @intFromFloat(@round(floatFromInt(R, diff) * weight));
            const thresholded_result = grid.center_center + weighted_diff;

            return math.lossyCast(T, thresholded_result);
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

        fn interQuartileMean(mode: comptime_int, grid: Grid, threshold_low: T, threshold_divisor: T, minimum: T, maximum: T) T {
            return switch (mode) {
                1 => iqm(grid, threshold_low, threshold_divisor, minimum, maximum),
                else => unreachable,
            };
        }

        // pub fn processPlaneScalar(mode: comptime_int, noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize, threshold: T) void {
        pub fn processPlaneScalar(mode: comptime_int, noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize, threshold_low: T, threshold_divisor: T, minimum: T, maximum: T) void {
            // Process top row with mirrored grid.
            for (0..width) |column| {
                const grid = Grid.initFromCenterMirrored(T, 0, column, width, height, srcp, stride);
                dstp[(0 * stride) + column] = interQuartileMean(mode, grid, threshold_low, threshold_divisor, minimum, maximum);
            }

            for (1..height - 1) |row| {
                // Process first pixel of the row with mirrored grid.
                const gridFirst = Grid.initFromCenterMirrored(T, row, 0, width, height, srcp, stride);
                dstp[(row * stride)] = interQuartileMean(mode, gridFirst, threshold_low, threshold_divisor, minimum, maximum);

                for (1..width - 1) |w| {
                    const rowCurr = ((row) * stride);
                    const top_left = ((row - 1) * stride) + w - 1;

                    // Use a non-mirrored grid everywhere else for maximum performance.
                    // We don't need the mirror effect anyways, as all pixels contain valid data.
                    const grid = Grid.init(T, srcp[top_left..], stride);

                    dstp[rowCurr + w] = interQuartileMean(mode, grid, threshold_low, threshold_divisor, minimum, maximum);
                }

                // Process last pixel of the row with mirrored grid.
                const gridLast = Grid.initFromCenterMirrored(T, row, width - 1, width, height, srcp, stride);
                dstp[(row * stride) + (width - 1)] = interQuartileMean(mode, gridLast, threshold_low, threshold_divisor, minimum, maximum);
            }

            // Process bottom row with mirrored grid.
            for (0..width) |column| {
                const grid = Grid.initFromCenterMirrored(T, height - 1, column, width, height, srcp, stride);
                dstp[((height - 1) * stride) + column] = interQuartileMean(mode, grid, threshold_low, threshold_divisor, minimum, maximum);
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
                    d.modes[0] > 0,
                    d.modes[1] > 0,
                    d.modes[2] > 0,
                };

                const dst = vscmn.newVideoFrame(&process, src_frame, d.vi, core, vsapi);

                for (0..@intCast(d.vi.format.numPlanes)) |_plane| {
                    const plane: c_int = @intCast(_plane);
                    // Skip planes we aren't supposed to process
                    if (d.modes[_plane] == 0) {
                        continue;
                    }

                    const width: usize = @intCast(vsapi.?.getFrameWidth.?(dst, plane));
                    const height: usize = @intCast(vsapi.?.getFrameHeight.?(dst, plane));
                    const stride: usize = @as(usize, @intCast(vsapi.?.getStride.?(dst, plane))) / @sizeOf(T);
                    const srcp: []const T = @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frame, plane))))[0..(height * stride)];
                    const dstp: []T = @as([*]T, @ptrCast(@alignCast(vsapi.?.getWritePtr.?(dst, plane))))[0..(height * stride)];
                    const chroma = d.vi.format.colorFamily == vs.ColorFamily.YUV and plane > 0;
                    const minimum = vscmn.getFormatMinimum(T, d.vi.format, chroma);
                    const maximum = vscmn.getFormatMaximum(T, d.vi.format, chroma);

                    switch (d.modes[_plane]) {
                        // inline 1 => |mode| processPlaneScalar(mode, srcp, dstp, width, height, stride, math.lossyCast(T, d.threshold[_plane])),
                        inline 1 => |mode| processPlaneScalar(mode, srcp, dstp, width, height, stride, math.lossyCast(T, d.threshold_low[_plane]), math.lossyCast(T, d.threshold_divisor[_plane]), minimum, maximum),
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

    var threshold = [3]f32{ 255, 255, 255 };
    var threshold_low = [3]f32{ 255, 255, 255 };
    var threshold_divisor = [3]f32{ 255, 255, 255 };
    const scalep = true;

    const numModes = vsapi.?.mapNumElements.?(in, "mode");
    if (numModes > d.vi.format.numPlanes) {
        vsapi.?.mapSetError.?(out, "InterQuartileMean: Number of modes must be equal or fewer than the number of input planes.");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    for (0..3) |i| {
        if (i < numModes) {
            if (vsh.mapGetN(i32, in, "mode", @intCast(i), vsapi)) |mode| {
                if (mode < 0 or mode > 24) {
                    vsapi.?.mapSetError.?(out, "InterQuartileMean: Invalid mode specified, only modes 0-1 supported.");
                    vsapi.?.freeNode.?(d.node);
                    return;
                }
                d.modes[i] = @intCast(mode);
            }
        } else {
            d.modes[i] = d.modes[i - 1];
        }

        if (vsh.mapGetN(f32, in, "threshold", @intCast(i), vsapi)) |thr| {
            threshold[i] = if (scalep and thr >= 0) thresh: {
                if (thr < 0 or thr > 255) {
                    vsapi.?.mapSetError.?(out, string.printf(allocator, "InterQuartileMean: Using parameter scaling (scalep), but threshold of {d} is outside the range of 0-255", .{thr}).ptr);
                    vsapi.?.freeNode.?(d.node);
                    return;
                }
                break :thresh vscmn.scaleToFormat(f32, d.vi.format, @intFromFloat(thr), 0);
            } else thr;

            // TODO: Fix threshold to work for all bit depths...
            const bias = @min(2 * @cos(std.math.pi + (2 * std.math.pi * threshold[i] / 255.0)) + 2, 1) * 20;
            const thr1 = @max(threshold[i] - 10 - bias, 0); // lower threshold
            const thr2 = @min(threshold[i] + 10 + bias, 255); // higher threshold
            const format_max = 255;
            const thrd = format_max / (thr2 - thr1);

            threshold_low[i] = thr1;
            threshold_divisor[i] = thrd;
        } else {
            threshold[i] = if (i == 0)
                vscmn.scaleToFormat(f32, d.vi.format, 255, 0)
            else
                threshold[i - 1];

            threshold_low[i] = if (i == 0)
                vscmn.scaleToFormat(f32, d.vi.format, 255, 0)
            else
                threshold_low[i - 1];

            threshold_divisor[i] = if (i == 0)
                vscmn.scaleToFormat(f32, d.vi.format, 255, 0)
            else
                threshold_divisor[i - 1];
        }
    }

    d.threshold = threshold;
    d.threshold_low = threshold_low;
    d.threshold_divisor = threshold_divisor;

    // https://github.com/Dogway/Avisynth-Scripts/blob/c6a837107afbf2aeffecea182d021862e9c2fc36/ExTools.avsi#L2484-L2492
    // # Soft threshold
    // bias =        min(2*cos(pi+2*pi*thr/255.)+2,1)*20           # Minimize soft threshold spread on extremes
    // thr1 = ex_bs( max(thr-10 - bias,   0), 8, bi, fulls=true, flt=true)
    // thr2 = ex_bs( min(thr+10 + bias, 255), 8, bi, fulls=true, flt=true)
    // mx   = ex_bs( 255,                     8, bi, fulls=true)
    // thrd = mx / (thr2 - thr1)
    // mx   = bi > 14 ? "range_max /" : string(1. / Eval(ex_dlut("range_max", bi, true))) + " *"
    // ths = mode!="EMF" && mode!="SNN" && !smart && !DGM && thr != 255 ?                                      \
    //       Format(" x swap - dup abs {thr1} - {thrd} * range_max swap - 0 range_max clip "+mx+" * x swap -") : ""

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
        // 2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &InterQuartileMean(u16).getFrame else &InterQuartileMean(f16).getFrame,
        // 4 => &InterQuartileMean(f32).getFrame,
        else => unreachable,
    };

    vsapi.?.createVideoFilter.?(out, "InterQuartileMean", d.vi, getFrame, interQuartileMeanFree, fm.Parallel, &deps, deps.len, data, core);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("InterQuartileMean", "clip:vnode;mode:int[];threshold:float[]:opt;", "clip:vnode;", interQuartileMeanCreate, null, plugin);
}
