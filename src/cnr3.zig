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
const types = @import("common/type.zig");

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
};

fn Cnr3(comptime T: type) type {
    const UAT = types.UnsignedArithmeticType(T);
    const BUAT = types.BigUnsignedArithmeticType(T);

    return struct {
        const DownSampleOpts = struct {
            dst_width: usize,
            dst_height: usize,
            dst_stride: usize,
            src_stride: usize,
            subsampling_h: u2,
            subsampling_w: u2,
        };

        fn downSampleLuma(noalias srcp: []const T, noalias dstp: []T, opt: DownSampleOpts) void {
            for (0..opt.dst_height) |y| {
                for (0..opt.dst_width) |x| {
                    const dst_index = y * opt.dst_stride + x;
                    const src_x = x << opt.subsampling_w;
                    const src_index = (y * opt.src_stride << opt.subsampling_h) + src_x;

                    dstp[dst_index] = @intCast((@as(UAT, srcp[src_index]) +
                        srcp[src_index + opt.subsampling_w] +
                        srcp[src_index + (opt.src_stride * opt.subsampling_h)] +
                        srcp[src_index + (opt.src_stride * opt.subsampling_h) + opt.subsampling_w] + 2) >> 2);
                }
            }
        }

        fn processFrame(prev8: [3][]const u8, curr8: [3][]const u8, dstp8: [2][]u8, scratch_y8: [2][]u8, tables: [3][]const u8, opt: struct {
            width_y: usize,
            height_y: usize,
            width_uv: usize,
            height_uv: usize,
            stride_y: usize,
            stride_uv: usize,
            stride_scratch: usize,
            subsampling_h: u2,
            subsampling_w: u2,
        }) void {
            const prev: [3][]const T = .{
                @ptrCast(prev8[0]),
                @ptrCast(prev8[1]),
                @ptrCast(prev8[2]),
            };

            const curr: [3][]const T = .{
                @ptrCast(curr8[0]),
                @ptrCast(curr8[1]),
                @ptrCast(curr8[2]),
            };

            const dst_u: []T = @ptrCast(dstp8[0]);
            const dst_v: []T = @ptrCast(dstp8[1]);

            const prev_y: []T = @ptrCast(scratch_y8[0]);
            const curr_y: []T = @ptrCast(scratch_y8[1]);

            const prev_u = prev[1];
            const curr_u = curr[1];

            const prev_v = prev[2];
            const curr_v = prev[2];

            const table_y = tables[0];
            const table_u = tables[1];
            const table_v = tables[2];

            const downsample_opts: DownSampleOpts = .{
                .dst_width = opt.width_y >> opt.subsampling_w,
                .dst_height = opt.height_y >> opt.subsampling_h,
                .dst_stride = opt.stride_scratch,
                .src_stride = opt.stride_y,
                .subsampling_w = opt.subsampling_w,
                .subsampling_h = opt.subsampling_h,
            };

            downSampleLuma(prev[0], prev_y, downsample_opts);
            downSampleLuma(curr[0], curr_y, downsample_opts);

            for (0..opt.height_uv) |y| {
                for (0..opt.width_uv) |x| {
                    const y_index = y * opt.stride_scratch + x;
                    const uv_index = y * opt.stride_uv + x;
                    const abs_diff_y = math.absDiff(curr_y[y_index], prev_y[y_index]);
                    const abs_diff_u = math.absDiff(curr_u[uv_index], prev_u[uv_index]);
                    const abs_diff_v = math.absDiff(curr_v[uv_index], prev_v[uv_index]);

                    const weight_u: BUAT = @as(UAT, table_y[abs_diff_y]) * table_u[abs_diff_u];
                    const weight_v: BUAT = @as(UAT, table_y[abs_diff_y]) * table_v[abs_diff_v];

                    const max = std.math.maxInt(T) * std.math.maxInt(T);
                    const shift = @typeInfo(UAT).int.bits;
                    const round = 1 << (shift - 1);

                    dst_u[uv_index] = @intCast((weight_u * prev_u[uv_index] + (max - weight_u) * curr_u[uv_index] + round) >> shift);
                    dst_v[uv_index] = @intCast((weight_v * prev_v[uv_index] + (max - weight_v) * curr_v[uv_index] + round) >> shift);
                }
            }
        }
    };
}

fn cnr3GetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const zapi = ZAPI.init(vsapi, core, frame_ctx);
    const d: *Cnr3Data = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        zapi.requestFrameFilter(@max(n - 1, 0), d.node);
        zapi.requestFrameFilter(n, d.node);
    } else if (activation_reason == ar.AllFramesReady) {
        // Don't process the first and last frames
        if (n < 1) {
            //TODO: Handle this case better when I support bidirectional filtering,
            //since we can use the next frame for filtering.
            return zapi.getFrameFilter(n, d.node);
        }

        const prev_frame = zapi.initZFrame(d.node, n - 1);
        defer prev_frame.deinit();

        const curr_frame = zapi.initZFrame(d.node, n);
        defer curr_frame.deinit();

        // copy the luma plane only
        const dst = curr_frame.newVideoFrame2(.{ false, true, true });

        var grey_format: vs.VideoFormat = undefined;
        _ = zapi.queryVideoFormat(&grey_format, .Gray, d.vi.format.sampleType, d.vi.format.bitsPerSample, 0, 0);

        // Allocate scratch buffers for downsampled luma planes
        const prev_y = ZAPI.ZFrame(*vs.Frame).init(&zapi, zapi.newVideoFrame(&grey_format, d.vi.width >> @intCast(d.vi.format.subSamplingW), d.vi.height >> @intCast(d.vi.format.subSamplingH), null).?);
        const curr_y = ZAPI.ZFrame(*vs.Frame).init(&zapi, zapi.newVideoFrame(&grey_format, d.vi.width >> @intCast(d.vi.format.subSamplingW), d.vi.height >> @intCast(d.vi.format.subSamplingH), null).?);
        defer {
            prev_y.deinit();
            curr_y.deinit();
        }

        const processFrame = switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &Cnr3(u8).processFrame,
            else => unreachable,
            // .U16 => &Cnr3(u16).processPlane,
            // .F16 => &Cnr3(f16).processPlane,
            // .F32 => &Cnr3(f32).processPlane,
        };

        processFrame(.{
            prev_frame.getReadSlice(0),
            prev_frame.getReadSlice(1),
            prev_frame.getReadSlice(2),
        }, .{
            curr_frame.getReadSlice(0),
            curr_frame.getReadSlice(1),
            curr_frame.getReadSlice(2),
        }, .{
            // Only writing to the chroma planes
            dst.getWriteSlice(1),
            dst.getWriteSlice(2),
        }, .{
            prev_y.getWriteSlice(0),
            curr_y.getWriteSlice(0),
        }, .{
            d.table_y,
            d.table_u,
            d.table_v,
        }, .{
            .width_y = curr_frame.getWidth(0),
            .width_uv = curr_frame.getWidth(1),

            .height_y = curr_frame.getHeight(0),
            .height_uv = curr_frame.getHeight(1),

            .stride_y = dst.getStride(0),
            .stride_uv = dst.getStride(1),

            .stride_scratch = prev_y.getStride(0),
            .subsampling_w = @intCast(d.vi.format.subSamplingW),
            .subsampling_h = @intCast(d.vi.format.subSamplingH),
        });

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

    //TODO: inline casts once we're using Zig 0.16.0+
    const l_strf: f32 = @floatFromInt(l_str);
    const l_sensef: f32 = @floatFromInt(l_sense);
    const u_strf: f32 = @floatFromInt(u_str);
    const u_sensef: f32 = @floatFromInt(u_sense);
    const v_strf: f32 = @floatFromInt(v_str);
    const v_sensef: f32 = @floatFromInt(v_sense);

    var l: u9 = 0;
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

    var u: u9 = 0;
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

    var v: u9 = 0;
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
