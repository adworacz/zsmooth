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

// Align LUTs to a reasonable cache size.
// Maybe change this for Mac targets, which have larger cache sizes...
const LUT_ALIGN = 64;
const MAX_RADIUS = 10;
const MAX_DIAMETER = MAX_RADIUS * 2 + 1;
const MAX_DIAMETER_PLANES = MAX_DIAMETER * 3;

const Cnr3Data = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,

    vi: *const vs.VideoInfo,

    radius: u8,

    table_y: []align(LUT_ALIGN) u8,
    table_u: []align(LUT_ALIGN) u8,
    table_v: []align(LUT_ALIGN) u8,
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

        fn processFrameScalar(radius: comptime_int, curr: [3][]const T, src: []const [3][]const T, noalias dst_u: []T, noalias dst_v: []T, scratch_y: []const []T, tables: [3][]align(LUT_ALIGN) const u8, opt: struct {
            width_y: usize,
            height_y: usize,
            width_uv: usize,
            height_uv: usize,

            stride_y: usize,
            stride_uv: usize,
            stride_scratch: usize,

            subsampling_h: u2,
            subsampling_w: u2,

            table_idx_shift: u4,
        }) void {
            const downsample_opts: DownSampleOpts = .{
                .dst_width = opt.width_y >> opt.subsampling_w,
                .dst_height = opt.height_y >> opt.subsampling_h,
                .dst_stride = opt.stride_scratch,
                .src_stride = opt.stride_y,
                .subsampling_w = opt.subsampling_w,
                .subsampling_h = opt.subsampling_h,
            };
            const curr_y: []T = scratch_y[0];
            const curr_u = curr[1];
            const curr_v = curr[2];
            downSampleLuma(curr[0], curr_y, downsample_opts);

            // Downsample all other luma planes
            for (src, scratch_y[1..]) |other, scratch| {
                downSampleLuma(other[0], scratch, downsample_opts);
            }

            const table_y = tables[0];
            const table_u = tables[1];
            const table_v = tables[2];

            var results_u: [MAX_DIAMETER]UAT = @splat(0);
            var results_v: [MAX_DIAMETER]UAT = @splat(0);
            var abs_diffs: [MAX_DIAMETER]UAT = @splat(0);

            // Constants for pixel combinations using shifts or divides.
            const shift = @typeInfo(UAT).int.bits;
            const weight_shift = if (T == u16) shift / 2 else 0;
            const max: BUAT = 1 << shift;
            const round = 1 << (shift - 1);
            const divisor = @as(BUAT, max) * (radius * 2);
            const round2 = divisor / 2;

            // Calculate past frames
            for (0..opt.height_uv) |y| {
                for (0..opt.width_uv) |x| {
                    const y_index = y * opt.stride_scratch + x;
                    const uv_index = y * opt.stride_uv + x;

                    for (0..radius * 2, src, scratch_y[1..]) |i, other, other_y| {
                        const other_u = other[1];
                        const other_v = other[2];

                        const abs_diff_y = math.absDiff(curr_y[y_index], other_y[y_index]);
                        const abs_diff_u = math.absDiff(curr_u[uv_index], other_u[uv_index]);
                        const abs_diff_v = math.absDiff(curr_v[uv_index], other_v[uv_index]);

                        const abs_diff = @as(UAT, abs_diff_y) + abs_diff_u + abs_diff_v;

                        const table_idx_y: usize = switch (T) {
                            u8 => abs_diff_y,
                            u16 => abs_diff_y >> opt.table_idx_shift,
                            else => @trunc(abs_diff_y * 255.0),
                        };
                        const table_idx_u: usize = switch (T) {
                            u8 => abs_diff_u,
                            u16 => abs_diff_u >> opt.table_idx_shift,
                            else => @trunc(abs_diff_u * 255.0),
                        };
                        const table_idx_v: usize = switch (T) {
                            u8 => abs_diff_v,
                            u16 => abs_diff_v >> opt.table_idx_shift,
                            else => @trunc(abs_diff_v * 255.0),
                        };

                        const weight_u: BUAT = (@as(UAT, table_y[table_idx_y]) * table_u[table_idx_u]) << weight_shift;
                        const weight_v: BUAT = (@as(UAT, table_y[table_idx_y]) * table_v[table_idx_v]) << weight_shift;

                        const result_u = ((weight_u * other_u[uv_index] + (max - weight_u) * curr_u[uv_index] + round) >> shift);
                        const result_v = ((weight_v * other_v[uv_index] + (max - weight_v) * curr_v[uv_index] + round) >> shift);

                        results_u[i] = @intCast(result_u);
                        results_v[i] = @intCast(result_v);
                        abs_diffs[i] = abs_diff;
                    }

                    // Inverse weight the results so that results derived
                    // from large difference frames have a lower weight, and vice versa.
                    var result_u: BUAT = 0;
                    var result_v: BUAT = 0;

                    for (0..radius * 2) |i| {
                        result_u += (max - abs_diffs[i]) * results_u[i];
                        result_v += (max - abs_diffs[i]) * results_v[i];
                    }

                    dst_u[uv_index] = @intCast((result_u + round2) / divisor);
                    dst_v[uv_index] = @intCast((result_v + round2) / divisor);
                }
            }
        }

        // Use separate dstp pointers so we can use `noalias`,
        // which leads to a *substantial speedup*: ~290fps -> 513 fps
        fn processFrame(curr8: [3][]const u8, src8: []const [3][]const u8, noalias dst8_u: []u8, noalias dst8_v: []u8, scratch_y8: []const []u8, tables: [3][]align(LUT_ALIGN) const u8, opt: struct {
            radius: u8,

            width_y: usize,
            height_y: usize,
            width_uv: usize,
            height_uv: usize,

            stride_y: usize,
            stride_uv: usize,
            stride_scratch: usize,

            subsampling_h: u2,
            subsampling_w: u2,

            table_idx_shift: u4,
        }) void {
            const curr: [3][]const T = .{
                @ptrCast(@alignCast(curr8[0])),
                @ptrCast(@alignCast(curr8[1])),
                @ptrCast(@alignCast(curr8[2])),
            };

            const src: []const [3][]const T = @ptrCast(@alignCast(src8));
            const scratch_y: []const []T = @ptrCast(@alignCast(scratch_y8));

            const dst_u: []T = @ptrCast(@alignCast(dst8_u));
            const dst_v: []T = @ptrCast(@alignCast(dst8_v));

            switch (opt.radius) {
                inline 1...MAX_RADIUS => |r| processFrameScalar(r, curr, src, dst_u, dst_v, scratch_y, tables, .{
                    .width_y = opt.width_y,
                    .height_y = opt.height_y,
                    .width_uv = opt.width_uv,
                    .height_uv = opt.height_uv,

                    .stride_y = opt.stride_uv / @sizeOf(T),
                    .stride_uv = opt.stride_uv / @sizeOf(T),
                    .stride_scratch = opt.stride_scratch / @sizeOf(T),

                    .subsampling_h = opt.subsampling_h,
                    .subsampling_w = opt.subsampling_w,

                    .table_idx_shift = opt.table_idx_shift,
                }),
                else => unreachable,
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
        var i: i8 = -@as(i8, @intCast(d.radius));
        while (i <= d.radius) : (i += 1) {
            zapi.requestFrameFilter(std.math.clamp(n + i, 0, d.vi.numFrames - 1), d.node);
        }
    } else if (activation_reason == ar.AllFramesReady) {
        // Don't process the first and last frames
        // if (n < 1 or n == d.vi.numFrames - 1) {
        //     return zapi.getFrameFilter(n, d.node);
        // }

        var src_frames: [MAX_DIAMETER]ZAPI.ZFrame(*const vs.Frame) = undefined;
        var frame_count: u8 = 0;

        {
            var i: i8 = -@as(i8, @intCast(d.radius));
            while (i <= d.radius) : (i += 1) {
                if (i != 0) {
                    //Grab all frames *except* the current frame, which we retrieve separately later.
                    src_frames[frame_count] = zapi.initZFrame(d.node, std.math.clamp(n + i, 0, d.vi.numFrames - 1));
                    frame_count += 1;
                }
            }
        }

        var src_planes: [MAX_DIAMETER][3][]const u8 = undefined;

        // Allocate scratch buffers for downsampled luma planes
        var scratch_frames: [MAX_DIAMETER]ZAPI.ZFrame(*vs.Frame) = undefined;
        var scratch_planes: [MAX_DIAMETER][]u8 = undefined;
        var grey_format: vs.VideoFormat = undefined;
        _ = zapi.queryVideoFormat(&grey_format, .Gray, d.vi.format.sampleType, d.vi.format.bitsPerSample, 0, 0);

        // Get read slices and setup scratch buffers.
        for (0..frame_count) |i| {
            src_planes[i][0] = src_frames[i].getReadSlice(0);
            src_planes[i][1] = src_frames[i].getReadSlice(1);
            src_planes[i][2] = src_frames[i].getReadSlice(2);
        }
        // frame_count + 1 to ensure we have a scratch buffer for the current frame
        for (0..frame_count + 1) |i| {
            scratch_frames[i] = ZAPI.ZFrame(*vs.Frame).init(&zapi, zapi.newVideoFrame(&grey_format, d.vi.width >> @intCast(d.vi.format.subSamplingW), d.vi.height >> @intCast(d.vi.format.subSamplingH), null).?);
            scratch_planes[i] = scratch_frames[i].getWriteSlice(0);
        }

        // Cleanup
        defer for (0..frame_count) |i| src_frames[i].deinit();
        defer for (0..frame_count + 1) |i| scratch_frames[i].deinit();

        //TODO: Handle scene changes
        //TODO: Return the current frame if the total frame count < 3 (radius 1)
        const start_idx = 0;
        const end_idx = frame_count;

        const curr = zapi.initZFrame(d.node, n);
        defer curr.deinit();

        // copy the luma plane only
        const dst = curr.newVideoFrame2(.{ false, true, true });

        const table_idx_shift: u4 = if (d.vi.format.sampleType == .Integer) @intCast(d.vi.format.bitsPerSample - 8) else 0;

        const processFrame = switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &Cnr3(u8).processFrame,
            .U16 => &Cnr3(u16).processFrame,
            else => unreachable,
            // .F16 => &Cnr3(f16).processPlane,
            // .F32 => &Cnr3(f32).processPlane,
        };

        processFrame(.{
            curr.getReadSlice(0),
            curr.getReadSlice(1),
            curr.getReadSlice(2),
        }, src_planes[start_idx..end_idx], dst.getWriteSlice(1), dst.getWriteSlice(2), scratch_planes[0 .. frame_count + 1], .{
            d.table_y,
            d.table_u,
            d.table_v,
        }, .{
            .radius = d.radius,

            .width_y = curr.getWidth(0),
            .width_uv = curr.getWidth(1),

            .height_y = curr.getHeight(0),
            .height_uv = curr.getHeight(1),

            .stride_y = dst.getStride(0),
            .stride_uv = dst.getStride(1),
            .stride_scratch = scratch_frames[0].getStride(0),

            .subsampling_w = @intCast(d.vi.format.subSamplingW),
            .subsampling_h = @intCast(d.vi.format.subSamplingH),

            .table_idx_shift = table_idx_shift,
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
        d.vi.format.bitsPerSample < 8 or d.vi.format.bitsPerSample > 16 or
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

    d.radius = if (inz.getInt(i32, "radius")) |radius| blk: {
        if (radius < 1 or radius > MAX_RADIUS) {
            outz.setError("Cnr3: radius must be between 1 and 10");
            zapi.freeNode(d.node);
            return;
        }

        break :blk @intCast(radius);
    } else 1;

    // Sensitivies
    const sense_l: u8 = if (inz.getInt(i32, "sense_l")) |sense_l| blk: {
        if (sense_l < 0 or sense_l > 255) {
            outz.setError("Cnr3: sense_l must be between 0 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk @intCast(sense_l);
    } else 35;

    const sense_u: u8 = if (inz.getInt(i32, "sense_u")) |sense_u| blk: {
        if (sense_u < 0 or sense_u > 255) {
            outz.setError("Cnr3: sense_u must be between 0 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk @intCast(sense_u);
    } else 47;

    const sense_v: u8 = if (inz.getInt(i32, "sense_v")) |sense_v| blk: {
        if (sense_v < 0 or sense_v > 255) {
            outz.setError("Cnr3: sense_v must be between 0 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk @intCast(sense_v);
    } else 47;

    // Strengths
    const str_l: u8 = if (inz.getInt(i32, "str_l")) |str_l| blk: {
        if (str_l < 0 or str_l > 255) {
            outz.setError("Cnr3: str_l must be between 0 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk @intCast(str_l);
    } else 192;

    const str_u: u8 = if (inz.getInt(i32, "str_u")) |str_u| blk: {
        if (str_u < 0 or str_u > 255) {
            outz.setError("Cnr3: str_u must be between 0 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk @intCast(str_u);
    } else 255;

    const str_v: u8 = if (inz.getInt(i32, "str_v")) |str_v| blk: {
        if (str_v < 0 or str_v > 255) {
            outz.setError("Cnr3: str_v must be between 0 and 255");
            zapi.freeNode(d.node);
            return;
        }
        break :blk @intCast(str_v);
    } else 255;

    // Using an aligned alloc for potential SIMD/autovec friendliness
    // Might not make any difference, but it doesn't hurt
    const table_size = 256;
    d.table_y = allocator.alignedAlloc(u8, std.mem.Alignment.fromByteUnits(LUT_ALIGN), table_size) catch {
        outz.setError("Cnr3: Unable to allocate memory for internal tables");
        zapi.freeNode(d.node);
        return;
    };
    d.table_u = allocator.alignedAlloc(u8, std.mem.Alignment.fromByteUnits(LUT_ALIGN), table_size) catch {
        outz.setError("Cnr3: Unable to allocate memory for internal tables");
        zapi.freeNode(d.node);
        return;
    };
    d.table_v = allocator.alignedAlloc(u8, std.mem.Alignment.fromByteUnits(LUT_ALIGN), table_size) catch {
        outz.setError("Cnr3: Unable to allocate memory for internal tables");
        zapi.freeNode(d.node);
        return;
    };

    // Zero out all weights
    @memset(d.table_y, 0);
    @memset(d.table_u, 0);
    @memset(d.table_v, 0);

    // Create separate scopes to reduce chance of bugs from variable reuse (which happened)
    {
        //TODO: inline casts once we're using Zig 0.16.0+
        const str_lf: f32 = @floatFromInt(str_l);
        const sense_lf: f32 = @floatFromInt(sense_l);
        var l: u9 = 0;
        while (l <= str_l) : (l += 1) {
            const lf: f32 = @floatFromInt(l);
            d.table_y[l] = switch (mode[0]) {
                'o' => @intFromFloat(str_lf / 2 * (1 + @cos(lf * lf * std.math.pi / (sense_lf * sense_lf)))),
                'x' => @intFromFloat(str_lf / 2 * (1 + @cos(lf * std.math.pi / sense_lf))),
                else => {
                    outz.setError("Cnr3: Only 'o' and 'x' are recognized characters in mode");
                    zapi.freeNode(d.node);
                    return;
                },
            };
        }
    }

    {
        const str_uf: f32 = @floatFromInt(str_u);
        const sense_uf: f32 = @floatFromInt(sense_u);
        var u: u9 = 0;
        while (u <= str_u) : (u += 1) {
            const uf: f32 = @floatFromInt(u);
            d.table_u[u] = switch (mode[1]) {
                'o' => @intFromFloat(str_uf / 2 * (1 + @cos(uf * uf * std.math.pi / (sense_uf * sense_uf)))),
                'x' => @intFromFloat(str_uf / 2 * (1 + @cos(uf * std.math.pi / sense_uf))),
                else => {
                    outz.setError("Cnr3: Only 'o' and 'x' are recognized characters in mode");
                    zapi.freeNode(d.node);
                    return;
                },
            };
        }
    }

    {
        const str_vf: f32 = @floatFromInt(str_v);
        const sense_vf: f32 = @floatFromInt(sense_v);
        var v: u9 = 0;
        while (v <= str_v) : (v += 1) {
            const vf: f32 = @floatFromInt(v);
            d.table_v[v] = switch (mode[2]) {
                'o' => @intFromFloat(str_vf / 2 * (1 + @cos(vf * vf * std.math.pi / (sense_vf * sense_vf)))),
                'x' => @intFromFloat(str_vf / 2 * (1 + @cos(vf * std.math.pi / sense_vf))),
                else => {
                    outz.setError("Cnr3: Only 'o' and 'x' are recognized characters in mode");
                    zapi.freeNode(d.node);
                    return;
                },
            };
        }
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
        "radius:int:opt;" ++
        "sense_l:int:opt;" ++
        "str_l:int:opt;" ++
        "sense_u:int:opt;" ++
        "str_u:int:opt;" ++
        "sense_v:int:opt;" ++
        "str_u:int:opt;", "clip:vnode;", cnr3Create, null, plugin);
}
