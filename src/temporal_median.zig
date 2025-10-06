const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;

const math = @import("common/math.zig");
const vscmn = @import("common/vapoursynth.zig");
const vec = @import("common/vector.zig");
const sort = @import("common/sorting_networks.zig");
const float_mode: std.builtin.FloatMode = if (@import("config").optimize_float) .optimized else .strict;

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

const MAX_RADIUS = 10;
const MAX_DIAMETER = MAX_RADIUS * 2 + 1;

const TemporalMedianData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    vi: *const vs.VideoInfo,

    // The temporal radius from which we'll build a median.
    radius: i8,

    // Which planes we will process.
    process: [3]bool,
};

fn TemporalMedian(comptime T: type) type {
    const vec_size = vec.getVecSize(T);
    const VecType = @Vector(vec_size, T);

    return struct {
        fn processPlaneScalar(comptime diameter: u8, srcp: []const []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
            @setFloatMode(float_mode);

            var temp: [diameter]T = undefined;

            for (0..height) |row| {
                for (0..width) |column| {
                    const current_pixel = row * stride + column;

                    for (0..@intCast(diameter)) |i| {
                        temp[i] = srcp[i][current_pixel];
                    }

                    // 60fps with radius 1
                    // 7 fps with radius 10
                    // TODO: Try this code again with new sorting networks in common/sort.zig.
                    std.mem.sortUnstable(T, temp[0..diameter], {}, comptime std.sort.asc(T));

                    dstp[current_pixel] = temp[diameter / 2];
                }
            }
        }

        fn processPlaneVector(comptime diameter: u8, srcp: []const []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
            const width_simd = width / vec_size * vec_size;

            for (0..height) |row| {
                var column: usize = 0;
                while (column < width_simd) : (column += vec_size) {
                    const offset = row * stride + column;
                    medianVector(diameter, srcp, dstp, offset);
                }

                // If the video width is not perfectly aligned with the vector width, do one
                // last operation at the end of the plane to cover what's leftover from the loop above.
                if (width_simd < width) {
                    medianVector(diameter, srcp, dstp, (row * stride) + width - vec_size);
                }
            }
        }

        test "processPlane should find the median value" {
            const height = 2;
            const width = vec_size + 24;
            const stride = width + 8 + vec_size;
            const size = height * stride;

            const radius = 4;
            const diameter = radius * 2 + 1;
            const expectedMedian = ([_]T{radius + 1} ** size)[0..];

            var src: [diameter][]const T = undefined;
            for (0..diameter) |i| {
                const frame = try testingAllocator.alloc(T, size);
                @memset(frame, math.lossyCast(T, i + 1));

                src[i] = frame;
            }
            defer {
                for (0..diameter) |i| {
                    testingAllocator.free(src[i]);
                }
            }

            const dstp_scalar = try testingAllocator.alloc(T, size);
            const dstp_vec = try testingAllocator.alloc(T, size);
            defer testingAllocator.free(dstp_scalar);
            defer testingAllocator.free(dstp_vec);

            processPlaneScalar(diameter, &src, dstp_scalar, width, height, stride);
            processPlaneVector(diameter, &src, dstp_vec, width, height, stride);

            for (0..height) |row| {
                const start = row * stride;
                const end = start + width;
                try testing.expectEqualDeep(expectedMedian[start..end], dstp_scalar[start..end]);
                try testing.expectEqualDeep(expectedMedian[start..end], dstp_vec[start..end]);
            }
        }

        fn medianVector(comptime diameter: u8, srcp: []const []const T, noalias dstp: []T, offset: usize) void {
            @setFloatMode(float_mode);

            var src: [diameter]VecType = undefined;

            for (0..diameter) |r| {
                src[r] = vec.load(VecType, srcp[r], offset);
            }

            const result: VecType = switch (diameter) {
                3 => sort.median(VecType, 3, src[0..3]),
                5 => sort.median(VecType, 5, src[0..5]),
                7 => sort.median(VecType, 7, src[0..7]),
                9 => sort.median(VecType, 9, src[0..9]),
                11 => sort.median(VecType, 11, src[0..11]),
                13 => sort.median(VecType, 13, src[0..13]),
                15 => sort.median(VecType, 15, src[0..15]),
                17 => sort.median(VecType, 17, src[0..17]),
                19 => sort.median(VecType, 19, src[0..19]),
                21 => sort.median(VecType, 21, src[0..21]),
                else => unreachable,
            };

            // Store
            vec.store(VecType, dstp, offset, result);
        }

        pub fn getFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) ?*const vs.Frame {
            // Assign frame_data to nothing to stop compiler complaints
            _ = frame_data;

            const d: *TemporalMedianData = @ptrCast(@alignCast(instance_data));

            if (activation_reason == ar.Initial) {
                if (n < d.radius or n > d.vi.numFrames - 1 - d.radius) {
                    vsapi.?.requestFrameFilter.?(n, d.node, frame_ctx);
                } else {
                    // Request previous, current, and next frames, based on the filter radius.
                    var i = -d.radius;
                    while (i <= d.radius) : (i += 1) {
                        vsapi.?.requestFrameFilter.?(n + i, d.node, frame_ctx);
                    }
                }
            } else if (activation_reason == ar.AllFramesReady) {
                // Skip filtering on the first and last frames that lie inside the filter radius,
                // since we do not have enough information to filter them properly.
                if (n < d.radius or n > d.vi.numFrames - 1 - d.radius) {
                    return vsapi.?.getFrameFilter.?(n, d.node, frame_ctx);
                }

                const diameter: u8 = @intCast(d.radius * 2 + 1);
                var src_frames: [MAX_DIAMETER]?*const vs.Frame = undefined;

                // Retrieve all source frames within the filter radius.
                {
                    var i = -d.radius;
                    while (i <= d.radius) : (i += 1) {
                        src_frames[@intCast(d.radius + i)] = vsapi.?.getFrameFilter.?(n + i, d.node, frame_ctx);
                    }
                }
                defer for (0..diameter) |i| vsapi.?.freeFrame.?(src_frames[i]);

                const dst = vscmn.newVideoFrame(&d.process, src_frames[@intCast(d.radius)], d.vi, core, vsapi);

                var plane: c_int = 0;
                while (plane < d.vi.format.numPlanes) : (plane += 1) {
                    // Skip planes we aren't supposed to process
                    if (!d.process[@intCast(plane)]) {
                        continue;
                    }

                    const width: usize = @intCast(vsapi.?.getFrameWidth.?(dst, plane));
                    const height: usize = @intCast(vsapi.?.getFrameHeight.?(dst, plane));
                    const stride: usize = @as(usize, @intCast(vsapi.?.getStride.?(dst, plane))) / @sizeOf(T);

                    var srcp: [MAX_DIAMETER][]const T = undefined;
                    for (0..diameter) |i| {
                        srcp[i] = @as([*]const T, @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[i], plane))))[0..(height * stride)];
                    }
                    const dstp: []T = @as([*]T, @ptrCast(@alignCast(vsapi.?.getWritePtr.?(dst, plane))))[0..(height * stride)];

                    switch (d.radius) {
                        inline 1...MAX_RADIUS => |r| processPlaneVector((r * 2 + 1), srcp[0..(r * 2 + 1)], dstp, width, height, stride),
                        else => unreachable,
                    }
                }

                return dst;
            }

            return null;
        }
    };
}

export fn temporalMedianFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = core;
    const d: *TemporalMedianData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn temporalMedianCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.c) void {
    _ = user_data;
    var d: TemporalMedianData = undefined;
    var err: vs.MapPropertyError = undefined;

    d.node = vsapi.?.mapGetNode.?(in, "clip", 0, &err).?;
    d.vi = vsapi.?.getVideoInfo.?(d.node);

    if (!vsh.isConstantVideoFormat(d.vi)) {
        vsapi.?.mapSetError.?(out, "TemporalMedian: only constant format input supported");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    d.radius = vscmn.mapGetN(i8, in, "radius", 0, vsapi) orelse 1;

    if ((d.radius < 1) or (d.radius > MAX_RADIUS)) {
        vsapi.?.mapSetError.?(out, "TemporalMedian: Radius must be between 1 and 10 (inclusive)");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    d.process = vscmn.normalizePlanes(d.vi.format, in, vsapi) catch |e| {
        vsapi.?.freeNode.?(d.node);

        switch (e) {
            vscmn.PlanesError.IndexOutOfRange => vsapi.?.mapSetError.?(out, "TemporalMedian: Plane index out of range."),
            vscmn.PlanesError.SpecifiedTwice => vsapi.?.mapSetError.?(out, "TemporalMedian: Plane specified twice."),
        }
        return;
    };

    const data: *TemporalMedianData = allocator.create(TemporalMedianData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.General,
        },
    };

    const getFrame = switch (d.vi.format.bytesPerSample) {
        1 => &TemporalMedian(u8).getFrame,
        2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &TemporalMedian(u16).getFrame else &TemporalMedian(f16).getFrame,
        4 => &TemporalMedian(f32).getFrame,
        else => unreachable,
    };

    vsapi.?.createVideoFilter.?(out, "TemporalMedian", d.vi, getFrame, temporalMedianFree, fm.Parallel, &deps, deps.len, data, core);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("TemporalMedian", "clip:vnode;radius:int:opt;planes:int[]:opt;", "clip:vnode;", temporalMedianCreate, null, plugin);
}
