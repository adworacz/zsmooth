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

const Cnr3Data = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,

    vi: *const vs.VideoInfo,

    table_y: []u8,
    table_u: []u8,
    table_v: []u8,

    // Which planes to process.
    process: [3]bool,
};

fn Cnr3(comptime T: type) type {
    return struct {
        fn processPlane() void {}
    };
}

fn cnr3GetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const zapi = ZAPI.init(vsapi, core, frame_ctx);
    const d: *Cnr3Data = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        zapi.requestFrameFilter(n, d.node);
    } else if (activation_reason == ar.AllFramesReady) {
        const src_frame = zapi.initZFrame(d.node, n);
        defer src_frame.deinit();

        const dst = src_frame.newVideoFrame2(d.process);

        const processPlane = switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &Cnr3(u8).processPlane,
            // .U16 => &Cnr3(u16).processPlane,
            // .F16 => &Cnr3(f16).processPlane,
            // .F32 => &Cnr3(f32).processPlane,
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

            processPlane();
        }

        return dst.frame;
    }

    return null;
}

export fn cnr3Free(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = core;
    const d: *Cnr3Data = @ptrCast(@alignCast(instance_data));

    vsapi.?.freeNode.?(d.node);

    allocator.free(d.table_y);
    allocator.free(d.table_u);
    allocator.free(d.table_v);

    allocator.destroy(d);
}

export fn cnr3Create(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = user_data;
    const zapi = ZAPI.init(vsapi, core, null);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);

    var d: Cnr3Data = undefined;

    d.node, d.vi = inz.getNodeVi("clip").?;

    if (!vsh.isConstantVideoFormat(d.vi) or
        d.vi.format.colorFamily != .YUV or
        d.vi.format.sampleType != .Integer or
        d.vi.format.bitsPerSample != 8 or // TODO fix this
        d.vi.format.subSamplingW > 1 or
        d.vi.format.subSamplingH > 1)
    {
        outz.setError("Cnr3: clip must have constant format and dimensions, and it must be integer YUV420, YUV422, YUV440, or YUV444.");
        zapi.freeNode(d.node);
        return;
    }

    const mode: []const u8 = if (inz.getData("mode", 0)) |_mode| blk: {
        if (_mode.len != 3) {
            outz.setError("Cnr3: mode must have 3 characters");
            zapi.freeNode(d.node);
            return;
        }
        break :blk _mode;
    } else "oxx";

    // Sensitivies
    const l_sense: u8 = if (inz.getInt(i32, "ln")) |ln| blk: {
        if (ln < 0 or ln > 255) {
            outz.setError("Cnr3: ln must be between 0 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk @intCast(ln);
    } else 35;

    const u_sense: u8 = if (inz.getInt(i32, "un")) |un| blk: {
        if (un < 0 or un > 255) {
            outz.setError("Cnr3: un must be between 0 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk @intCast(un);
    } else 47;

    const v_sense: u8 = if (inz.getInt(i32, "vn")) |vn| blk: {
        if (vn < 0 or vn > 255) {
            outz.setError("Cnr3: vn must be between 0 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk @intCast(vn);
    } else 47;

    // Strengths
    const l_str: u8 = if (inz.getInt(i32, "lm")) |lm| blk: {
        if (lm < 0 or lm > 255) {
            outz.setError("Cnr3: lm must be between 0 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk @intCast(lm);
    } else 192;

    const u_str: u8 = if (inz.getInt(i32, "um")) |um| blk: {
        if (um < 0 or um > 255) {
            outz.setError("Cnr3: um must be between 0 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk @intCast(um);
    } else 255;

    const v_str: u8 = if (inz.getInt(i32, "vm")) |vm| blk: {
        if (vm < 0 or vm > 255) {
            outz.setError("Cnr3: vm must be between 0 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk @intCast(vm);
    } else 255;

    // Using an aligned alloc for potential SIMD/autovec friendliness
    // Might not make any difference, but it doesn't hurt
    const table_size = 256 + 1;
    d.table_y = allocator.alignedAlloc(u8, .@"64", table_size) catch {
        outz.setError("Cnr3: Unable to allocate memory for internal tables");
        zapi.freeNode(d.node);
        return;
    };
    d.table_u = allocator.alignedAlloc(u8, .@"64", table_size) catch {
        outz.setError("Cnr3: Unable to allocate memory for internal tables");
        zapi.freeNode(d.node);
        return;
    };
    d.table_v = allocator.alignedAlloc(u8, .@"64", table_size) catch {
        outz.setError("Cnr3: Unable to allocate memory for internal tables");
        zapi.freeNode(d.node);
        return;
    };

    // Zero out all weights
    @memset(d.table_y, 0);
    @memset(d.table_u, 0);
    @memset(d.table_v, 0);

    const l_strf: f32 = @floatFromInt(l_str);
    const l_sensef: f32 = @floatFromInt(l_sense);
    const u_strf: f32 = @floatFromInt(u_str);
    const u_sensef: f32 = @floatFromInt(u_sense);
    const v_strf: f32 = @floatFromInt(v_str);
    const v_sensef: f32 = @floatFromInt(v_sense);

    var l: u8 = 0;
    while (l <= l_str) : (l += 1) {
        const lf: f32 = @floatFromInt(l);
        d.table_y[l] = switch (mode[0]) {
            'o' => @intFromFloat(l_strf / 2 * (1 + @cos(lf * lf * std.math.pi / (l_sensef * l_sensef)))),
            'x' => @intFromFloat(l_strf / 2 * (1 + @cos(lf * std.math.pi / l_sensef))),
            else => {
                outz.setError("Cnr3: Only 'o' and 'x' are recognized characters in mode");
                zapi.freeNode(d.node);
                return;
            },
        };
    }

    var u: u8 = 0;
    while (u <= u_str) : (u += 1) {
        const uf: f32 = @floatFromInt(u);
        d.table_u[u] = switch (mode[1]) {
            'o' => @intFromFloat(u_strf / 2 * (1 + @cos(uf * uf * std.math.pi / (u_sensef * u_sensef)))),
            'x' => @intFromFloat(u_strf / 2 * (1 + @cos(uf * std.math.pi / u_sensef))),
            else => {
                outz.setError("Cnr3: Only 'o' and 'x' are recognized characters in mode");
                zapi.freeNode(d.node);
                return;
            },
        };
    }

    var v: u8 = 0;
    while (v <= v_str) : (v += 1) {
        const vf: f32 = @floatFromInt(v);
        d.table_v[l] = switch (mode[2]) {
            'o' => @intFromFloat(v_strf / 2 * (1 + @cos(vf * vf * std.math.pi / (v_sensef * v_sensef)))),
            'x' => @intFromFloat(v_strf / 2 * (1 + @cos(vf * std.math.pi / v_sensef))),
            else => {
                outz.setError("Cnr3: Only 'o' and 'x' are recognized characters in mode");
                zapi.freeNode(d.node);
                return;
            },
        };
    }

    const data: *Cnr3Data = allocator.create(Cnr3Data) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.General,
        },
    };

    zapi.createVideoFilter(out, "Cnr3", d.vi, cnr3GetFrame, cnr3Free, fm.Parallel, &deps, data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("Cnr3", "clip:vnode;" ++
        "mode:data:opt;" ++
        "scdthr:int:opt;" ++
        "ln:int:opt;" ++
        "lm:int:opt;" ++
        "un:int:opt;" ++
        "um:int:opt;" ++
        "vn:int:opt;" ++
        "vm:int:opt;" ++
        "scenechroma:int:opt;", "clip:vnode;", cnr3Create, null, plugin);
}
