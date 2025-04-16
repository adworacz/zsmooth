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

const ClenseData = struct {
    // The clip on which we are operating.
    cnode: ?*vs.Node,
    pnode: ?*vs.Node,
    nnode: ?*vs.Node,

    vi: *const vs.VideoInfo,

    // The modes for each plane we will process.
    process: [3]bool,
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
fn Clense(comptime T: type) type {
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

        fn clense(noalias dstp: []T, noalias srcp: []const T, noalias prev: []const T, noalias next: []const T, width: usize, height: usize, stride: usize) void {
            for (0..height) |row| {
                for (0..width) |column| {
                    const p = prev[(row * stride) + column];
                    const c = srcp[(row * stride) + column];
                    const n = next[(row * stride) + column];

                    dstp[(row * stride) + column] = sort.median3(p, c, n);
                }
            }
        }

        test clense {
            const width = 3;
            const height = 5;
            const stride = 3;
            const prev = [_]T{
                3, 3, 3, //
                3, 3, 3, //
                3, 3, 3, //
                3, 3, 3, //
                3, 3, 3, //
            };
            const srcp = [_]T{
                1, 1, 1, //
                1, 1, 1, //
                1, 1, 1, //
                1, 1, 1, //
                1, 1, 1, //
            };
            const next = [_]T{
                5, 5, 5, //
                5, 5, 5, //
                5, 5, 5, //
                5, 5, 5, //
                5, 5, 5, //
            };

            const dstp = try testingAllocator.alloc(T, height * stride);
            defer testingAllocator.free(dstp);

            clense(dstp, &srcp, &prev, &next, width, height, stride);

            const expected = [_]T{
                3, 3, 3, //
                3, 3, 3, //
                3, 3, 3, //
                3, 3, 3, //
                3, 3, 3, //
            };
            try std.testing.expectEqualDeep(&expected, dstp);
        }

        fn getFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
            // Assign frame_data to nothing to stop compiler complaints
            _ = frame_data;

            const d: *ClenseData = @ptrCast(@alignCast(instance_data));

            if (activation_reason == ar.Initial) {
                if (n >= 1 and n <= d.vi.numFrames - 2) {
                    vsapi.?.requestFrameFilter.?(n - 1, d.pnode, frame_ctx);
                    vsapi.?.requestFrameFilter.?(n, d.cnode, frame_ctx);
                    vsapi.?.requestFrameFilter.?(n + 1, d.nnode, frame_ctx);
                } else {
                    vsapi.?.requestFrameFilter.?(n, d.cnode, frame_ctx);
                }
            } else if (activation_reason == ar.AllFramesReady) {
                // skip processing on first/last frames
                if (n < 1 or n > d.vi.numFrames - 2) {
                    return vsapi.?.getFrameFilter.?(n, d.cnode, frame_ctx);
                }

                const prev_frame = vsapi.?.getFrameFilter.?(n - 1, d.pnode, frame_ctx);
                const src_frame = vsapi.?.getFrameFilter.?(n, d.cnode, frame_ctx);
                const next_frame = vsapi.?.getFrameFilter.?(n + 1, d.nnode, frame_ctx);

                defer vsapi.?.freeFrame.?(prev_frame);
                defer vsapi.?.freeFrame.?(src_frame);
                defer vsapi.?.freeFrame.?(next_frame);

                const dst = vscmn.newVideoFrame(&d.process, src_frame, d.vi, core, vsapi);

                for (0..@intCast(d.vi.format.numPlanes)) |_plane| {
                    const plane: c_int = @intCast(_plane);
                    // Skip planes we aren't supposed to process
                    if (!d.process[_plane]) {
                        continue;
                    }

                    const width: usize = @intCast(vsapi.?.getFrameWidth.?(dst, plane));
                    const height: usize = @intCast(vsapi.?.getFrameHeight.?(dst, plane));
                    const stride: usize = @as(usize, @intCast(vsapi.?.getStride.?(dst, plane))) / @sizeOf(T);
                    const prev: []const T = @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(prev_frame, plane))))[0..(height * stride)];
                    const srcp: []const T = @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frame, plane))))[0..(height * stride)];
                    const next: []const T = @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(next_frame, plane))))[0..(height * stride)];
                    const dstp: []T = @as([*]T, @ptrCast(@alignCast(vsapi.?.getWritePtr.?(dst, plane))))[0..(height * stride)];

                    clense(dstp, srcp, prev, next, width, height, stride);

                    // switch (d.modes[_plane]) {
                    //     1 => verticalMedian(srcp, dstp, width, height, stride),
                    //     2 => relaxedVerticalMedian(srcp, dstp, width, height, stride, minimum, maximum),
                    //     else => unreachable,
                    // }
                }

                return dst;
            }

            return null;
        }
    };
}

export fn clenseFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *ClenseData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.cnode);
    vsapi.?.freeNode.?(d.pnode);
    vsapi.?.freeNode.?(d.nnode);
    allocator.destroy(d);
}

export fn clenseCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    var d: ClenseData = undefined;

    // TODO: Add error handling.
    var err: vs.MapPropertyError = undefined;

    d.cnode = vsapi.?.mapGetNode.?(in, "clip", 0, &err).?;
    d.vi = vsapi.?.getVideoInfo.?(d.cnode);

    if (!vsh.isConstantVideoFormat(d.vi)) {
        vsapi.?.mapSetError.?(out, "Clense: only constant format input supported");
        vsapi.?.freeNode.?(d.cnode);
        return;
    }

    // Reference previous/next clips, falling back to the main clip
    // if either are absent.
    d.pnode = vsapi.?.mapGetNode.?(in, "previous", 0, &err);
    if (err == vs.MapPropertyError.Unset) {
        d.pnode = vsapi.?.addNodeRef.?(d.cnode);
    }
    d.nnode = vsapi.?.mapGetNode.?(in, "next", 0, &err);
    if (err == vs.MapPropertyError.Unset) {
        d.nnode = vsapi.?.addNodeRef.?(d.cnode);
    }

    if (d.pnode != null and !vsh.isSameVideoInfo(d.vi, vsapi.?.getVideoInfo.?(d.pnode))) {
        vsapi.?.mapSetError.?(out, "Clense: previous clip does not have the same format as the main clip.");
        vsapi.?.freeNode.?(d.cnode);
        vsapi.?.freeNode.?(d.pnode);
        vsapi.?.freeNode.?(d.nnode);
    }

    if (d.nnode != null and !vsh.isSameVideoInfo(d.vi, vsapi.?.getVideoInfo.?(d.nnode))) {
        vsapi.?.mapSetError.?(out, "Clense: next clip does not have the same format as the main clip.");
        vsapi.?.freeNode.?(d.cnode);
        vsapi.?.freeNode.?(d.pnode);
        vsapi.?.freeNode.?(d.nnode);
    }

    d.process = vscmn.normalizePlanes(d.vi.format, in, vsapi) catch |e| {
        vsapi.?.freeNode.?(d.cnode);
        vsapi.?.freeNode.?(d.pnode);
        vsapi.?.freeNode.?(d.nnode);

        switch (e) {
            vscmn.PlanesError.IndexOutOfRange => vsapi.?.mapSetError.?(out, "Clense: Plane index out of range."),
            vscmn.PlanesError.SpecifiedTwice => vsapi.?.mapSetError.?(out, "Clense: Plane specified twice."),
        }
        return;
    };

    const data: *ClenseData = allocator.create(ClenseData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.pnode,
            .requestPattern = rp.NoFrameReuse,
        },
        vs.FilterDependency{
            .source = d.cnode,
            .requestPattern = rp.StrictSpatial,
        },
        vs.FilterDependency{
            .source = d.pnode,
            .requestPattern = rp.NoFrameReuse,
        },
    };

    const getFrame = switch (d.vi.format.bytesPerSample) {
        1 => &Clense(u8).getFrame,
        2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &Clense(u16).getFrame else &Clense(f16).getFrame,
        4 => &Clense(f32).getFrame,
        else => unreachable,
    };

    vsapi.?.createVideoFilter.?(out, "Clense", d.vi, getFrame, clenseFree, fm.Parallel, &deps, deps.len, data, core);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("Clense", "clip:vnode;previous:vnode:opt;next:vnode:opt;planes:int[]:opt", "clip:vnode;", clenseCreate, null, plugin);
}
