const std = @import("std");
const vapoursynth = @import("vapoursynth");
const testing = @import("std").testing;
const testingAllocator = @import("std").testing.allocator;

const cmn = @import("common.zig");

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

const FluxSmoothData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,
    vi: *const vs.VideoInfo,

    // The temporal radius from which we'll build a median.
    // threshold: [3]u32,
    threshold: u32,

    // Which planes we will process.
    process: [3]bool,
};

fn FluxSmooth(comptime T: type) type {
    return struct {
        /// Signed Arithmetic Type - used in signed arithmetic to safely hold
        /// the values (particularly integers) without overflowing when doing
        /// signed arithmetic.
        const SAT = switch (T) {
            u8 => i16,
            u16 => i32,
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
            f16 => f16, //TODO: This might be more performant as f32 on some systems.
            f32 => f32,
            else => unreachable,
        };

        fn process_plane_scalar(srcp: [3][*]const T, dstp: [*]T, width: usize, height: usize, threshold: u32) void {

            // Used for rounding of integer formats.
            // TODO: Support higher bit depths, can do this in comptime.
            const magic_numbers = [_]UAT{ 0, 32767, 16384, 10923 };
            // Calculated thusly:
            // magic_numbers[1] = 32767;
            // for (int i = 2; i < 4; i++) {
            //     magic_numbers[i] = (int16_t)(32768.0 / i + 0.5);
            // }

            for (0..height) |row| {
                for (0..width) |column| {
                    const current_pixel = row * width + column;

                    const prev = srcp[0][current_pixel];
                    const curr = srcp[1][current_pixel];
                    const next = srcp[2][current_pixel];

                    // If both pixels from the corresponding previous and next frames
                    // are *brighter* or both are *darker*, then filter.
                    if ((prev < curr and next < curr) or (prev > curr and next > curr)) {
                        const prevdiff = @max(prev, curr) - @min(prev, curr);
                        const nextdiff = @max(next, curr) - @min(next, curr);

                        // Turns out picking the types on
                        // these can have a major impact on performance.
                        // Using u8, u16, u32, etc has better performance
                        // than u10, u2, etc.
                        // *and* picking the smallest possible byte-sized type
                        // leads to the best performance.
                        var sum: UAT = curr;
                        var count: u8 = 1;

                        if (prevdiff <= threshold) {
                            sum += prev;
                            count += 1;
                        }

                        if (nextdiff <= threshold) {
                            sum += next;
                            count += 1;
                        }

                        if (cmn.isFloat(T)) {
                            // Good ol' fashion division for floating point.
                            dstp[current_pixel] = sum / count;
                        } else {
                            // This code is taken verbatim from the Vaopursynth FluxSmooth plugin.
                            //
                            // The sum is multiplied by 2 so that the division is always by an even number,
                            // thus rounding can always be done by adding half the divisor
                            dstp[current_pixel] = @intCast(((sum * 2 + count) * @as(u32, magic_numbers[count]) >> 16));
                            //dstp[x] = (uint8_t)(sum / (float)count + 0.5f);

                            // Performance note:
                            // Turns out doing the @as(u32, magic_numbers[count]) cast leads to a significant gain in performance.
                            // Additionally, doing the right shift operation myself instead of calling std.math.shr leads
                            // to another leap in performance.
                        }
                    } else {
                        dstp[current_pixel] = curr;
                    }
                }
            }
        }

        pub fn getFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
            // Assign frame_data to nothing to stop compiler complaints
            _ = frame_data;

            const d: *FluxSmoothData = @ptrCast(@alignCast(instance_data));

            if (activation_reason == ar.Initial) {
                if (n == 0 or n == d.vi.numFrames - 1) {
                    vsapi.?.requestFrameFilter.?(n, d.node, frame_ctx);
                } else {
                    vsapi.?.requestFrameFilter.?(n - 1, d.node, frame_ctx);
                    vsapi.?.requestFrameFilter.?(n, d.node, frame_ctx);
                    vsapi.?.requestFrameFilter.?(n + 1, d.node, frame_ctx);
                }
            } else if (activation_reason == ar.AllFramesReady) {
                // Skip filtering on the first and last frames,
                // since we do not have enough information to filter them properly.
                if (n == 0 or n == d.vi.numFrames - 1) {
                    return vsapi.?.getFrameFilter.?(n, d.node, frame_ctx);
                }

                // const src_frames: [3]?*const vs.Frame = {
                // const src_frames = [3]?*const vs.Frame{
                const src_frames = [3]?*const vs.Frame{
                    vsapi.?.getFrameFilter.?(n - 1, d.node, frame_ctx),
                    vsapi.?.getFrameFilter.?(n, d.node, frame_ctx),
                    vsapi.?.getFrameFilter.?(n + 1, d.node, frame_ctx),
                };

                // Free all source frames within the filter radius when this function exits.
                defer {
                    for (0..3) |i| {
                        vsapi.?.freeFrame.?(src_frames[i]);
                    }
                }

                //TODO: Pull this code into a shared function somewhere, as several
                //plugins use it.
                // Prepare array of frame pointers, with null for planes we will process,
                // and pointers to the source frame for planes we won't process.
                var plane_src = [_]?*const vs.Frame{
                    if (d.process[0]) null else src_frames[1],
                    if (d.process[1]) null else src_frames[1],
                    if (d.process[2]) null else src_frames[1],
                };
                const planes = [_]c_int{ 0, 1, 2 };

                const dst = vsapi.?.newVideoFrame2.?(&d.vi.format, d.vi.width, d.vi.height, @ptrCast(&plane_src), @ptrCast(&planes), src_frames[1], core);

                var plane: c_int = 0;
                while (plane < d.vi.format.numPlanes) : (plane += 1) {
                    // Skip planes we aren't supposed to process
                    if (!d.process[@intCast(plane)]) {
                        continue;
                    }

                    const srcp = [3][*]const T{
                        @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[0], plane))),
                        @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[1], plane))),
                        @ptrCast(@alignCast(vsapi.?.getReadPtr.?(src_frames[2], plane))),
                    };

                    const dstp: [*]T = @ptrCast(@alignCast(vsapi.?.getWritePtr.?(dst, plane)));
                    const width: usize = @intCast(vsapi.?.getFrameWidth.?(dst, plane));
                    const height: usize = @intCast(vsapi.?.getFrameHeight.?(dst, plane));

                    process_plane_scalar(srcp, dstp, width, height, d.threshold);
                }

                return dst;
            }

            return null;
        }
    };
}

export fn fluxSmoothFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *FluxSmoothData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

pub export fn fluxSmoothCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    var d: FluxSmoothData = undefined;
    var err: vs.MapPropertyError = undefined;

    d.node = vsapi.?.mapGetNode.?(in, "clip", 0, &err).?;
    d.vi = vsapi.?.getVideoInfo.?(d.node);

    if (!vsh.isConstantVideoFormat(d.vi)) {
        vsapi.?.mapSetError.?(out, "FluxSmooth: only constant format  input supported");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    // TODO: Scale threshold based on bit depth.
    d.threshold = vsh.mapGetN(u32, in, "temporal_threshold", 0, vsapi) orelse 7;

    if (d.threshold < 0) {
        vsapi.?.mapSetError.?(out, "SmoothT: temporal_threshold must be 0 or greater.");
        vsapi.?.freeNode.?(d.node);
        return;
    }

    // TODO: Pull this into a reusable function somewhere, since it's used in a few different functions now.
    //
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
                vsapi.?.mapSetError.?(out, "FluxSmooth: plane index out of range.");
            }

            if (d.process[plane]) {
                vsapi.?.freeNode.?(d.node);
                // TODO: Add string formatting.
                vsapi.?.mapSetError.?(out, "FluxSmooth: plane specified twice.");
            }

            d.process[plane] = true;
        }
    }

    const data: *FluxSmoothData = allocator.create(FluxSmoothData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.General,
        },
    };

    const getFrame = switch (d.vi.format.bytesPerSample) {
        1 => &FluxSmooth(u8).getFrame,
        // 2 => if (d.vi.format.sampleType == vs.SampleType.Integer) &FluxSmooth(u16).getFrame else &FluxSmooth(f16).getFrame,
        // 4 => &FluxSmooth(f32).getFrame,
        else => unreachable,
    };

    vsapi.?.createVideoFilter.?(out, "FluxSmooth", d.vi, getFrame, fluxSmoothFree, fm.Parallel, &deps, deps.len, data, core);
}
