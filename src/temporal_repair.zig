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
        /// Clips the source pixel to the min and max of the prev, curr, and next frames from the repair clip.
        fn temporalRepairMode0(src: T, prev_repair: T, curr_repair: T, next_repair: T) T {
            const min = @min(prev_repair, curr_repair, next_repair);
            const max = @max(prev_repair, curr_repair, next_repair);

            return std.math.clamp(src, min, max);
        }

        /// Preserves more static detail than mode 0. Less sensitive to noise and small fluctations. 
        fn temporalRepairMode4(chroma: bool, src: T, prev_repair: T, curr_repair: T, next_repair: T) T {
            const subSat = math.subSat;
            const addSat = math.addSat;
            const tmax = if (chroma) types.getTypeMaximum(T, true) else types.getTypeMaximum(T, false);
            const tmin = if (chroma) types.getTypeMinimum(T, true) else types.getTypeMinimum(T, false);

            const brightest_neighbor = @max(prev_repair, next_repair);
            const darkest_neighbor = @min(prev_repair, next_repair);

            const diff_curr_darkest = subSat(curr_repair, darkest_neighbor, 0); // curr_repair -| darkest_neighbor
            const darkest_plus_weighted_diff = addSat(addSat(diff_curr_darkest, diff_curr_darkest, tmax), darkest_neighbor, tmax); // darkest_neighbor +| (diff_curr_darkest *| 2)

            const diff_curr_brightest = subSat(brightest_neighbor, curr_repair, 0); // brightest_neighbor -| curr_repair
            const brightest_minus_weighted_diff = subSat(brightest_neighbor, addSat(diff_curr_brightest, diff_curr_brightest, tmax), tmin); // brightest_neighbor -| (diff_curr_brightest *| 2)

            const upper = @min(darkest_plus_weighted_diff, brightest_neighbor); // clip dark weighted diff so it doesn't overshoot brightest neighbor
            const lower = @max(brightest_minus_weighted_diff, darkest_neighbor); // clip bright weigted diff so it doesn't undershoot darkest neighbor

            return if (darkest_neighbor == upper or brightest_neighbor == lower) curr_repair else std.math.clamp(src, lower, upper);
        }

        fn temporalRepair(mode: comptime_int, chroma: bool, src: T, prev_repair: T, curr_repair: T, next_repair: T) T {
            return switch (mode) {
                0 => temporalRepairMode0(src, prev_repair, curr_repair, next_repair),
                4 => temporalRepairMode4(chroma, src, prev_repair, curr_repair, next_repair),
                else => unreachable,
            };
        }

        fn processPlaneScalar(mode: comptime_int, chroma: bool, noalias srcp: []const T, noalias prev_repairp: []const T, noalias curr_repairp: []const T, noalias next_repairp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
            for (0..height) |row| {
                for (0..width) |column| {
                    const src = srcp[row * stride + column];
                    const prev_repair = prev_repairp[row * stride + column];
                    const curr_repair = curr_repairp[row * stride + column];
                    const next_repair = next_repairp[row * stride + column];

                    dstp[row * stride + column] = temporalRepair(mode, chroma, src, prev_repair, curr_repair, next_repair);
                }
            }
        }

        fn processPlane(mode: u8, chroma: bool, noalias srcp8: []const u8, noalias prev_repairp8: []const u8, noalias curr_repairp8: []const u8, noalias next_repairp8: []const u8, noalias dstp8: []u8, width: usize, height: usize, stride8: usize) void {
            const stride = stride8 / @sizeOf(T);
            const srcp: []const T = @ptrCast(@alignCast(srcp8));
            const prev_repairp: []const T = @ptrCast(@alignCast(prev_repairp8));
            const curr_repairp: []const T = @ptrCast(@alignCast(curr_repairp8));
            const next_repairp: []const T = @ptrCast(@alignCast(next_repairp8));
            const dstp: []T = @ptrCast(@alignCast(dstp8));

            switch (mode) {
                inline 0 => |r| processPlaneScalar(r, chroma, srcp, prev_repairp, curr_repairp, next_repairp, dstp, width, height, stride),
                inline 4 => |r| processPlaneScalar(r, chroma, srcp, prev_repairp, curr_repairp, next_repairp, dstp, width, height, stride),
                // inline 0...3 => |r| processPlaneScalar(r, srcp, prev_repairp, curr_repairp, next_repairp, dstp, width, height, stride),
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
            const chroma = d.vi.format.colorFamily == vs.ColorFamily.YUV and plane > 0;

            processPlane(d.mode[plane], chroma, srcp8, prev_repairp8, curr_repairp8, next_repairp8, dstp8, width, height, stride8);
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
