const std = @import("std");
const vapoursynth = @import("vapoursynth");
const ZAPI = vapoursynth.ZAPI;
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;

const copy = @import("common/copy.zig");
const types = @import("common/type.zig");
const vscmn = @import("common/vapoursynth.zig");
const sort = @import("common/sorting_networks.zig");
const float_mode: std.builtin.FloatMode = if (@import("config").optimize_float) .optimized else .strict;

const vs = vapoursynth.vapoursynth4;

const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;
const st = vs.SampleType;

// https://ziglang.org/documentation/master/#Choosing-an-Allocator
//
// Using the C allocator since we're passing pointers to allocated memory between Zig and C code,
// specifically the filter data between the Create and GetFrame functions.
const allocator = std.heap.c_allocator;

const VerticalCleanerData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,

    vi: *const vs.VideoInfo,

    // The modes for each plane we will process.
    modes: [3]u2,
};

fn VerticalCleaner(comptime T: type) type {
    return struct {
        const SAT = types.SignedArithmeticType(T);
        const UAT = types.UnsignedArithmeticType(T);

        fn verticalMedian(noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
            @setFloatMode(float_mode);

            // Copy the first line
            copy.copyFirstNLines(T, dstp, srcp, width, stride, 1);

            for (1..height - 1) |row| {
                for (0..width) |column| {
                    const top = srcp[(row - 1) * stride + column];
                    const center = srcp[row * stride + column];
                    const bottom = srcp[(row + 1) * stride + column];

                    dstp[row * stride + column] = sort.median3(top, center, bottom);
                }
            }

            // Copy the last line
            copy.copyLastNLines(T, dstp, srcp, width, height, stride, 1);
        }

        test verticalMedian {
            const width = 3;
            const height = 5;
            const stride = 3;
            const srcp = [_]T{
                0, 0, 0, //
                3, 3, 3, //
                1, 1, 1, //
                5, 5, 5, //
                0, 0, 0, //
            };

            const dstp = try testingAllocator.alloc(T, height * stride);
            defer testingAllocator.free(dstp);

            verticalMedian(&srcp, dstp, width, height, stride);

            const expected = [_]T{
                0, 0, 0, //
                1, 1, 1, //
                3, 3, 3, //
                1, 1, 1, //
                0, 0, 0, //
            };
            try std.testing.expectEqualDeep(&expected, dstp);
        }

        fn relaxedVerticalMedian(noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize, minimum: T, maximum: T) void {
            @setFloatMode(float_mode);

            // Copy the first two lines
            copy.copyFirstNLines(T, dstp, srcp, width, stride, 2);

            for (2..height - 2) |row| {
                for (0..width) |column| {
                    const p2 = srcp[(row - 2) * stride + column];
                    const p1 = srcp[(row - 1) * stride + column];
                    const c = srcp[row * stride + column];
                    const n1 = srcp[(row + 1) * stride + column];
                    const n2 = srcp[(row + 2) * stride + column];

                    const upper = if (types.isInt(T))
                        // Use saturating arithmetic on integers to prevent overflow
                        @max(@max(@min(std.math.clamp(std.math.clamp(p1 -| p2, minimum, maximum) +| p1, minimum, maximum), std.math.clamp(std.math.clamp(n1 -| n2, minimum, maximum) +| n1, minimum, maximum)), p1), n1)
                    else
                        @max(@max(@min(std.math.clamp(std.math.clamp(p1 - p2, minimum, maximum) + p1, minimum, maximum), std.math.clamp(std.math.clamp(n1 - n2, minimum, maximum) + n1, minimum, maximum)), p1), n1);

                    const lower = if (types.isInt(T))
                        // Use saturating arithmetic on integers to prevent overflow
                        @min(@min(p1, n1), @max(std.math.clamp(p1 -| std.math.clamp(p2 -| p1, minimum, maximum), minimum, maximum), std.math.clamp(n1 -| std.math.clamp(n2 -| n1, minimum, maximum), minimum, maximum)))
                    else
                        @min(@min(p1, n1), @max(std.math.clamp(p1 - std.math.clamp(p2 - p1, minimum, maximum), minimum, maximum), std.math.clamp(n1 - std.math.clamp(n2 - n1, minimum, maximum), minimum, maximum)));

                    dstp[row * stride + column] = std.math.clamp(c, lower, upper);
                }
            }

            // Copy the last two lines
            copy.copyLastNLines(T, dstp, srcp, width, height, stride, 2);
        }

        test relaxedVerticalMedian {
            const width = 3;
            const height = 5;
            const stride = 3;
            const srcp = [_]T{
                0, 0, 0, //
                3, 3, 3, //
                1, 1, 1, //
                5, 5, 5, //
                0, 0, 0, //
            };

            const dstp = try testingAllocator.alloc(T, height * stride);
            defer testingAllocator.free(dstp);

            relaxedVerticalMedian(&srcp, dstp, width, height, stride, 0, 255);

            const expected = [_]T{
                0, 0, 0, //
                3, 3, 3, //
                3, 3, 3, //
                5, 5, 5, //
                0, 0, 0, //
            };
            try std.testing.expectEqualDeep(&expected, dstp);
        }

        fn processPlane(mode: u2, chroma: bool, bits_per_sample: u6, noalias dstp8: []u8, noalias srcp8: []const u8, width: usize, height: usize, stride8: usize) void {
            const stride = stride8 / @sizeOf(T);
            const srcp: []const T = @ptrCast(@alignCast(srcp8));
            const dstp: []T = @ptrCast(@alignCast(dstp8));

            const maximum = vscmn.getFormatMaximum2(T, bits_per_sample, chroma);
            const minimum = vscmn.getFormatMinimum2(T, chroma);

            switch (mode) {
                1 => verticalMedian(srcp, dstp, width, height, stride),
                2 => relaxedVerticalMedian(srcp, dstp, width, height, stride, minimum, maximum),
                else => unreachable,
            }
        }
        
    };
}

fn verticalCleanerGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const zapi = ZAPI.init(vsapi, core, frame_ctx);

    const d: *VerticalCleanerData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        zapi.requestFrameFilter(n, d.node);
    } else if (activation_reason == ar.AllFramesReady) {
        const src_frame = zapi.initZFrame(d.node, n);

        defer src_frame.deinit();

        const process = [_]bool{
            d.modes[0] > 0,
            d.modes[1] > 0,
            d.modes[2] > 0,
        };

        const dst = src_frame.newVideoFrame2(process);

        const processPlane = switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &VerticalCleaner(u8).processPlane,
            .U16 => &VerticalCleaner(u16).processPlane,
            .F16 => &VerticalCleaner(f16).processPlane,
            .F32 => &VerticalCleaner(f32).processPlane,
        };

        for (0..@intCast(d.vi.format.numPlanes)) |plane| {
            // Skip planes we aren't supposed to process
            if (d.modes[plane] == 0) {
                continue;
            }

            const width: usize = dst.getWidth(plane);
            const height: usize = dst.getHeight(plane);
            const stride8: usize = dst.getStride(plane);
            const srcp8: []const u8 = src_frame.getReadSlice(plane);
            const dstp8: []u8 = dst.getWriteSlice(plane);
            const chroma = vscmn.isChromaPlane(d.vi.format.colorFamily, plane);
            const bits_per_sample: u6 = @intCast(d.vi.format.bitsPerSample);

            processPlane(d.modes[plane], chroma, bits_per_sample, dstp8, srcp8, width, height, stride8); 
        }

        return dst.frame;
    }

    return null;
}

export fn verticalCleanerFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = core;
    const d: *VerticalCleanerData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn verticalCleanerCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = user_data;
    var d: VerticalCleanerData = undefined;

    const zapi = ZAPI.init(vsapi, core, null);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);

    d.node, d.vi = inz.getNodeVi("clip").?;

    const numModes: c_int = @intCast(inz.numElements("mode") orelse 0);
    if (numModes > d.vi.format.numPlanes) {
        outz.setError("VerticalCleaner: Number of modes must be equal or fewer than the number of input planes.");
        zapi.freeNode(d.node);
        return;
    }

    for (0..3) |i| {
        if (i < numModes) {
            if (inz.getInt2(i32, "mode", i)) |mode| {
                if (mode < 0 or mode > 2) {
                    outz.setError("VerticalCleaner: Invalid mode specified, only modes 0-2 supported.");
                    zapi.freeNode(d.node);
                    return;
                }
                d.modes[i] = @intCast(mode);
            }
        } else {
            d.modes[i] = d.modes[i - 1];
        }

        const height = d.vi.height >> @intCast(if (i > 0) d.vi.format.subSamplingH else 0);

        if (d.modes[i] == 1 and height < 3) {
            outz.setError("VerticalCleaner: corresponding plane's height must be greater than or equal to 3 for mode 1");
            zapi.freeNode(d.node);
            return;
        } else if (d.modes[i] == 2 and height < 5) {
            outz.setError("VerticalCleaner: corresponding plane's height must be greater than or equal to 5 for mode 2");
            zapi.freeNode(d.node);
            return;
        }
    }

    const data: *VerticalCleanerData = allocator.create(VerticalCleanerData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
    };

    zapi.createVideoFilter(out, "VerticalCleaner", d.vi, verticalCleanerGetFrame, verticalCleanerFree, fm.Parallel, &deps, data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("VerticalCleaner", "clip:vnode;mode:int[]", "clip:vnode;", verticalCleanerCreate, null, plugin);
}
