const std = @import("std");
const vapoursynth = @import("vapoursynth");
const ZAPI = vapoursynth.ZAPI;
const testing = @import("std").testing;

const types = @import("common/type.zig");
const vscmn = @import("common/vapoursynth.zig");
const gridcmn = @import("common/array_grid.zig");
const vec = @import("common/vector.zig");
const sort = @import("common/sorting_networks.zig");
const math = @import("common/math.zig");
const lossyCast = math.lossyCast;
const printf = @import("common/string.zig").printf;

const string = @import("common/string.zig");
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

const CCDData = struct {
    // The clip on which we are operating.
    node: ?*vs.Node,

    vi: *const vs.VideoInfo,

    threshold: f32,
};

fn CCD(comptime T: type) type {
    const diameter = 25;
    const radius = diameter / 2;

    const vector_len = vec.getVecSize(T);
    const VT = @Vector(vector_len, T);
    const BSAT = types.BigSignedArithmeticType(T);
    // const SATV = @Vector(vector_len, SAT);
    const UAT = types.UnsignedArithmeticType(T);
    const BUAT = types.BigUnsignedArithmeticType(T);
    // const UATV = @Vector(vector_len, UAT);

    return struct {
        const Grid = gridcmn.ArrayGrid(diameter, T);
        const GridV = gridcmn.ArrayGrid(diameter, VT);

        // fn ccdScalar(threshold: T, r_grid: anytype, g_grid: anytype, b_grid: anytype) struct { @typeInfo(@TypeOf(grid.values)).array.child, @typeInfo(@TypeOf(grid.values)).array.child, @typeInfo(@TypeOf(grid.values)).array.child } {
        fn ccdScalar(threshold: BUAT, format_min: T, format_max: T, grid_r: *Grid, grid_g: *Grid, grid_b: *Grid) struct { @typeInfo(@TypeOf(grid_r.values)).array.child, @typeInfo(@TypeOf(grid_g.values)).array.child, @typeInfo(@TypeOf(grid_b.values)).array.child } {
            @setFloatMode(float_mode);

            const F = if (types.isInt(T)) f32 else T;

            const center_r = grid_r.values[grid_r.values.len / 2];
            const center_g = grid_g.values[grid_g.values.len / 2];
            const center_b = grid_b.values[grid_b.values.len / 2];

            var total_r: UAT = center_r;
            var total_g: UAT = center_g;
            var total_b: UAT = center_b;

            var count: u8 = 0;

            // TODO: support different point selections (high/medium/low) like vs-jetpack.
            var row: usize = 0;
            while (row < diameter) : (row += 8) {
                var column: usize = 0;
                while (column < diameter) : (column += 8) {
                    const neighbor_r = grid_r.values[row * diameter + column];
                    const neighbor_g = grid_g.values[row * diameter + column];
                    const neighbor_b = grid_b.values[row * diameter + column];

                    const diff_r: BSAT = lossyCast(BSAT, neighbor_r) - center_r;
                    const diff_g: BSAT = lossyCast(BSAT, neighbor_g) - center_g;
                    const diff_b: BSAT = lossyCast(BSAT, neighbor_b) - center_b;

                    // sum of squared differences
                    const ssd: BUAT = lossyCast(BUAT, diff_r * diff_r) + lossyCast(BUAT, diff_g * diff_g) + lossyCast(BUAT, diff_b * diff_b);

                    if (ssd < threshold) {
                        total_r += neighbor_r;
                        total_g += neighbor_g;
                        total_b += neighbor_b;
                        count += 1;
                    }
                }
            }

            var calculated_r: F = lossyCast(F, total_r) * (1.0 / (lossyCast(F, count) + 1.0));
            var calculated_g: F = lossyCast(F, total_g) * (1.0 / (lossyCast(F, count) + 1.0));
            var calculated_b: F = lossyCast(F, total_b) * (1.0 / (lossyCast(F, count) + 1.0));

            if (types.isInt(T)) {
                // Round int formats before we cast back.
                calculated_r = @round(calculated_r);
                calculated_g = @round(calculated_g);
                calculated_b = @round(calculated_b);
            }

            return .{
                std.math.clamp(lossyCast(T, calculated_r), format_min, format_max),
                std.math.clamp(lossyCast(T, calculated_g), format_min, format_max),
                std.math.clamp(lossyCast(T, calculated_b), format_min, format_max),
            };
        }

        // Faster than ccdScalar, since we only load minimal amounts of data.
        fn ccdScalar2(comptime mirror: bool, threshold: BUAT, format_min: T, format_max: T, row: usize, column: usize, width: usize, height: usize, stride: usize, src: [3][]const T) struct { T, T, T } {
            @setFloatMode(float_mode);

            const F = if (types.isInt(T)) f32 else T;

            const center_r = src[0][row * stride + column];
            const center_g = src[1][row * stride + column];
            const center_b = src[2][row * stride + column];

            var total_r: UAT = center_r;
            var total_g: UAT = center_g;
            var total_b: UAT = center_b;

            var count: u8 = 0;

            // TODO: support different point selections (high/medium/low) like vs-jetpack.
            var y: isize = @as(isize, @intCast(row)) - radius;
            while (y <= row + radius) : (y += 8) {
                var x: isize = @as(isize, @intCast(column)) - radius;
                while (x <= column + radius) : (x += 8) {
                    const absolute_y: usize = if (mirror) math.mirrorIndex(y, height) else @intCast(y);
                    const absolute_x: usize = if (mirror) math.mirrorIndex(x, width) else @intCast(x);

                    const neighbor_r = src[0][absolute_y * stride + absolute_x];
                    const neighbor_g = src[1][absolute_y * stride + absolute_x];
                    const neighbor_b = src[2][absolute_y * stride + absolute_x];

                    const diff_r: BSAT = lossyCast(BSAT, neighbor_r) - center_r;
                    const diff_g: BSAT = lossyCast(BSAT, neighbor_g) - center_g;
                    const diff_b: BSAT = lossyCast(BSAT, neighbor_b) - center_b;

                    // sum of squared differences
                    const ssd: BUAT = lossyCast(BUAT, diff_r * diff_r) + lossyCast(BUAT, diff_g * diff_g) + lossyCast(BUAT, diff_b * diff_b);

                    if (ssd < threshold) {
                        total_r += neighbor_r;
                        total_g += neighbor_g;
                        total_b += neighbor_b;
                        count += 1;
                    }
                }
            }

            var calculated_r: F = lossyCast(F, total_r) * (1.0 / (lossyCast(F, count) + 1.0));
            var calculated_g: F = lossyCast(F, total_g) * (1.0 / (lossyCast(F, count) + 1.0));
            var calculated_b: F = lossyCast(F, total_b) * (1.0 / (lossyCast(F, count) + 1.0));

            if (types.isInt(T)) {
                // Round int formats before we cast back.
                calculated_r = @round(calculated_r);
                calculated_g = @round(calculated_g);
                calculated_b = @round(calculated_b);
            }

            return .{
                std.math.clamp(lossyCast(T, calculated_r), format_min, format_max),
                std.math.clamp(lossyCast(T, calculated_g), format_min, format_max),
                std.math.clamp(lossyCast(T, calculated_b), format_min, format_max),
            };
        }

        fn processPlaneScalar(threshold: BUAT, format_min: T, format_max: T, srcp: [3][]const T, dstp: [3][]T, width: usize, height: usize, stride: usize) void {
            // Process top rows with mirrored grid.
            for (0..radius) |row| {
                for (0..width) |column| {
                    //TODO: s/r_grid/grid_r/g
                    var r_grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp[0], stride);
                    var g_grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp[1], stride);
                    var b_grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp[2], stride);

                    const result = ccdScalar(threshold, format_min, format_max, &r_grid, &g_grid, &b_grid);

                    dstp[0][(row * stride) + column] = result[0];
                    dstp[1][(row * stride) + column] = result[1];
                    dstp[2][(row * stride) + column] = result[2];
                }
            }

            for (radius..height - radius) |row| {
                // Process first pixels of the row with mirrored grid.
                for (0..radius) |column| {
                    var r_grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp[0], stride);
                    var g_grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp[1], stride);
                    var b_grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp[2], stride);

                    const result = ccdScalar(threshold, format_min, format_max, &r_grid, &g_grid, &b_grid);

                    dstp[0][(row * stride) + column] = result[0];
                    dstp[1][(row * stride) + column] = result[1];
                    dstp[2][(row * stride) + column] = result[2];
                }

                for (radius..width - radius) |column| {
                    // Use a non-mirrored grid everywhere else for maximum performance.
                    // We don't need the mirror effect anyways, as all pixels contain valid data.
                    var r_grid = Grid.initFromCenter(T, row, column, srcp[0], stride);
                    var g_grid = Grid.initFromCenter(T, row, column, srcp[1], stride);
                    var b_grid = Grid.initFromCenter(T, row, column, srcp[2], stride);

                    const result = ccdScalar(threshold, format_min, format_max, &r_grid, &g_grid, &b_grid);

                    dstp[0][(row * stride) + column] = result[0];
                    dstp[1][(row * stride) + column] = result[1];
                    dstp[2][(row * stride) + column] = result[2];
                }

                // Process last pixel of the row with mirrored grid.
                for (width - radius..width) |column| {
                    var r_grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp[0], stride);
                    var g_grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp[1], stride);
                    var b_grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp[2], stride);

                    const result = ccdScalar(threshold, format_min, format_max, &r_grid, &g_grid, &b_grid);

                    dstp[0][(row * stride) + column] = result[0];
                    dstp[1][(row * stride) + column] = result[1];
                    dstp[2][(row * stride) + column] = result[2];
                }
            }

            // Process bottom rows with mirrored grid.
            for (height - radius..height) |row| {
                for (0..width) |column| {
                    var r_grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp[0], stride);
                    var g_grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp[1], stride);
                    var b_grid = Grid.initFromCenterMirrored(T, row, column, width, height, srcp[2], stride);

                    const result = ccdScalar(threshold, format_min, format_max, &r_grid, &g_grid, &b_grid);

                    dstp[0][(row * stride) + column] = result[0];
                    dstp[1][(row * stride) + column] = result[1];
                    dstp[2][(row * stride) + column] = result[2];
                }
            }
        }

        fn processPlanesScalar2(threshold: BUAT, format_min: T, format_max: T, src: [3][]const T, dst: [3][]T, width: usize, height: usize, stride: usize) void {
            // Process top rows with mirrored grid.
            for (0..radius) |row| {
                for (0..width) |column| {
                    const result = ccdScalar2(true, threshold, format_min, format_max, row, column, width, height, stride, src);

                    dst[0][(row * stride) + column] = result[0];
                    dst[1][(row * stride) + column] = result[1];
                    dst[2][(row * stride) + column] = result[2];
                }
            }

            for (radius..height - radius) |row| {
                // Process first pixels of the row with mirrored grid.
                for (0..radius) |column| {
                    const result = ccdScalar2(true, threshold, format_min, format_max, row, column, width, height, stride, src);

                    dst[0][(row * stride) + column] = result[0];
                    dst[1][(row * stride) + column] = result[1];
                    dst[2][(row * stride) + column] = result[2];
                }

                for (radius..width - radius) |column| {
                    // Use a non-mirrored grid everywhere else for maximum performance.
                    // We don't need the mirror effect anyways, as all pixels contain valid data.
                    const result = ccdScalar2(false, threshold, format_min, format_max, row, column, width, height, stride, src);

                    dst[0][(row * stride) + column] = result[0];
                    dst[1][(row * stride) + column] = result[1];
                    dst[2][(row * stride) + column] = result[2];
                }

                // Process last pixel of the row with mirrored grid.
                for (width - radius..width) |column| {
                    const result = ccdScalar2(true, threshold, format_min, format_max, row, column, width, height, stride, src);

                    dst[0][(row * stride) + column] = result[0];
                    dst[1][(row * stride) + column] = result[1];
                    dst[2][(row * stride) + column] = result[2];
                }
            }

            // Process bottom rows with mirrored grid.
            for (height - radius..height) |row| {
                for (0..width) |column| {
                    const result = ccdScalar2(true, threshold, format_min, format_max, row, column, width, height, stride, src);

                    dst[0][(row * stride) + column] = result[0];
                    dst[1][(row * stride) + column] = result[1];
                    dst[2][(row * stride) + column] = result[2];
                }
            }
        }

        // fn processPlaneVector(radius: comptime_int, threshold: T, noalias srcp: []const T, noalias dstp: []T, width: usize, height: usize, stride: usize) void {
        //     // We process the mirrored pixels using our scalar implementation, as Grid.initFromCenterMirrored
        //     // doesn't fully support vectors at this time. That's why we need both a scalar Grid and a vector Grid.
        //     const GridS = switch (comptime radius) {
        //         1 => Grid3,
        //         2 => Grid5,
        //         3 => Grid7,
        //         else => unreachable,
        //     };
        //
        //     const GridV = switch (comptime radius) {
        //         1 => GridV3,
        //         2 => GridV5,
        //         3 => GridV7,
        //         else => unreachable,
        //     };
        //
        //     // We make some assumptions in this code in order to make processing with vectors simpler.
        //     std.debug.assert(width >= vector_len);
        //     std.debug.assert(radius < vector_len);
        //
        //     const width_simd = (width - radius) / vector_len * vector_len;
        //
        //     // Top rows - mirrored
        //     for (0..radius) |row| {
        //         for (0..width) |column| {
        //             var grid = GridS.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
        //             dstp[(row * stride) + column] = ccdScalar(threshold, &grid);
        //         }
        //     }
        //
        //     // Middle rows
        //     for (radius..height - radius) |row| {
        //         // First columns - mirrored
        //         for (0..radius) |column| {
        //             var gridFirst = GridS.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
        //             dstp[(row * stride) + column] = ccdScalar(threshold, &gridFirst);
        //         }
        //
        //         // Middle columns - not mirrored
        //         var column: usize = radius;
        //         while (column < width_simd) : (column += vector_len) {
        //             var grid = GridV.initFromCenter(T, row, column, srcp, stride);
        //             const result = ccdVector(threshold, &grid);
        //             vec.storeAt(VT, dstp, row, column, stride, result);
        //         }
        //
        //         // Last columns - non-mirrored
        //         // We do this to minimize the use of scalar mirror code.
        //         if (width_simd < width) {
        //             const adjusted_column = width - vector_len - radius;
        //             var grid = GridV.initFromCenter(T, row, adjusted_column, srcp, stride);
        //             const result = ccdVector(threshold, &grid);
        //             vec.storeAt(VT, dstp, row, adjusted_column, stride, result);
        //         }
        //
        //         // Last columns - mirrored
        //         for (width - radius..width) |c| {
        //             var gridLast = GridS.initFromCenterMirrored(T, row, c, width, height, srcp, stride);
        //             dstp[(row * stride) + c] = ccdScalar(threshold, &gridLast);
        //         }
        //     }
        //
        //     // Bottom rows - mirrored
        //     for (height - radius..height) |row| {
        //         for (0..width) |column| {
        //             var grid = GridS.initFromCenterMirrored(T, row, column, width, height, srcp, stride);
        //             dstp[(row * stride) + column] = ccdScalar(threshold, &grid);
        //         }
        //     }
        // }

        fn processPlanes(_threshold: f32, chroma: bool, bits_per_sample: u6, srcp8: [3][]const u8, dstp8: [3][]u8, width: usize, height: usize, stride8: usize) void {
            const threshold: BUAT = lossyCast(BUAT, _threshold);
            const stride = stride8 / @sizeOf(T);
            const srcp: [3][]const T = .{
                @ptrCast(@alignCast(srcp8[0])),
                @ptrCast(@alignCast(srcp8[1])),
                @ptrCast(@alignCast(srcp8[2])),
            };
            const dstp: [3][]T = .{
                @ptrCast(@alignCast(dstp8[0])),
                @ptrCast(@alignCast(dstp8[1])),
                @ptrCast(@alignCast(dstp8[2])),
            };

            const format_max = vscmn.getFormatMaximum2(T, bits_per_sample, chroma);
            const format_min = vscmn.getFormatMinimum2(T, chroma);

            // processPlaneScalar(threshold, format_min, format_max, srcp, dstp, width, height, stride);
            processPlanesScalar2(threshold, format_min, format_max, srcp, dstp, width, height, stride);
        }
    };
}

fn ccdGetFrame(n: c_int, activation_reason: ar, instance_data: ?*anyopaque, frame_data: ?*?*anyopaque, frame_ctx: ?*vs.FrameContext, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) ?*const vs.Frame {
    // Assign frame_data to nothing to stop compiler complaints
    _ = frame_data;

    const zapi = ZAPI.init(vsapi, core);
    const d: *CCDData = @ptrCast(@alignCast(instance_data));

    if (activation_reason == ar.Initial) {
        zapi.requestFrameFilter(n, d.node, frame_ctx);
    } else if (activation_reason == ar.AllFramesReady) {
        const src_frame = zapi.initZFrame(d.node, n, frame_ctx);
        defer src_frame.deinit();

        const dst = src_frame.newVideoFrame();

        const processPlanes: @TypeOf(&CCD(u8).processPlanes) = switch (vscmn.FormatType.getDataType(d.vi.format)) {
            .U8 => &CCD(u8).processPlanes,
            .U16 => &CCD(u16).processPlanes,
            .F16 => &CCD(f16).processPlanes,
            .F32 => &CCD(f32).processPlanes,
        };

        // Width, height, and stride are the same for all planes,
        // so just using values from the first one.
        const width: usize = dst.getWidth(0);
        const height: usize = dst.getHeight(0);
        const stride8: usize = dst.getStride(0);
        const srcp8: [3][]const u8 = .{
            src_frame.getReadSlice(0),
            src_frame.getReadSlice(1),
            src_frame.getReadSlice(2),
        };
        const dstp8: [3][]u8 = .{
            dst.getWriteSlice(0),
            dst.getWriteSlice(1),
            dst.getWriteSlice(2),
        };
        const chroma = vscmn.isChromaPlane(d.vi.format.colorFamily, 0);
        const bits_per_sample: u6 = @intCast(d.vi.format.bitsPerSample);

        processPlanes(d.threshold, chroma, bits_per_sample, srcp8, dstp8, width, height, stride8);

        return dst.frame;
    }

    return null;
}

export fn ccdFree(instance_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = core;
    const d: *CCDData = @ptrCast(@alignCast(instance_data));
    vsapi.?.freeNode.?(d.node);
    allocator.destroy(d);
}

export fn ccdCreate(in: ?*const vs.Map, out: ?*vs.Map, user_data: ?*anyopaque, core: ?*vs.Core, vsapi: ?*const vs.API) callconv(.C) void {
    _ = user_data;
    const zapi = ZAPI.init(vsapi, core);
    const inz = zapi.initZMap(in);
    // const outz = zapi.initZMap(out);

    var d: CCDData = undefined;

    d.node, d.vi = inz.getNodeVi("clip").?;

    // const scalep = inz.getBool("scalep") orelse false;

    d.threshold = inz.getFloat(f32, "threshold") orelse 4;
    d.threshold = (d.threshold * d.threshold) / (255 * 255 * 3);

    // const numThreshold: c_int = @intCast(inz.numElements("threshold") orelse 0);
    // if (numThreshold > d.vi.format.numPlanes) {
    //     outz.setError("CCD: Element count of threshold must be less than or equal to the number of input planes.");
    //     zapi.freeNode(d.node);
    //     return;
    // }
    // if (numThreshold > 0) {
    //     for (0..3) |i| {
    //         if (inz.getFloat2(f32, "threshold", i)) |_threshold| {
    //             const format_max = if (scalep) 255 else vscmn.getFormatMaximum(f32, d.vi.format, false);
    //             if (_threshold < 0 or _threshold > format_max) {
    //                 outz.setError(printf(allocator, "CCD: Invalid threshold, must be in the range of 0 - {d} with scalep = {} for this bit depth", .{ format_max, scalep }));
    //                 zapi.freeNode(d.node);
    //                 return;
    //             }
    //             d.threshold[i] = if (scalep) vscmn.scaleToFormat(f32, d.vi.format, _threshold, 0) else _threshold;
    //         } else {
    //             d.threshold[i] = d.threshold[i - 1];
    //         }
    //     }
    // } else {
    //     const fifty = vscmn.scaleToFormat(f32, d.vi.format, 50, 0);
    //     const one_twenty_eight = vscmn.scaleToFormat(f32, d.vi.format, 128, 0);
    //     d.threshold = .{
    //         if (d.radius[0] == 1) fifty else one_twenty_eight,
    //         if (d.radius[1] == 1) fifty else one_twenty_eight,
    //         if (d.radius[2] == 1) fifty else one_twenty_eight,
    //     };
    // }

    const data: *CCDData = allocator.create(CCDData) catch unreachable;
    data.* = d;

    var deps = [_]vs.FilterDependency{
        vs.FilterDependency{
            .source = d.node,
            .requestPattern = rp.StrictSpatial,
        },
    };

    zapi.createVideoFilter(out, "CCD", d.vi, ccdGetFrame, ccdFree, fm.Parallel, &deps, data);
}

pub fn registerFunction(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.registerFunction.?("CCD", "clip:vnode;threshold:float:opt;scalep:int:opt;", "clip:vnode;", ccdCreate, null, plugin);
}
