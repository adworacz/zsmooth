const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;

const copy = @import("common/copy.zig");
const types = @import("common/type.zig");
const vscmn = @import("common/vapoursynth.zig");
const sort = @import("common/sorting_networks.zig");

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

const VerticalCleanerData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,

    vi: *const vs.VideoInfo,

    // The modes for each plane we will process.
    modes: [3]u5,
};

/// Using a generic struct here as an optimization mechanism.
///
/// Essentially, when I first implemented things using just raw functions.
/// as soon as I supported 4 modes using a switch in the process_plane_scalar
/// function, performance dropped like a rock from 700+fps down to 40fps.
///
/// This meant that the Zig compiler couldn't optimize code properly.
///
/// With this implementation, I can generate perfect auto-vectorized code for each mode
/// at compile time (in which case the switch inside process_plane_scalar is optimized away).
///
/// It requires a "double switch" to in the GetFrame method in order to jump from runtime-land to compiletime-land
/// but it produces well optimized code at the expensive of a little visual repetition.
///
/// I techinically don't need the generic struct, and can get by with just a comptime mode param to process_plane_scalar,
/// but using a struct means I only need to specify a type param once instead of for each function, so it's slightly cleaner.
fn VerticalCleaner(comptime T: type) type {
    return struct {
        const SAT = types.SignedArithmeticType(T);
        const UAT = types.UnsignedArithmeticType(T);

        pub fn verticalMedian(noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
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

        pub fn relaxedVerticalMedian(noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize, minimum: T, maximum: T) void {
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

        fn getFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
            // Assign frame_data to nothing to stop compiler complaints
            _ = frame_data;

            const d: *VerticalCleanerData = @ptrCast(@alignCast(instance_data));

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
                    const maximum = vscmn.getFormatMaximum(T, d.vi.format, chroma);
                    const minimum = vscmn.getFormatMinimum(T, d.vi.format, chroma);

                    switch (d.modes[_plane]) {
                        1 => verticalMedian(srcp, dstp, width, height, stride),
                        2 => relaxedVerticalMedian(srcp, dstp, width, height, stride, minimum, maximum),
                        else => unreachable,
                    }
                }

                return dst;
            }

            return null;
        }
    };
}

export fn verticalCleanerFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *VerticalCleanerData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn verticalCleanerCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    var d: VerticalCleanerData = undefined;

    // TODO: Add error handling.
    var err: vs.MapPropertyError = undefined;

    d.node = vsapi.?.mapGetNode.?(in, "clip", 0, &err).?;
    d.vi = vsapi.?.getVideoInfo.?(d.node);

    const numModes = vsapi.?.mapNumElements.?(in, "mode");
    if (numModes > d.vi.format.numPlanes) {
        vsapi.?.mapSetError.?(out, "VerticalCleaner: Number of modes must be equal or fewer than the number of input planes.");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    for (0..3) |i| {
        if (i < numModes) {
            if (vsh.mapGetN(i32, in, "mode", @intCast(i), vsapi)) |mode| {
                if (mode < 0 or mode > 2) {
                    vsapi.?.mapSetError.?(out, "VerticalCleaner: Invalid mode specified, only modes 0-2 supported.");
                    vsapi.?.freeNode.?(d.node);
                    return;
                }
                d.modes[i] = @intCast(mode);
            }
        } else {
            d.modes[i] = d.modes[i - 1];
        }

        const height = d.vi.height >> @intCast(if (i > 0) d.vi.format.subSamplingH else 0);

        if (d.modes[i] == 1 and height < 3) {
            vsapi.?.mapSetError.?(out, "VerticalCleaner: corresponding plane's height must be greater than or equal to 3 for mode 1");
            vsapi.?.freeNode.?(d.node);
            return;
        } else if (d.modes[i] == 2 and height < 5) {
            vsapi.?.mapSetError.?(out, "VerticalCleaner: corresponding plane's height must be greater than or equal to 5 for mode 2");
            vsapi.?.freeNode.?(d.node);
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

    const getFrame = switch (d.vi.format.bytesPerSample) {
        1 => &VerticalCleaner(u8).getFrame,
        2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &VerticalCleaner(u16).getFrame else &VerticalCleaner(f16).getFrame,
        4 => &VerticalCleaner(f32).getFrame,
        else => unreachable,
    };

    vsapi.?.createVideoFilter.?(out, "VerticalCleaner", d.vi, getFrame, verticalCleanerFree, fm.Parallel, &deps, deps.len, data, core);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("VerticalCleaner", "clip:vnode;mode:int[]", "clip:vnode;", verticalCleanerCreate, null, plugin);
}
