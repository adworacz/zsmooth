const std = @import("std");
const vapoursynth = @import("vapoursynth");
const ZAPI = vapoursynth.ZAPI;
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;

const copy = @import("common/copy.zig");
const types = @import("common/type.zig");
const vscmn = @import("common/vapoursynth.zig");
const sort = @import("common/sorting_networks.zig");
const math = @import("common/math.zig");
const float_mode: std.builtin.FloatMode = if (@import("config").optimize_float) .optimized else .strict;

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

    mode: ClenseMode,
};

fn Clense(comptime T: type) type {
    return struct {
        const SAT = types.SignedArithmeticType(T);
        const UAT = types.UnsignedArithmeticType(T);

        /// Find the median of the previous, current, and next frames.
        fn clense(noalias dstp: []T, noalias srcp: []const T, noalias prev: []const T, noalias next: []const T, width: usize, height: usize, stride: usize) void {
            @setFloatMode(float_mode);

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
            @setFloatMode(float_mode);

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


        fn processPlane(mode: ClenseMode, noalias dstp8: []u8, noalias srcp8: []const u8, noalias ref1p8: []const u8, noalias ref2p8: []const u8, width: usize, height: usize, stride8: usize) void {
            const stride = stride8 / @sizeOf(T);
            const srcp: []const T = @ptrCast(@alignCast(srcp8));
            const ref1p: []const T = @ptrCast(@alignCast(ref1p8));
            const ref2p: []const T = @ptrCast(@alignCast(ref2p8));
            const dstp: []T = @ptrCast(@alignCast(dstp8));

            switch (mode) {
                .Normal => clense(dstp, srcp, ref1p, ref2p, width, height, stride),
                .Forward => clenseForwardBackward(dstp, srcp, ref1p, ref2p, width, height, stride),
                .Backward => clenseForwardBackward(dstp, srcp, ref1p, ref2p, width, height, stride),
            }
        }
    };
}

fn clenseGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
    const zapi = ZAPI.init(vsapi, core);
    const d: *ClenseData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        switch (d.mode) {
            .Normal => {
                if (n >= 1 and n <= d.vi.numFrames - 2) {
                    frame_data.?.* = @ptrCast(@as(*void, @ptrFromInt(1)));
                    zapi.requestFrameFilter(n - 1, d.pnode, frame_ctx);
                    zapi.requestFrameFilter(n, d.cnode, frame_ctx);
                    zapi.requestFrameFilter(n + 1, d.nnode, frame_ctx);
                } else {
                    zapi.requestFrameFilter(n, d.cnode, frame_ctx);
                }
            },
            .Forward => {
                zapi.requestFrameFilter(n, d.cnode, frame_ctx);
                if (n <= d.vi.numFrames - 3) {
                    frame_data.?.* = @ptrCast(@as(*void, @ptrFromInt(1)));
                    zapi.requestFrameFilter(n + 1, d.cnode, frame_ctx);
                    zapi.requestFrameFilter(n + 2, d.cnode, frame_ctx);
                }
            },
            .Backward => {
                if (n >= 2) {
                    frame_data.?.* = @ptrCast(@as(*void, @ptrFromInt(1)));
                    zapi.requestFrameFilter(n - 2, d.cnode, frame_ctx);
                    zapi.requestFrameFilter(n - 1, d.cnode, frame_ctx);
                }
                zapi.requestFrameFilter(n, d.cnode, frame_ctx);
            },
        }
    } else if (activation_reason == ar.AllFramesReady) {
        // Skip processing on first/last frames.
        // Uses `framedata` to communicate state between getFrame calls, as the first call is for ar.Initial to request necessary frames, and the second call is for ar.AllFramesReady once said requested frames are available.
        // Nifty trick, taken from RGVS/SF + Vapoursynth's SelectEvery function.
        if (@intFromPtr(frame_data.?.*) != 1) {
            return zapi.getFrameFilter(n, d.cnode, frame_ctx);
        }

        const ref1 = switch (d.mode) {
            .Normal => zapi.initZFrame(d.pnode, n - 1, frame_ctx),
            .Forward => zapi.initZFrame(d.cnode, n + 1, frame_ctx),
            .Backward => zapi.initZFrame(d.cnode, n - 1, frame_ctx),
        };
        const src_frame = zapi.initZFrame(d.cnode, n, frame_ctx);
        const ref2 = switch (d.mode) {
            .Normal => zapi.initZFrame(d.nnode, n + 1, frame_ctx),
            .Forward => zapi.initZFrame(d.cnode, n + 2, frame_ctx),
            .Backward => zapi.initZFrame(d.cnode, n - 2, frame_ctx),
        };

        defer {
            ref1.deinit();
            src_frame.deinit();
            ref2.deinit();
        }

        const dst = src_frame.newVideoFrame2(d.process);

        const processPlane: @TypeOf(&Clense(u8).processPlane) = switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &Clense(u8).processPlane,
            .U16 => &Clense(u16).processPlane,
            .F16 => &Clense(f16).processPlane,
            .F32 => &Clense(f32).processPlane,
        };

        for (0..@intCast(d.vi.format.numPlanes)) |plane| {
            // Skip planes we aren't supposed to process
            if (!d.process[plane]) {
                continue;
            }

            const width: usize = dst.getWidth(plane);
            const height: usize = dst.getHeight(plane);
            const stride8: usize = dst.getStride(plane);
            const ref1p8: []const u8 = ref1.getReadSlice(plane);
            const srcp8: []const u8 = src_frame.getReadSlice(plane);
            const ref2p8: []const u8 = ref2.getReadSlice(plane);
            const dstp8: []u8 = dst.getWriteSlice(plane);

            processPlane(d.mode, dstp8, srcp8, ref1p8, ref2p8, width, height, stride8);
        }

        return dst.frame;
    }

    return null;
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
    const zapi = ZAPI.init(vsapi, core);
    const inz = zapi.initZMap(in);
    const outz = zapi.initZMap(out);

    var d: ClenseData = undefined;

    d.cnode, d.vi = inz.getNodeVi("clip").?;
    d.pnode = null;
    d.nnode = null;

    d.mode = @as(*ClenseMode, @ptrCast(user_data)).*;

    if (!vsh.isConstantVideoFormat(d.vi)) {
        outz.setError("Clense: only constant format input supported");
        zapi.freeNode(d.cnode);
        return;
    }

    if (d.mode == .Normal) {
        // Reference previous/next clips, falling back to the main clip
        // if either are absent.
        d.pnode = inz.getNode("previous") orelse zapi.addNodeRef(d.cnode);
        d.nnode = inz.getNode("next") orelse zapi.addNodeRef(d.cnode);

        if (d.pnode != null and !vsh.isSameVideoInfo(d.vi, zapi.getVideoInfo(d.pnode))) {
            outz.setError("Clense: previous clip does not have the same format as the main clip.");
            zapi.freeNode(d.cnode);
            zapi.freeNode(d.pnode);
            zapi.freeNode(d.nnode);
        }

        if (d.nnode != null and !vsh.isSameVideoInfo(d.vi, zapi.getVideoInfo(d.nnode))) {
            outz.setError("Clense: next clip does not have the same format as the main clip.");
            zapi.freeNode(d.cnode);
            zapi.freeNode(d.pnode);
            zapi.freeNode(d.nnode);
        }
    }

    d.process = vscmn.normalizePlanes(d.vi.format, in, vsapi) catch |e| {
        zapi.freeNode(d.cnode);
        zapi.freeNode(d.pnode);
        zapi.freeNode(d.nnode);

        switch (e) {
            vscmn.PlanesError.IndexOutOfRange => outz.setError("Clense: Plane index out of range."),
            vscmn.PlanesError.SpecifiedTwice => outz.setError("Clense: Plane specified twice."),
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

    zapi.createVideoFilter(out, "Clense", d.vi, clenseGetFrame, clenseFree, fm.Parallel, if (d.mode == .Normal) &normalDeps else &forwardBackwardDeps, data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("Clense", "clip:vnode;previous:vnode:opt;next:vnode:opt;planes:int[]:opt", "clip:vnode;", clenseCreate, @constCast(@ptrCast(&ClenseMode.Normal)), plugin);
    _ = vsapi.registerFunction.?("ForwardClense", "clip:vnode;planes:int[]:opt", "clip:vnode;", clenseCreate, @constCast(@ptrCast(&ClenseMode.Forward)), plugin);
    _ = vsapi.registerFunction.?("BackwardClense", "clip:vnode;planes:int[]:opt", "clip:vnode;", clenseCreate, @constCast(@ptrCast(&ClenseMode.Backward)), plugin);
}
