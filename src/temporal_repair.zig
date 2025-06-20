const std = @import("std");
const vapoursynth = @import("vapoursynth");
const ZAPI = vapoursynth.ZAPI;
const testing = @import("std").testing;

const types = @import("common/type.zig");
const vscmn = @import("common/vapoursynth.zig");
const gridcmn = @import("common/array_grid.zig");
const vec = @import("common/vector.zig");

const math = @import("common/math.zig");
const subSat = math.subSat;
const addSat = math.addSat;

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

const TemporalRepairData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    repair_node: ?*vs.Node,

    vi: *const vs.VideoInfo,

    // The mode for each plane we will process.
    mode: [3]u5,

    // Which planes to process.
    process: [3]bool,
};

fn TemporalRepair(comptime T: type) type {
    return struct {
        const UAT = types.UnsignedArithmeticType(T);

        const Grid = gridcmn.ArrayGrid(3, T);

        /// Clips the source pixel to the min and max of the prev, curr, and next frames from the repair clip.
        fn temporalRepairMode0(src: T, prev_repair: T, curr_repair: T, next_repair: T) T {
            const min = @min(prev_repair, curr_repair, next_repair);
            const max = @max(prev_repair, curr_repair, next_repair);

            return std.math.clamp(src, min, max);
        }

        /// Preserves more static detail than mode 0. Less sensitive to noise and small fluctations.
        fn temporalRepairMode4(format_min: T, format_max: T, src: T, prev_repair: T, curr_repair: T, next_repair: T) T {
            // // Clamp float input so that we can perform proper addition/subtraction on it.
            // // Fixes an issue where illegal float input was producing negative values out of the addSat operation below.
            // const prev_repair = if (types.isInt(T)) _prev_repair else std.math.clamp(_prev_repair, format_min, format_max);
            // const curr_repair = if (types.isInt(T)) _curr_repair else std.math.clamp(_curr_repair, format_min, format_max);
            // const next_repair = if (types.isInt(T)) _next_repair else std.math.clamp(_next_repair, format_min, format_max);

            const brightest_neighbor = @max(prev_repair, next_repair);
            const darkest_neighbor = @min(prev_repair, next_repair);

            const diff_curr_darkest = subSat(curr_repair, darkest_neighbor, 0); // curr_repair -| darkest_neighbor
            const darkest_plus_weighted_diff = addSat(addSat(diff_curr_darkest, diff_curr_darkest, format_max), darkest_neighbor, format_max); // darkest_neighbor +| (diff_curr_darkest *| 2)

            const diff_curr_brightest = subSat(brightest_neighbor, curr_repair, 0); // brightest_neighbor -| curr_repair
            const brightest_minus_weighted_diff = subSat(brightest_neighbor, addSat(diff_curr_brightest, diff_curr_brightest, format_max), format_min); // brightest_neighbor -| (diff_curr_brightest *| 2)

            var upper = @min(darkest_plus_weighted_diff, brightest_neighbor); // clip dark weighted diff so it doesn't overshoot brightest neighbor
            const lower = @max(brightest_minus_weighted_diff, darkest_neighbor); // clip bright weigted diff so it doesn't undershoot darkest neighbor

            // Clamp the upper so that it can't be less than the lower, which
            // can happen for float content with illegal values after the addSat's above.
            upper = if (types.isFloat(T)) @max(upper, lower) else upper;

            return if (darkest_neighbor == upper or brightest_neighbor == lower) curr_repair else std.math.clamp(src, lower, upper);
        }

        fn temporalRepair(mode: comptime_int, format_min: T, format_max: T, src: T, prev_repair: T, curr_repair: T, next_repair: T) T {
            return switch (mode) {
                0 => temporalRepairMode0(src, prev_repair, curr_repair, next_repair),
                4 => temporalRepairMode4(format_min, format_max, src, prev_repair, curr_repair, next_repair),
                else => unreachable,
            };
        }

        /// Calculates the brightest and darkest temporal (repair) neighbors,
        /// and then returns two differences:
        /// A) saturated diff between brighest neighbor and current (repair)
        /// B) saturated diff between the current (repair) and darkest neighbor
        fn getExtremesDiffs(prev: T, curr: T, next: T) struct { T, T } {
            const brightest_neighbor = @max(prev, next);
            const darkest_neighbor = @min(prev, next);

            return .{
                subSat(brightest_neighbor, curr, 0), //brightest sat diff
                subSat(curr, darkest_neighbor, 0), //darkest sat diff
            };
        }

        fn spatialTemporalRepairMode1(format_min: T, format_max: T, src: T, prev_repair: Grid, curr_repair: Grid, next_repair: Grid) T {
            const center_idx = curr_repair.values.len / 2;
            var brightest_diff_max: T = 0;
            var darkest_diff_max: T = 0;

            // 'inline for' takes speed from ~500 fps -> ~576 fps.
            inline for (prev_repair.values, curr_repair.values, next_repair.values, 0..) |p, c, n, i| {
                // skip over the center pixel, as we don't want it included in the upper/lowermax values.
                if (i == center_idx) {
                    continue;
                }

                const brightest_sat_diff, const darkest_sat_diff = getExtremesDiffs(p, c, n);
                brightest_diff_max = @max(brightest_sat_diff, brightest_diff_max);
                darkest_diff_max = @max(darkest_sat_diff, darkest_diff_max);
            }

            const brightest_curr_diff = addSat(brightest_diff_max, curr_repair.values[center_idx], format_max);
            const darkest_curr_diff = subSat(curr_repair.values[center_idx], darkest_diff_max, format_min);

            const max = @max(brightest_curr_diff, prev_repair.values[center_idx], next_repair.values[center_idx]);
            const min = @min(darkest_curr_diff, prev_repair.values[center_idx], next_repair.values[center_idx]);

            return std.math.clamp(src, min, max);
        }

        fn spatialTemporalRepairMode2(format_min: T, format_max: T, src: T, prev_repair: Grid, curr_repair: Grid, next_repair: Grid) T {
            const center_idx = curr_repair.values.len / 2;
            var brightest_diff_max: T = 0;
            var darkest_diff_max: T = 0;

            // `inline for` of this loop seemed to offer little to no noticeable difference in speed.
            // Could be worth retesting on different architectures.
            for (prev_repair.values, curr_repair.values, next_repair.values) |p, c, n| {
                const brightest_sat_diff, const darkest_sat_diff = getExtremesDiffs(p, c, n);
                brightest_diff_max = @max(brightest_sat_diff, brightest_diff_max);
                darkest_diff_max = @max(darkest_sat_diff, darkest_diff_max);
            }

            const diff_max = @max(brightest_diff_max, darkest_diff_max);

            var curr_diff_upper = addSat(curr_repair.values[center_idx], diff_max, format_max);
            const curr_diff_lower = subSat(curr_repair.values[center_idx], diff_max, format_min);

            // Clamp the upper so that it can't be less than the lower, which
            // can happen for float content with illegal values after the addSat's above.
            curr_diff_upper = if (types.isFloat(T)) @max(curr_diff_upper, curr_diff_lower) else curr_diff_upper;

            return std.math.clamp(src, curr_diff_lower, curr_diff_upper);
        }

        /// Finds the absolute difference between the current frame and the previous + next frames.
        /// Returns the previous frame difference first, and the next frame difference second.
        fn getNeighborDiff(prev: T, curr: T, next: T) struct { T, T } {
            const pdiff = math.absDiff(curr, prev);
            const ndiff = math.absDiff(curr, next);

            return .{
                pdiff,
                ndiff,
            };
        }

        fn spatialTemporalRepairMode3(format_min: T, format_max: T, src: T, prev_repair: Grid, curr_repair: Grid, next_repair: Grid) T {
            const center_idx = curr_repair.values.len / 2;
            var prev_diff_max: T = 0;
            var next_diff_max: T = 0;

            for (prev_repair.values, curr_repair.values, next_repair.values) |p, c, n| {
                const prev_diff, const next_diff = getNeighborDiff(p, c, n);
                prev_diff_max = @max(prev_diff, prev_diff_max);
                next_diff_max = @max(next_diff, next_diff_max);
            }

            const diff_min = @min(prev_diff_max, next_diff_max);

            var curr_diff_upper = addSat(curr_repair.values[center_idx], diff_min, format_max);
            const curr_diff_lower = subSat(curr_repair.values[center_idx], diff_min, format_min);

            // Clamp the upper so that it can't be less than the lower, which
            // can happen for float content with illegal values after the addSat's above.
            curr_diff_upper = if (types.isFloat(T)) @max(curr_diff_upper, curr_diff_lower) else curr_diff_upper;

            return std.math.clamp(src, curr_diff_lower, curr_diff_upper);
        }

        fn spatialTemporalRepair(mode: comptime_int, format_min: T, format_max: T, src: T, prev_repair: Grid, curr_repair: Grid, next_repair: Grid) T {
            return switch (mode) {
                1 => spatialTemporalRepairMode1(format_min, format_max, src, prev_repair, curr_repair, next_repair),
                2 => spatialTemporalRepairMode2(format_min, format_max, src, prev_repair, curr_repair, next_repair),
                3 => spatialTemporalRepairMode3(format_min, format_max, src, prev_repair, curr_repair, next_repair),
                else => unreachable,
            };
        }

        fn processPlaneScalarTemporal(mode: comptime_int, format_min: T, format_max: T, noalias srcp: []const T, noalias prev_repairp: []const T, noalias curr_repairp: []const T, noalias next_repairp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
            for (0..height) |row| {
                for (0..width) |column| {
                    const src = srcp[row * stride + column];
                    const prev_repair = prev_repairp[row * stride + column];
                    const curr_repair = curr_repairp[row * stride + column];
                    const next_repair = next_repairp[row * stride + column];

                    dstp[row * stride + column] = temporalRepair(mode, format_min, format_max, src, prev_repair, curr_repair, next_repair);
                }
            }
        }

        fn processPlaneScalarSpatialTemporal(mode: comptime_int, format_min: T, format_max: T, noalias srcp: []const T, noalias prev_repairp: []const T, noalias curr_repairp: []const T, noalias next_repairp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
            // Process top rows with mirrored grid.
            for (0..width) |column| {
                const src = srcp[0 * stride + column];
                const prev = Grid.initFromCenterMirrored(T, 0, column, width, height, prev_repairp, stride);
                const curr = Grid.initFromCenterMirrored(T, 0, column, width, height, curr_repairp, stride);
                const next = Grid.initFromCenterMirrored(T, 0, column, width, height, next_repairp, stride);
                dstp[(0 * stride) + column] = spatialTemporalRepair(mode, format_min, format_max, src, prev, curr, next);
            }

            for (1..height - 1) |row| {
                // Process first pixels of the row with mirrored grid.
                const src_first = srcp[row * stride + 0];
                const prev_first = Grid.initFromCenterMirrored(T, row, 0, width, height, prev_repairp, stride);
                const curr_first = Grid.initFromCenterMirrored(T, row, 0, width, height, curr_repairp, stride);
                const next_first = Grid.initFromCenterMirrored(T, row, 0, width, height, next_repairp, stride);
                dstp[(row * stride) + 0] = spatialTemporalRepair(mode, format_min, format_max, src_first, prev_first, curr_first, next_first);

                for (1..width - 1) |column| {
                    // Use a non-mirrored grid everywhere else for maximum performance.
                    // We don't need the mirror effect anyways, as all pixels contain valid data.
                    const src = srcp[row * stride + column];
                    const prev = Grid.initFromCenter(T, row, column, prev_repairp, stride);
                    const curr = Grid.initFromCenter(T, row, column, curr_repairp, stride);
                    const next = Grid.initFromCenter(T, row, column, next_repairp, stride);

                    dstp[(row * stride) + column] = spatialTemporalRepair(mode, format_min, format_max, src, prev, curr, next);
                }

                // Process last pixel of the row with mirrored grid.
                const src_last = srcp[row * stride + (width - 1)];
                const prev_last = Grid.initFromCenterMirrored(T, row, width - 1, width, height, prev_repairp, stride);
                const curr_last = Grid.initFromCenterMirrored(T, row, width - 1, width, height, curr_repairp, stride);
                const next_last = Grid.initFromCenterMirrored(T, row, width - 1, width, height, next_repairp, stride);
                dstp[(row * stride) + (width - 1)] = spatialTemporalRepair(mode, format_min, format_max, src_last, prev_last, curr_last, next_last);
            }

            // Process bottom rows with mirrored grid.
            for (0..width) |column| {
                const src = srcp[(height - 1) * stride + column];
                const prev = Grid.initFromCenterMirrored(T, height - 1, column, width, height, prev_repairp, stride);
                const curr = Grid.initFromCenterMirrored(T, height - 1, column, width, height, curr_repairp, stride);
                const next = Grid.initFromCenterMirrored(T, height - 1, column, width, height, next_repairp, stride);
                dstp[((height - 1) * stride) + column] = spatialTemporalRepair(mode, format_min, format_max, src, prev, curr, next);
            }
        }

        fn processPlane(mode: u8, chroma: bool, bits_per_sample: u6, noalias srcp8: []const u8, noalias prev_repairp8: []const u8, noalias curr_repairp8: []const u8, noalias next_repairp8: []const u8, noalias dstp8: []u8, width: usize, height: usize, stride8: usize) void {
            const stride = stride8 / @sizeOf(T);
            const srcp: []const T = @ptrCast(@alignCast(srcp8));
            const prev_repairp: []const T = @ptrCast(@alignCast(prev_repairp8));
            const curr_repairp: []const T = @ptrCast(@alignCast(curr_repairp8));
            const next_repairp: []const T = @ptrCast(@alignCast(next_repairp8));
            const dstp: []T = @ptrCast(@alignCast(dstp8));

            const format_max = vscmn.getFormatMaximum2(T, bits_per_sample, chroma);
            const format_min = vscmn.getFormatMinimum2(T, chroma);

            switch (mode) {
                inline 0 => |r| processPlaneScalarTemporal(r, format_min, format_max, srcp, prev_repairp, curr_repairp, next_repairp, dstp, width, height, stride),
                inline 1 => |r| processPlaneScalarSpatialTemporal(r, format_min, format_max, srcp, prev_repairp, curr_repairp, next_repairp, dstp, width, height, stride),
                inline 2 => |r| processPlaneScalarSpatialTemporal(r, format_min, format_max, srcp, prev_repairp, curr_repairp, next_repairp, dstp, width, height, stride),
                inline 3 => |r| processPlaneScalarSpatialTemporal(r, format_min, format_max, srcp, prev_repairp, curr_repairp, next_repairp, dstp, width, height, stride),
                inline 4 => |r| processPlaneScalarTemporal(r, format_min, format_max, srcp, prev_repairp, curr_repairp, next_repairp, dstp, width, height, stride),
                else => unreachable,
            }
        }
    };
}

fn temporalRepairGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const zapi = ZAPI.init(vsapi, core);
    const d: *TemporalRepairData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        zapi.requestFrameFilter(n, d.node, frame_ctx);

        // Request the previous, current, and next frames from repair clip.
        const start: usize = @max(n - 1, 0);
        const end: usize = @intCast(@min(n + 1, d.vi.numFrames - 1));
        for (start..end + 1) |i| { // end + 1 because .. range syntax is exclusive.
            zapi.requestFrameFilter(@intCast(i), d.repair_node, frame_ctx);
        }
    } else if (activation_reason == ar.AllFramesReady) {
        // Skip the first and last frames since we can't process them temporally.
        if (n < 1 or n > d.vi.numFrames - 2) {
            return zapi.getFrameFilter(n, d.node, frame_ctx);
        }

        const src = zapi.initZFrame(d.node, n, frame_ctx);
        const prev_repair = zapi.initZFrame(d.repair_node, n - 1, frame_ctx);
        const curr_repair = zapi.initZFrame(d.repair_node, n, frame_ctx);
        const next_repair = zapi.initZFrame(d.repair_node, n + 1, frame_ctx);

        defer {
            src.deinit();
            prev_repair.deinit();
            curr_repair.deinit();
            next_repair.deinit();
        }

        const dst = src.newVideoFrame2(d.process);

        const processPlane: @TypeOf(&TemporalRepair(u8).processPlane) = switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &TemporalRepair(u8).processPlane,
            .U16 => &TemporalRepair(u16).processPlane,
            .F16 => &TemporalRepair(f16).processPlane,
            .F32 => &TemporalRepair(f32).processPlane,
        };

        for (0..@intCast(d.vi.format.numPlanes)) |plane| {
            // Skip planes we aren't supposed to process
            if (!d.process[plane]) {
                continue;
            }

            const width: usize = dst.getWidth(plane);
            const height: usize = dst.getHeight(plane);
            const stride8: usize = dst.getStride(plane);
            const srcp8: []const u8 = src.getReadSlice(plane);
            const prev_repairp8: []const u8 = prev_repair.getReadSlice(plane);
            const curr_repairp8: []const u8 = curr_repair.getReadSlice(plane);
            const next_repairp8: []const u8 = next_repair.getReadSlice(plane);
            const dstp8: []u8 = dst.getWriteSlice(plane);
            const chroma = vscmn.isChromaPlane(d.vi.format.colorFamily, plane);
            const bits_per_sample: u6 = @intCast(d.vi.format.bitsPerSample);

            processPlane(d.mode[plane], chroma, bits_per_sample, srcp8, prev_repairp8, curr_repairp8, next_repairp8, dstp8, width, height, stride8);
        }

        return dst.frame;
    }

    return null;
}

export fn temporalRepairFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *TemporalRepairData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    vsapi.?.freeNode.?(d.repair_node);
    allocator.destroy(d);
}

export fn temporalRepairCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    const zapi = ZAPI.init(vsapi, core);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);

    var d: TemporalRepairData = undefined;

    d.node, d.vi = inz.getNodeVi("clip").?;
    d.repair_node = inz.getNode("repairclip");

    if (!vsh.isSameVideoInfo(d.vi, zapi.getVideoInfo(d.repair_node))) {
        outz.setError("TemporalRepair: Input clips must have the same format.");
        zapi.freeNode(d.node);
        zapi.freeNode(d.repair_node);
        return;
    }

    const numMode: c_int = @intCast(inz.numElements("mode") orelse 0);
    if (numMode > d.vi.format.numPlanes) {
        outz.setError("TemporalRepair: Element count of mode must be less than or equal to the number of input planes.");
        zapi.freeNode(d.node);
        zapi.freeNode(d.repair_node);
        return;
    }

    if (numMode > 0) {
        for (0..3) |i| {
            if (i < numMode) {
                if (inz.getInt(i32, "mode")) |mode| {
                    if (mode < 0 or mode > 4) {
                        outz.setError("TemporalRepair: Invalid mode specified, only mode 0-4 supported.");
                        zapi.freeNode(d.node);
                        zapi.freeNode(d.repair_node);
                        return;
                    }
                    d.mode[i] = @intCast(mode);
                }
            } else {
                d.mode[i] = d.mode[i - 1];
            }
        }
    } else {
        // Default mode
        d.mode = .{ 0, 0, 0 };
    }

    d.process = vscmn.normalizePlanes(d.vi.format, in, vsapi) catch |e| {
        zapi.freeNode(d.node);
        zapi.freeNode(d.repair_node);

        switch (e) {
            vscmn.PlanesError.IndexOutOfRange => outz.setError("TemporalRepair: Plane index out of range."),
            vscmn.PlanesError.SpecifiedTwice => outz.setError("TemporalRepair: Plane specified twice."),
        }
        return;
    };

    const data: *TemporalRepairData = allocator.create(TemporalRepairData) catch unreachable;
    data.* = d;

    // We only request the current frame from the source clip, but we request
    // the previous, current, and next frames from the repair clip.
    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
        vs.FilterDependency{
            .source = d.repair_node,
            .requestPattern = rp.General,
        },
    };

    zapi.createVideoFilter(out, "TemporalRepair", d.vi, temporalRepairGetFrame, temporalRepairFree, fm.Parallel, &deps, data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("TemporalRepair", "clip:vnode;repairclip:vnode;mode:int[]:opt;planes:int[]:opt;", "clip:vnode;", temporalRepairCreate, null, plugin);
}
