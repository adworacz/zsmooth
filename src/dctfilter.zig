const std = @import("std");
const vapoursynth = @import("vapoursynth");
const ZAPI = vapoursynth.ZAPI;
const testing = @import("std").testing;

const vscmn = @import("common/vapoursynth.zig");
const gridcmn = @import("common/array_grid.zig");
const vec = @import("common/vector.zig");

const float_mode: std.builtin.FloatMode = if (@import("config").optimize_float) .optimized else .strict;

const vs = vapoursynth.vapoursynth4;

const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;
const st = vs.SampleType;

const allocator = std.heap.c_allocator;

const DCTFilterData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,

    vi: *const vs.VideoInfo,

    // Which planes to process.
    process: [3]bool,
};

fn DCTFilter(comptime T: type) type {
    return struct {
        fn processPlane(radius: u8, noalias srcp8: []const u8, noalias dstp8: []u8, width: usize, height: usize, stride8: usize) void {
            const stride = stride8 / @sizeOf(T);
            const srcp: []const T = @ptrCast(@alignCast(srcp8));
            const dstp: []T = @ptrCast(@alignCast(dstp8));
        }
    };
}

fn dctFilterGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const zapi = ZAPI.init(vsapi, core, frame_ctx);
    const d: *DCTFilterData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        zapi.requestFrameFilter(n, d.node);
    } else if (activation_reason == ar.AllFramesReady) {
        const src_frame = zapi.initZFrame(d.node, n);
        defer src_frame.deinit();

        const dst = src_frame.newVideoFrame2(d.process);

        const processPlane = switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &DCTFilter(u8).processPlane,
            .U16 => &DCTFilter(u16).processPlane,
            .F16 => &DCTFilter(f16).processPlane,
            .F32 => &DCTFilter(f32).processPlane,
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

export fn dctFilterFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = core;
    const d: *DCTFilterData = @ptrCast(@alignCast(instance_data));

    vsapi.?.freeNode.?(d.node);

    allocator.destroy(d);
}

export fn dctFilterCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = user_data;
    const zapi = ZAPI.init(vsapi, core, null);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);

    var d: DCTFilterData = undefined;

    d.node, d.vi = inz.getNodeVi("clip").?;


    const planes = vscmn.normalizePlanes(d.vi.format, in, vsapi) catch |e| {
        zapi.freeNode(d.node);

        switch (e) {
            vscmn.PlanesError.IndexOutOfRange => outz.setError("DCTFilter: Plane index out of range."),
            vscmn.PlanesError.SpecifiedTwice => outz.setError("DCTFilter: Plane specified twice."),
        }
        return;
    };

    d.process = [3]bool{
        planes[0] and d.radius[0] > 0,
        planes[1] and d.radius[1] > 0,
        planes[2] and d.radius[2] > 0,
    };

    const data: *DCTFilterData = allocator.create(DCTFilterData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
    };

    zapi.createVideoFilter(out, "DCTFilter", d.vi, dctFilterGetFrame, dctFilterFree, fm.Parallel, &deps, data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("DCTFilter", "clip:vnode;factors:float[];planes:int[]:opt;n:int:opt;qps:float[]:opt;", "clip:vnode;", dctFilterCreate, null, plugin);
}
