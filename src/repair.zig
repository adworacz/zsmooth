const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;

const types = @import("common/type.zig");
const math = @import("common/math.zig");
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

const RepairData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    repair_node: ?*vs.Node,

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
fn Repair(comptime T: type) type {
    return struct {
        /// Signed Arithmetic Type - used in signed arithmetic to safely hold
        /// the values (particularly integers) without overflowing when doing
        /// signed arithmetic.
        const SAT = switch (T) {
            u8 => i16,
            u16 => i32,
            // RGSF uses double values for its computations,
            // while Avisynth uses single precision float for its computations.
            // I'm using single (and half) precision just like Avisynth since
            // double is unnecessary in most cases and twice as slow than single precision.
            // And I mean literally unnecessary - RGSF uses double on operations that are completely
            // safe for f32 calculations without any loss in precision, so it's *unnecessarily* slow.
            f16 => f16, //TODO: This might be more performant as f32 on some systems.
            f32 => f32,
            else => unreachable,
        };

        /// Unsigned Arithmetic Type - used in unsigned arithmetic to safely
        /// hold values (particularly integers) without overflowing when doing
        /// unsigned arithmetic.
        const UAT = switch (T) {
            u8 => u16,
            u16 => u32,
            // See note on floating point precision above.
            f16 => f16, //TODO: This might be more performant as f32 on some systems.
            f32 => f32,
            else => unreachable,
        };

        // Clamp the source pixel to the min/max of the repair pixels.
        fn repairMode1(src: T, c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            const min = @min(c, a1, a2, a3, a4, a5, a6, a7, a8);
            const max = @max(c, a1, a2, a3, a4, a5, a6, a7, a8);

            return math.clamp(src, min, max);
        }

        fn repairMode2(src: T, c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            var a = [_]T{ c, a1, a2, a3, a4, a5, a6, a7, a8 };

            sort.sort(T, a.len, &a);

            return math.clamp(src, a[1], a[7]);
        }

        fn repairMode3(src: T, c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            var a = [_]T{ c, a1, a2, a3, a4, a5, a6, a7, a8 };

            sort.sort(T, a.len, &a);

            return math.clamp(src, a[2], a[6]);
        }

        fn repairMode4(src: T, c: T, a1: T, a2: T, a3: T, a4: T, a5: T, a6: T, a7: T, a8: T) T {
            var a = [_]T{ c, a1, a2, a3, a4, a5, a6, a7, a8 };

            sort.sort(T, a.len, &a);

            return math.clamp(src, a[3], a[5]);
        }

        test "Repair Mode 1-4" {
            // In range
            try std.testing.expectEqual(5, repairMode1(5, 1, 2, 3, 4, 5, 6, 7, 8, 9));
            try std.testing.expectEqual(5, repairMode2(5, 1, 2, 3, 4, 5, 6, 7, 8, 9));
            try std.testing.expectEqual(5, repairMode3(5, 1, 2, 3, 4, 5, 6, 7, 8, 9));
            try std.testing.expectEqual(5, repairMode4(5, 1, 2, 3, 4, 5, 6, 7, 8, 9));

            // Out of range - high
            try std.testing.expectEqual(9, repairMode1(10, 1, 2, 3, 4, 5, 6, 7, 8, 9));
            try std.testing.expectEqual(8, repairMode2(10, 9, 8, 7, 6, 5, 4, 3, 2, 1));
            try std.testing.expectEqual(7, repairMode3(10, 9, 8, 7, 6, 5, 4, 3, 2, 1));
            try std.testing.expectEqual(6, repairMode4(10, 9, 8, 7, 6, 5, 4, 3, 2, 1));

            // Out of range - low
            try std.testing.expectEqual(1, repairMode1(0, 1, 2, 3, 4, 5, 6, 7, 8, 9));
            try std.testing.expectEqual(2, repairMode2(0, 9, 8, 7, 6, 5, 4, 3, 2, 1));
            try std.testing.expectEqual(3, repairMode3(0, 9, 8, 7, 6, 5, 4, 3, 2, 1));
            try std.testing.expectEqual(4, repairMode4(0, 9, 8, 7, 6, 5, 4, 3, 2, 1));
        }

        pub fn processPlaneScalar(mode: comptime_int, noalias srcp: []const T, noalias repairp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
            // Copy the first line.
            @memcpy(dstp[0..width], srcp[0..width]);

            for (1..height - 1) |row| {
                // Copy the pixel at the beginning of the line.
                dstp[(row * stride)] = srcp[(row * stride)];

                for (1..width - 1) |w| {
                    // Retrieve pixels from the 3x3 grid surrounding the current pixel
                    //
                    // a1 a2 a3
                    // a4  c a5
                    // a6 a7 a8

                    // Build c, cr,  and a1-a8 pixels.
                    //
                    // Note that *most* of the pixels used are from the *REPAIR* clip,
                    // and only the center pixel of the *SOURCE* clip is used.
                    const rowPrev = ((row - 1) * stride);
                    const rowCurr = ((row) * stride);
                    const rowNext = ((row + 1) * stride);

                    const a1 = repairp[rowPrev + w - 1];
                    const a2 = repairp[rowPrev + w];
                    const a3 = repairp[rowPrev + w + 1];

                    const a4 = repairp[rowCurr + w - 1];

                    const c = repairp[rowCurr + w];
                    const src = srcp[rowCurr + w];

                    const a5 = repairp[rowCurr + w + 1];

                    const a6 = repairp[rowNext + w - 1];
                    const a7 = repairp[rowNext + w];
                    const a8 = repairp[rowNext + w + 1];

                    dstp[rowCurr + w] = switch (mode) {
                        1 => repairMode1(src, c, a1, a2, a3, a4, a5, a6, a7, a8),
                        2 => repairMode2(src, c, a1, a2, a3, a4, a5, a6, a7, a8),
                        3 => repairMode3(src, c, a1, a2, a3, a4, a5, a6, a7, a8),
                        4 => repairMode4(src, c, a1, a2, a3, a4, a5, a6, a7, a8),
                        else => unreachable,
                    };
                }

                // Copy the pixel at the end of the line.
                dstp[(row * stride) + (width - 1)] = srcp[(row * stride) + (width - 1)];
            }

            // Copy the last line.
            const lastLine = ((height - 1) * stride);
            @memcpy(dstp[lastLine..], srcp[lastLine..(lastLine + width)]);
        }

        fn getFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
            // Assign frame_data to nothing to stop compiler complaints
            _ = frame_data;

            const d: *RepairData = @ptrCast(@alignCast(instance_data));

            if (activation_reason == ar.Initial) {
                vsapi.?.requestFrameFilter.?(n, d.node, frame_ctx);
                vsapi.?.requestFrameFilter.?(n, d.repair_node, frame_ctx);
            } else if (activation_reason == ar.AllFramesReady) {
                const src_frame = vsapi.?.getFrameFilter.?(n, d.node, frame_ctx);
                const repair_frame = vsapi.?.getFrameFilter.?(n, d.repair_node, frame_ctx);

                defer vsapi.?.freeFrame.?(src_frame);
                defer vsapi.?.freeFrame.?(repair_frame);

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
                    const repairp: []const T = @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(repair_frame, plane))))[0..(height * stride)];
                    const dstp: []T = @as([*]T, @ptrCast(@alignCast(vsapi.?.getWritePtr.?(dst, plane))))[0..(height * stride)];
                    // const chroma = d.vi.format.colorFamily == vs.ColorFamily.YUV and plane > 0;

                    // See note in remove_grain about the use of "double switch" optimization.
                    switch (d.modes[_plane]) {
                        // inline 1...24 => |mode| processPlaneScalar(mode, srcp, repairp, dstp, width, height, stride, chroma),
                        inline 1...24 => |mode| processPlaneScalar(mode, srcp, repairp, dstp, width, height, stride),
                        else => unreachable,
                    }
                }

                return dst;
            }

            return null;
        }
    };
}

export fn repairFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *RepairData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    vsapi.?.freeNode.?(d.repair_node);
    allocator.destroy(d);
}

export fn repairCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    var d: RepairData = undefined;

    // TODO: Add error handling.
    var err: vs.MapPropertyError = undefined;

    d.node = vsapi.?.mapGetNode.?(in, "clip", 0, &err).?;
    d.repair_node = vsapi.?.mapGetNode.?(in, "repairclip", 0, &err).?;

    d.vi = vsapi.?.getVideoInfo.?(d.node);

    if (!vsh.isSameVideoInfo(d.vi, vsapi.?.getVideoInfo.?(d.repair_node))) {
        vsapi.?.mapSetError.?(out, "Repair: Input clips must have the same format.");
        vsapi.?.freeNode.?(d.node);
        vsapi.?.freeNode.?(d.repair_node);
        return;
    }

    const numModes = vsapi.?.mapNumElements.?(in, "mode");
    if (numModes > d.vi.format.numPlanes) {
        vsapi.?.mapSetError.?(out, "Repair: Number of modes must be equal or fewer than the number of input planes.");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    for (0..3) |i| {
        if (i < numModes) {
            if (vsh.mapGetN(i32, in, "mode", @intCast(i), vsapi)) |mode| {
                if (mode < 0 or mode > 24) {
                    vsapi.?.mapSetError.?(out, "Repair: Invalid mode specified, only modes 0-24 supported.");
                    vsapi.?.freeNode.?(d.node);
                    return;
                }
                d.modes[i] = @intCast(mode);
            }
        } else {
            d.modes[i] = d.modes[i - 1];
        }
    }

    const data: *RepairData = allocator.create(RepairData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
        vs.FilterDependency{
            .source = d.repair_node,
            .requestPattern = rp.StrictSpatial,
        },
    };

    const getFrame = switch (d.vi.format.bytesPerSample) {
        1 => &Repair(u8).getFrame,
        2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &Repair(u16).getFrame else &Repair(f16).getFrame,
        4 => &Repair(f32).getFrame,
        else => unreachable,
    };

    vsapi.?.createVideoFilter.?(out, "Repair", d.vi, getFrame, repairFree, fm.Parallel, &deps, deps.len, data, core);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("Repair", "clip:vnode;repairclip:vnode;mode:int[]", "clip:vnode;", repairCreate, null, plugin);
}
