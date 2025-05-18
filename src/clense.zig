const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;

const copy = @import("common/copy.zig");
const types = @import("common/type.zig");
const vscmn = @import("common/vapoursynth.zig");
const sort = @import("common/sorting_networks.zig");
const math = @import("common/math.zig");

const vs = vapoursynth.vapoursynth4;
const vsh = vapoursynth.vshelper;

const ar = vs.ActivationReason;
const rp = vs.RequestPattern;
const fm = vs.FilterMode;
const st = vs.SampleType;

const allocator = std.heap.c_allocator;

const ClenseMode = enum {
    Normal,
    Forward,
    Backward,
};

const ClenseData = struct {
    // The clip on which we are operating.
    cnode: ?*vs.Node,
    pnode: ?*vs.Node,
    nnode: ?*vs.Node,

    vi: *const vs.VideoInfo,

    // The modes for each plane we will process.
    process: [3]bool,

    // mode: ClenseMode,
};

fn Clense(comptime T: type, comptime mode: ClenseMode) type {
    return struct {
        const SAT = types.SignedArithmeticType(T);
        const UAT = types.UnsignedArithmeticType(T);

        /// Find the median of the previous, current, and next frames.
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

        /// Clamps the source pixel using the difference between the furthest frame and the weighted minimum or maximum pixel of the closest and furthest frames.
        fn clenseForwardBackward(noalias dstp: []T, noalias srcp: []const T, noalias ref1p: []const T, noalias ref2p: []const T, width: usize, height: usize, stride: usize) void {
            for (0..height) |row| {
                for (0..width) |column| {
                    const ref1 = ref1p[(row * stride) + column];
                    const ref2 = ref2p[(row * stride) + column];
                    const src = srcp[(row * stride) + column];

                    // Find the brightest and darket pixels
                    const minref = @min(ref1, ref2);
                    const maxref = @max(ref1, ref2);

                    // Use saturating arithmetic to prevent needing to use a higher
                    // integer bit depth.
                    const lowref = if (types.isInt(T))
                        minref -| (ref2 -| minref)
                    else
                        minref * 2 - ref2;

                    const highref = if (types.isInt(T))
                        (maxref -| ref2) +| maxref
                    else
                        maxref * 2 - ref2;

                    dstp[(row * stride) + column] = std.math.clamp(src, lowref, highref);
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

        test clenseForwardBackward {
            const width = 3;
            const height = 5;
            const stride = 3;
            const ref1 = [_]T{
                7, 7, 7, //
                7, 7, 7, //
                7, 7, 7, //
                7, 7, 7, //
                7, 7, 7, //
            };
            const srcp = [_]T{
                1, 1, 1, //
                1, 1, 1, //
                1, 1, 1, //
                1, 1, 1, //
                1, 1, 1, //
            };
            const ref2 = [_]T{
                5, 5, 5, //
                5, 5, 5, //
                5, 5, 5, //
                5, 5, 5, //
                5, 5, 5, //
            };

            const dstp = try testingAllocator.alloc(T, height * stride);
            defer testingAllocator.free(dstp);

            clenseForwardBackward(dstp, &srcp, &ref1, &ref2, width, height, stride);

            const expected = [_]T{
                5, 5, 5, //
                5, 5, 5, //
                5, 5, 5, //
                5, 5, 5, //
                5, 5, 5, //
            };
            try std.testing.expectEqualDeep(&expected, dstp);
        }

        fn getFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
            const d: *ClenseData = @ptrCast(@alignCast(instance_data));

            if (activation_reason == ar.Initial) {
                switch (mode) {
                    .Normal => {
                        if (n >= 1 and n <= d.vi.numFrames - 2) {
                            frame_data.?.* = @ptrCast(@as(*void, @ptrFromInt(1)));
                            vsapi.?.requestFrameFilter.?(n - 1, d.pnode, frame_ctx);
                            vsapi.?.requestFrameFilter.?(n, d.cnode, frame_ctx);
                            vsapi.?.requestFrameFilter.?(n + 1, d.nnode, frame_ctx);
                        } else {
                            vsapi.?.requestFrameFilter.?(n, d.cnode, frame_ctx);
                        }
                    },
                    .Forward => {
                        vsapi.?.requestFrameFilter.?(n, d.cnode, frame_ctx);
                        if (n <= d.vi.numFrames - 3) {
                            frame_data.?.* = @ptrCast(@as(*void, @ptrFromInt(1)));
                            vsapi.?.requestFrameFilter.?(n + 1, d.cnode, frame_ctx);
                            vsapi.?.requestFrameFilter.?(n + 2, d.cnode, frame_ctx);
                        }
                    },
                    .Backward => {
                        if (n >= 2) {
                            frame_data.?.* = @ptrCast(@as(*void, @ptrFromInt(1)));
                            vsapi.?.requestFrameFilter.?(n - 2, d.cnode, frame_ctx);
                            vsapi.?.requestFrameFilter.?(n - 1, d.cnode, frame_ctx);
                        }
                        vsapi.?.requestFrameFilter.?(n, d.cnode, frame_ctx);
                    },
                }
            } else if (activation_reason == ar.AllFramesReady) {
                // Skip processing on first/last frames.
                // Uses `framedata` to communicate state between getFrame calls, as the first call is for ar.Initial to request necessary frames, and the second call is for ar.AllFramesReady once said requested frames are available.
                // Nifty trick, taken from RGVS/SF + Vapoursynth's SelectEvery function.
                if (@intFromPtr(frame_data.?.*) != 1) {
                    return vsapi.?.getFrameFilter.?(n, d.cnode, frame_ctx);
                }

                const ref1 = switch (mode) {
                    .Normal => vsapi.?.getFrameFilter.?(n - 1, d.pnode, frame_ctx),
                    .Forward => vsapi.?.getFrameFilter.?(n + 1, d.cnode, frame_ctx),
                    .Backward => vsapi.?.getFrameFilter.?(n - 1, d.cnode, frame_ctx),
                };
                const src_frame = vsapi.?.getFrameFilter.?(n, d.cnode, frame_ctx);
                const ref2 = switch (mode) {
                    .Normal => vsapi.?.getFrameFilter.?(n + 1, d.nnode, frame_ctx),
                    .Forward => vsapi.?.getFrameFilter.?(n + 2, d.cnode, frame_ctx),
                    .Backward => vsapi.?.getFrameFilter.?(n - 2, d.cnode, frame_ctx),
                };

                defer {
                    vsapi.?.freeFrame.?(ref1);
                    vsapi.?.freeFrame.?(src_frame);
                    vsapi.?.freeFrame.?(ref2);
                }

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
                    const ref1p: []const T = @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(ref1, plane))))[0..(height * stride)];
                    const srcp: []const T = @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frame, plane))))[0..(height * stride)];
                    const ref2p: []const T = @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(ref2, plane))))[0..(height * stride)];
                    const dstp: []T = @as([*]T, @ptrCast(@alignCast(vsapi.?.getWritePtr.?(dst, plane))))[0..(height * stride)];

                    switch (mode) {
                        .Normal => clense(dstp, srcp, ref1p, ref2p, width, height, stride),
                        .Forward => clenseForwardBackward(dstp, srcp, ref1p, ref2p, width, height, stride),
                        .Backward => clenseForwardBackward(dstp, srcp, ref1p, ref2p, width, height, stride),
                    }
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
    var d: ClenseData = undefined;
    var err: vs.MapPropertyError = undefined;

    d.cnode = vsapi.?.mapGetNode.?(in, "clip", 0, &err).?;
    d.pnode = null;
    d.nnode = null;

    d.vi = vsapi.?.getVideoInfo.?(d.cnode);
    const mode = @as(*ClenseMode, @ptrCast(user_data)).*;

    if (!vsh.isConstantVideoFormat(d.vi)) {
        vsapi.?.mapSetError.?(out, "Clense: only constant format input supported");
        vsapi.?.freeNode.?(d.cnode);
        return;
    }

    if (mode == .Normal) {
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

    const normalDeps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.pnode,
            .requestPattern = rp.NoFrameReuse, // Only a single frame (N - 1) is ever requested from this clip when processing frame N
        },
        vs.FilterDependency{
            .source = d.cnode,
            .requestPattern = rp.StrictSpatial,
        },
        vs.FilterDependency{
            .source = d.nnode,
            .requestPattern = rp.NoFrameReuse, // Only a single frame (N + 1) is ever requested from this clip when processing frame N
        },
    };

    const forwardBackwardDeps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.cnode,
            .requestPattern = rp.StrictSpatial,
        },
    };

    const getFrame = switch (mode) {
        .Normal => switch (d.vi.format.bytesPerSample) {
            1 => &Clense(u8, .Normal).getFrame,
            2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &Clense(u16, .Normal).getFrame else &Clense(f16, .Normal).getFrame,
            4 => &Clense(f32, .Normal).getFrame,
            else => unreachable,
        },
        .Forward => switch (d.vi.format.bytesPerSample) {
            1 => &Clense(u8, .Forward).getFrame,
            2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &Clense(u16, .Forward).getFrame else &Clense(f16, .Forward).getFrame,
            4 => &Clense(f32, .Forward).getFrame,
            else => unreachable,
        },
        .Backward => switch (d.vi.format.bytesPerSample) {
            1 => &Clense(u8, .Backward).getFrame,
            2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &Clense(u16, .Backward).getFrame else &Clense(f16, .Backward).getFrame,
            4 => &Clense(f32, .Backward).getFrame,
            else => unreachable,
        },
    };

    // vsapi.?.createVideoFilter.?(out, "Clense", d.vi, getFrame, clenseFree, fm.Parallel, if (d.mode == .Normal) &normalDeps else &forwardBackwardDeps, if (d.mode == .Normal) normalDeps.len else forwardBackwardDeps.len, data, core);
    vsapi.?.createVideoFilter.?(out, "Clense", d.vi, getFrame, clenseFree, fm.Parallel, if (mode == .Normal) &normalDeps else &forwardBackwardDeps, if (mode == .Normal) normalDeps.len else forwardBackwardDeps.len, data, core);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("Clense", "clip:vnode;previous:vnode:opt;next:vnode:opt;planes:int[]:opt", "clip:vnode;", clenseCreate, @constCast(@ptrCast(&ClenseMode.Normal)), plugin);
    _ = vsapi.registerFunction.?("ForwardClense", "clip:vnode;planes:int[]:opt", "clip:vnode;", clenseCreate, @constCast(@ptrCast(&ClenseMode.Forward)), plugin);
    _ = vsapi.registerFunction.?("BackwardClense", "clip:vnode;planes:int[]:opt", "clip:vnode;", clenseCreate, @constCast(@ptrCast(&ClenseMode.Backward)), plugin);
}
