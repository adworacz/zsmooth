const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;

const math = std.math;
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

fn lessThan(a: u8, b: u8) bool {
    return a < b;
}

fn getVecSize(comptime T: type) comptime_int {
    if (std.simd.suggestVectorLength(T)) |suggested| {
        return suggested;
    }

    // Default to using 256-bit registers (AVX2) if the suggested width is empty.
    return switch (@sizeOf(T)) {
        // u8
        1 => 32,
        // u16
        2 => 16,
        // f32
        4 => 8,
    };
}

fn process_plane_scalar(comptime T: type, srcp: [MAX_DIAMETER][*]const T, dstp: [*]T, width: usize, height: usize, diameter: i8) void {
    var temp: [MAX_DIAMETER]T = undefined;

    for (0..height) |row| {
        for (0..width) |column| {
            const current_pixel = row * width + column;

            for (0..@intCast(diameter)) |i| {
                temp[i] = srcp[i][current_pixel];
            }

            std.mem.sortUnstable(T, temp[0..@intCast(diameter)], {}, comptime std.sort.asc(T));
            dstp[current_pixel] = temp[@intCast(@divTrunc(diameter, 2))];
        }
    }
}

fn process_plane_vec(comptime T: type, srcp: [MAX_DIAMETER][*]const T, dstp: [*]T, width: usize, height: usize, radius: i8) void {
    const vec_size = getVecSize(T);
    const width_simd = width / vec_size * vec_size;

    for (0..height) |h| {
        var x: usize = 0;
        while (x < width_simd) : (x += vec_size) {
            const offset = h * width + x;
            median_vec(T, srcp, dstp, offset, radius);
        }

        // If the video width is not perfectly aligned with the vector width, do one
        // last operation at the end of the plane to cover what's leftover from the loop above.
        if (width_simd < width) {
            median_vec(T, srcp, dstp, width - vec_size, radius);
        }
    }
}

inline fn median_vec(comptime T: type, srcp: [MAX_DIAMETER][*]const T, _dstp: [*]T, offset: usize, radius: i8) void {
    _ = radius;
    var dstp: [*]T = @ptrCast(@alignCast(_dstp));
    const vec_size = getVecSize(T);

    // Load
    const a: @Vector(vec_size, T) = srcp[0][offset..][0..vec_size].*;
    const b: @Vector(vec_size, T) = srcp[1][offset..][0..vec_size].*;
    const c: @Vector(vec_size, T) = srcp[2][offset..][0..vec_size].*;

    // var src: [MAX_RADIUS]@Vector(vec_size, T) = undefined;
    //
    // for (0..@intCast(radius * 2 + 1)) |r| {
    //     src[r] = srcp[r][offset..][0..vec_size].*;
    // }

    // TODO: Support greater radii.
    // switch (radius) {
    //     1 => {},
    //     2 => {
    //         const d: @Vector(vec_size, T) = srcp[3][offset..][0..vec_size].*;
    //         const e: @Vector(vec_size, T) = srcp[4][offset..][0..vec_size].*;
    //
    //         const f = @max(@min(a, b), @min(c, d));
    //         const g = @min(@max(a, b), @max(c, d));
    //
    //         a = e;
    //         b = f;
    //         c = g;
    //     },

    // Find median
    const result = @max(@min(a, b), @min(c, @max(a, b)));
    // const result = @max(@min(src[0], src[1]), @min(src[2], @max(src[0], src[1])));

    // Store
    inline for (dstp[offset..][0..vec_size], 0..) |*d, i| {
        d.* = result[i];
    }
}

test "process_plane should find the median value" {
    //Emulate a 2 x 64 (width x height) video.
    const T = f32;
    const one = [_]T{1} ** 128;
    const two = [_]T{2} ** 128;
    const three = [_]T{3} ** 128;

    // Create a multidimensional array that holds all possible prev + cur + next frames for testing.
    const srcp = [_][*]const T{
        &one,
        &two,
        &three,
    } ** 7; // 3 * 7 = 21, which is the MAX_DIAMETER

    const dstp_scalar = try testingAllocator.alloc(T, 128);
    const dstp_vec = try testingAllocator.alloc(T, 128);
    defer testingAllocator.free(dstp_scalar);
    defer testingAllocator.free(dstp_vec);

    process_plane_scalar(T, srcp, dstp_scalar.ptr, 64, 2, 3);
    process_plane_vec(T, srcp, dstp_vec.ptr, 64, 2, 1); // vec version uses radius, not diameter.

    // The median of 1, 2, and 3 is 2.
    const expected = ([_]T{2} ** 128)[0..];

    try testing.expectEqualDeep(expected, dstp_scalar);
    try testing.expectEqualDeep(expected, dstp_vec);
}

export fn temporalMedianGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const d: *TemporalMedianData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        // Don't request frames outside the bounds of the input clip while respecting the radius.
        if (n < d.radius or n > d.vi.numFrames - 1 - d.radius) {
            vsapi.?.requestFrameFilter.?(n, d.node, frame_ctx);
        } else {
            // Request previous, current, and next frames, based on the filter radius.
            {
                var i = -d.radius;
                while (i <= d.radius) : (i += 1) {
                    vsapi.?.requestFrameFilter.?(n + i, d.node, frame_ctx);
                }
            }
        }
    } else if (activation_reason == ar.AllFramesReady) {
        // Skip filtering on the first and last frames that lie inside the filter radius,
        // since we do not have enough information to filter them properly.
        if (n < d.radius or n > d.vi.numFrames - 1 - d.radius) {
            return vsapi.?.getFrameFilter.?(n, d.node, frame_ctx);
        }

        const diameter = d.radius * 2 + 1;
        var src_frames: [MAX_DIAMETER]?*const vs.Frame = undefined;

        // Retrieve all source frames within the filter radius.
        {
            // Use block to scope 'var i'... which is annoying.
            // The fact that zig doesn't support negative numbers in their ranges is really annoying.
            // TODO: Open a ticket with zig.
            var i = -d.radius;
            while (i <= d.radius) : (i += 1) {
                src_frames[@intCast(d.radius + i)] = vsapi.?.getFrameFilter.?(n + i, d.node, frame_ctx);
            }
        }
        // Free all source frames within the filter radius when this function exits.
        defer {
            var i = -d.radius;
            while (i <= d.radius) : (i += 1) {
                vsapi.?.freeFrame.?(src_frames[@intCast(d.radius + i)]);
            }
        }

        // Prepare array of frame pointers, with null for planes we will process,
        // and pointers to the source frame for planes we won't process.
        var plane_src = [_]?*const vs.Frame{
            // TODO: Disable zig fmt for these lines.
            if (d.process[0]) null else src_frames[@intCast(d.radius)],
            if (d.process[1]) null else src_frames[@intCast(d.radius)],
            if (d.process[2]) null else src_frames[@intCast(d.radius)],
        };
        const planes = [_]c_int{ 0, 1, 2 };

        const dst = vsapi.?.newVideoFrame2.?(&d.vi.format, d.vi.width, d.vi.height, @ptrCast(&plane_src), @ptrCast(&planes), src_frames[@intCast(d.radius)], core);

        var plane: c_int = 0;
        while (plane < d.vi.format.numPlanes) : (plane += 1) {
            // Skip planes we aren't supposed to process
            if (!d.process[@intCast(plane)]) {
                continue;
            }

            const dstp: [*]u8 = vsapi.?.getWritePtr.?(dst, plane);
            const width: usize = @intCast(vsapi.?.getFrameWidth.?(dst, plane));
            const height: usize = @intCast(vsapi.?.getFrameHeight.?(dst, plane));

            //TODO: See if the srcp loading can be optimized a bit more... Maybe a reusable func.
            //TODO: Support an 'opt' param to switch between vector and scalar algoritms.
            switch (d.vi.format.bytesPerSample) {
                1 => {
                    // 8 bit content
                    var srcp: [MAX_DIAMETER][*]const u8 = undefined;
                    for (0..@intCast(diameter)) |i| {
                        srcp[i] = vsapi.?.getReadPtr.?(src_frames[i], plane);
                    }
                    if (d.radius <= 6) {
                        process_plane_vec(u8, srcp, dstp, width, height, d.radius);
                    } else {
                        process_plane_scalar(u8, srcp, dstp, width, height, diameter);
                    }
                },
                2 => {
                    // 9-16 bit content
                    var srcp: [MAX_DIAMETER][*]const u16 = undefined;
                    for (0..@intCast(diameter)) |i| {
                        srcp[i] = @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[i], plane)));
                    }
                    if (d.radius <= 6) {
                        process_plane_vec(u16, srcp, @ptrCast(@alignCast(dstp)), width, height, d.radius);
                    } else {
                        process_plane_scalar(u16, srcp, @ptrCast(@alignCast(dstp)), width, height, diameter);
                    }
                },
                4 => {
                    var srcp: [MAX_DIAMETER][*]const f32 = undefined;
                    for (0..@intCast(diameter)) |i| {
                        srcp[i] = @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[i], plane)));
                    }
                    if (d.radius <= 6) {
                        process_plane_vec(f32, srcp, @ptrCast(@alignCast(dstp)), width, height, d.radius);
                    } else {
                        process_plane_scalar(f32, srcp, @ptrCast(@alignCast(dstp)), width, height, diameter);
                    }
                },
                else => unreachable,
            }
        }

        return dst;
    }

    return null;
}

export fn temporalMedianFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *TemporalMedianData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn temporalMedianCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    var d: TemporalMedianData = undefined;
    var err: c_int = undefined;

    d.node = vsapi.?.mapGetNode.?(in, "clip", 0, &err).?;
    d.vi = vsapi.?.getVideoInfo.?(d.node);

    if (!vsh.isConstantVideoFormat(d.vi)) {
        vsapi.?.mapSetError.?(out, "TemporalMedian: only constant format  input supported");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    // https://ziglang.org/documentation/master/#Optionals
    const radius = vsh.mapGetN(i64, in, "radius", 0, vsapi) orelse 1;

    if ((radius < 1) or (radius > 10)) {
        vsapi.?.mapSetError.?(out, "TemporalMedian: Radius must be between 1 and 10 (inclusive)");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    d.radius = @intCast(radius);

    //mapNumElements returns -1 if the element doesn't exist (aka, the user doesn't specify the option.)
    const requestedPlanesSize = vsapi.?.mapNumElements.?(in, "planes");
    const requestedPlanesIsEmpty = requestedPlanesSize <= 0;
    const numPlanes = d.vi.format.numPlanes;
    d.process = [_]bool{ requestedPlanesIsEmpty, requestedPlanesIsEmpty, requestedPlanesIsEmpty };

    if (!requestedPlanesIsEmpty) {
        for (0..@intCast(requestedPlanesSize)) |i| {
            const plane: u8 = vsh.mapGetN(u8, in, "planes", @intCast(i), vsapi) orelse unreachable;

            if (plane < 0 or plane > numPlanes) {
                vsapi.?.freeNode.?(d.node);
                // TODO: Add string formatting.
                vsapi.?.mapSetError.?(out, "TemporalMedian: plane index out of range.");
            }

            if (d.process[plane]) {
                vsapi.?.freeNode.?(d.node);
                // TODO: Add string formatting.
                vsapi.?.mapSetError.?(out, "TemporalMedian: plane specified twice.");
            }

            d.process[plane] = true;
        }
    }

    const data: *TemporalMedianData = allocator.create(TemporalMedianData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.General,
        },
    };

    vsapi.?.createVideoFilter.?(out, "TemporalMedian", d.vi, temporalMedianGetFrame, temporalMedianFree, fm.Parallel, &deps, deps.len, data, core);
}

export fn VapourSynthPluginInit2(plugin: *vs.Plugin, vspapi: *const vs.PLUGINAPI) void {
    _ = vspapi.configPlugin.?("com.adub.zmooth", "zmooth", "Smoothing functions in Zig", vs.makeVersion(1, 0), vs.VAPOURSYNTH_API_VERSION, 0, plugin);
    _ = vspapi.registerFunction.?("TemporalMedian", "clip:vnode;radius:int:opt;planes:int[]:opt;", "clip:vnode;", temporalMedianCreate, null, plugin);
}
