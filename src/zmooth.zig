const vapoursynth = @import("vapoursynth");
const vs = vapoursynth.vapoursynth4;

const temporalMedian = @import("temporal_median.zig");
const temporalSoften = @import("temporal_soften.zig");
const removeGrain = @import("remove_grain.zig");

const version = @import("version.zig").version;

export fn VapourSynthPluginInit2(plugin: *vs.Plugin, vspapi: *const vs.PLUGINAPI) void {
    _ = vspapi.configPlugin.?("com.adub.zmooth", "zmooth", "Smoothing functions in Zig", vs.makeVersion(version.major, version.minor), vs.VAPOURSYNTH_API_VERSION, 0, plugin);
    _ = vspapi.registerFunction.?("TemporalMedian", "clip:vnode;radius:int:opt;planes:int[]:opt;", "clip:vnode;", temporalMedian.temporalMedianCreate, null, plugin);
    _ = vspapi.registerFunction.?("TemporalSoften", "clip:vnode;radius:int:opt;threshold:int[]:opt;scenechange:int:opt;", "clip:vnode;", temporalSoften.temporalSoftenCreate, null, plugin);
    _ = vspapi.registerFunction.?("RemoveGrain", "clip:vnode;mode:int[]", "clip:vnode;", removeGrain.removeGrainCreate, null, plugin);
}
