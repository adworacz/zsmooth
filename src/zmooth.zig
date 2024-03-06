const vapoursynth = @import("vapoursynth");
const vs = vapoursynth.vapoursynth4;

const temporalMedian = @import("temporal_median.zig");
const temporalSoften = @import("temporal_soften.zig");

export fn VapourSynthPluginInit2(plugin: *vs.Plugin, vspapi: *const vs.PLUGINAPI) void {
    _ = vspapi.configPlugin.?("com.adub.zmooth", "zmooth", "Smoothing functions in Zig", vs.makeVersion(1, 0), vs.VAPOURSYNTH_API_VERSION, 0, plugin);
    _ = vspapi.registerFunction.?("TemporalMedian", "clip:vnode;radius:int:opt;planes:int[]:opt;", "clip:vnode;", temporalMedian.temporalMedianCreate, null, plugin);
    _ = vspapi.registerFunction.?("TemporalSoften2", "clip:vnode;radius:int:opt;luma_threshold:int:opt;chroma_threshold:int:opt;scenechange:int:opt;mode:int:opt;", "clip:vnode;", temporalSoften.temporalSoftenCreate, null, plugin);
}
