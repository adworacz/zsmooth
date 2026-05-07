const std = @import("std");
const vapoursynth = @import("vapoursynth");
const ZAPI = vapoursynth.ZAPI;
const testing = @import("std").testing;

const c = @cImport({
    @cInclude("fftw3.h");
});

const vscmn = @import("common/vapoursynth.zig");
const gridcmn = @import("common/array_grid.zig");
const vec = @import("common/vector.zig");
const math = @import("common/math.zig");

const float_mode: std.builtin.FloatMode = if (@import("config").optimize_float) .optimized else .strict;

const vs = vapoursynth.vapoursynth4;
const vsh = vapoursynth.vshelper;

const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;
const st = vs.SampleType;

const allocator = std.heap.c_allocator;

const DCT_SIDE_LEN = 8;
const DCT_SIZE = DCT_SIDE_LEN * DCT_SIDE_LEN;

const DCTFilterData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,

    vi: *const vs.VideoInfo,

    factors: []f32,
    dct_plan: c.fftwf_plan,
    idct_plan: c.fftwf_plan,

    // Which planes to process.
    process: [3]bool,
};

fn DCTFilter(comptime T: type) type {
    return struct {
        fn processPlane(noalias factors: []const f32, noalias buffer: []f32, dct_plan: c.fftwf_plan, idct_plan: c.fftwf_plan, _pixel_max: f32, noalias srcp8: []const u8, noalias dstp8: []u8, width: usize, height: usize, stride8: usize) void {
            std.debug.assert(factors.len == buffer.len);

            const stride = stride8 / @sizeOf(T);
            const srcp: []const T = @ptrCast(@alignCast(srcp8));
            const dstp: []T = @ptrCast(@alignCast(dstp8));
            const pixel_max: T = math.lossyCast(T, _pixel_max);

            var y: usize = 0;
            while (y < height) : (y += DCT_SIDE_LEN) {
                var x: usize = 0;
                while (x < width) : (x += DCT_SIDE_LEN) {
                    for (0..DCT_SIDE_LEN) |block_y| {
                        for (0..DCT_SIDE_LEN) |block_x| {
                            const index = stride * (y + block_y) + x + block_x;
                            buffer[DCT_SIDE_LEN * block_y + block_x] = switch (T) {
                                u8, u16 => @as(f32, @floatFromInt(srcp[index])) * (1.0 / 256.0),
                                else => srcp[index] * (1.0 / 256.0),
                            };
                        }
                    }

                    // Perform the DCT
                    c.fftwf_execute_r2r(dct_plan, buffer.ptr, buffer.ptr);

                    // Scale the DCT by factors
                    for (buffer, factors) |*b, factor| {
                        b.* *= factor;
                    }

                    // Reverse the DCT
                    c.fftwf_execute_r2r(idct_plan, buffer.ptr, buffer.ptr);

                    for (0..DCT_SIDE_LEN) |block_y| {
                        for (0..DCT_SIDE_LEN) |block_x| {
                            dstp[stride * (y + block_y) + x + block_x] = switch (T) {
                                u8 => @intFromFloat(@round(buffer[DCT_SIDE_LEN * block_y + block_x])),
                                u16 => std.math.clamp(@as(u16, @intFromFloat(@round(buffer[DCT_SIDE_LEN * block_y + block_x]))), 0, pixel_max),
                                f16 => @floatCast(buffer[DCT_SIDE_LEN * block_y + block_x]),
                                else => buffer[DCT_SIDE_LEN * block_y + block_x],
                            };
                        }
                    }
                }
            }
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

        const buffer = allocator.alignedAlloc(f32, .@"64", DCT_SIZE) catch {
            dst.deinit();
            zapi.setFilterError("DCTFilter: Unable to allocate memory for fftw buffer");
            return null;
        };
        defer allocator.free(buffer);

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

            const pixel_max = vscmn.getFormatMaximum(f32, d.vi.format, plane > 0);

            processPlane(d.factors, buffer, d.dct_plan, d.idct_plan, pixel_max, srcp8, dstp8, width, height, stride8);
        }

        return dst.frame;
    }

    return null;
}

export fn dctFilterFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = core;
    const d: *DCTFilterData = @ptrCast(@alignCast(instance_data));

    vsapi.?.freeNode.?(d.node);

    allocator.free(d.factors);

    {
        c.fftwf_make_planner_thread_safe();
        c.fftwf_destroy_plan(d.dct_plan);
        c.fftwf_destroy_plan(d.idct_plan);
    }

    allocator.destroy(d);
}

export fn dctFilterCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = user_data;
    const zapi = ZAPI.init(vsapi, core, null);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);

    var d: DCTFilterData = undefined;

    d.node, d.vi = inz.getNodeVi("clip").?;

    // Calculate any necessary padding to ensure the clip is mod 16
    const padWidth: u32 = if (d.vi.width & 15 != 0) 16 - @as(u32, @intCast(d.vi.width)) % 16 else 0;
    const padHeight: u32 = if (d.vi.height & 15 != 0) 16 - @as(u32, @intCast(d.vi.height)) % 16 else 0;
    const needsPadding = (padWidth != 0) or (padHeight != 0);

    const factors = inz.getFloatArray("factors") orelse {
        zapi.freeNode(d.node);
        outz.setError("DCTFilter: 'factors' must be specified");
        return;
    };

    for (factors) |f| if (f < 0.0 or f > 1.0) {
        zapi.freeNode(d.node);
        outz.setError("DCTFilter: 'factors' values must be between 0.0 and 1.0 (inclusive)");
        return;
    };

    d.factors = allocator.alloc(f32, DCT_SIZE) catch {
        zapi.freeNode(d.node);
        outz.setError("DCTFilter: Unable to allocate memory for factors");
        return;
    };

    for (0..DCT_SIDE_LEN) |y| {
        for (0..DCT_SIDE_LEN) |x| {
            d.factors[DCT_SIDE_LEN * y + x] = @floatCast(factors[y] * factors[x]);
        }
    }

    const fftw_buffer = allocator.alignedAlloc(f32, .@"64", DCT_SIZE) catch {
        zapi.freeNode(d.node);
        outz.setError("DCTFilter: Unable to allocate buffer for fftw");
        return;
    };
    defer allocator.free(fftw_buffer);

    {
        //Note: Because fftw is statically linked, locking via
        //fftwf_make_planner_thread_safe may not actually work.
        //
        //I'm honestly not sure.
        //
        //On the other hand, because of the static linking, it might not matter
        //as much, because we potentially aren't conflicting with other plugins
        //that might use dynamic linking. We still potentially conflict with
        //multiple instances of zsmooth though, so we need *some* kind of locking.
        c.fftwf_make_planner_thread_safe();
        d.dct_plan = c.fftwf_plan_r2r_2d(DCT_SIDE_LEN, DCT_SIDE_LEN, fftw_buffer.ptr, fftw_buffer.ptr, c.FFTW_REDFT10, c.FFTW_REDFT10, c.FFTW_PATIENT);
        d.idct_plan = c.fftwf_plan_r2r_2d(DCT_SIDE_LEN, DCT_SIDE_LEN, fftw_buffer.ptr, fftw_buffer.ptr, c.FFTW_REDFT01, c.FFTW_REDFT01, c.FFTW_PATIENT);
    }

    const planes = vscmn.normalizePlanes(d.vi.format, in, vsapi) catch |e| {
        zapi.freeNode(d.node);

        switch (e) {
            vscmn.PlanesError.IndexOutOfRange => outz.setError("DCTFilter: Plane index out of range."),
            vscmn.PlanesError.SpecifiedTwice => outz.setError("DCTFilter: Plane specified twice."),
        }
        return;
    };

    d.process = planes;

    // Add padding
    if (needsPadding) {
        const args = zapi.createZMap();
        defer args.free();

        _ = args.consumeNode("clip", d.node, .Replace);

        const width: u32 = @intCast(d.vi.width);
        const height: u32 = @intCast(d.vi.height);
        args.setInt("width", width + padWidth, .Replace);
        args.setInt("height", height + padHeight, .Replace);
        args.setFloat("src_width", @floatFromInt(width + padWidth), .Replace);
        args.setFloat("src_height", @floatFromInt(height + padHeight), .Replace);

        const ret = zapi.initZMap(zapi.invoke(zapi.getPluginByID(vsh.RESIZE_PLUGIN_ID), "Point", args.map));
        defer ret.free();

        if (ret.getError()) |e| {
            // Don't love this manual string length calculation, but it works for now.
            // Should probably upstream this to vapoursynth-zig
            const index = std.mem.indexOfSentinel(u8, 0, e);
            outz.setError(e[0..index :0]);
            return;
        }

        d.node, d.vi = ret.getNodeVi("clip").?;
    }

    const data: *DCTFilterData = allocator.create(DCTFilterData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
    };

    zapi.createVideoFilter(out, "DCTFilter", d.vi, dctFilterGetFrame, dctFilterFree, fm.Parallel, &deps, data);

    // Remove padding
    if (needsPadding) {
        const node = outz.getNode("clip");
        outz.clear();

        const args = zapi.createZMap();
        defer args.free();

        _ = args.consumeNode("clip", node, .Replace);
        args.setInt("right", padWidth, .Replace);
        args.setInt("bottom", padHeight, .Replace);

        const ret = zapi.initZMap(zapi.invoke(zapi.getPluginByID(vsh.STD_PLUGIN_ID), "Crop", args.map));
        defer ret.free();

        if (ret.getError()) |e| {
            // Don't love this manual string length calculation, but it works for now.
            // Should probably upstream this to vapoursynth-zig
            const index = std.mem.indexOfSentinel(u8, 0, e);
            outz.setError(e[0..index :0]);
            return;
        }

        _ = outz.consumeNode("clip", ret.getNode("clip"), .Replace);
    }
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("DCTFilter", "clip:vnode;factors:float[];planes:int[]:opt;", "clip:vnode;", dctFilterCreate, null, plugin);
}
