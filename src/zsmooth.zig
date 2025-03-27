const vapoursynth = @import("vapoursynth");
const vs = vapoursynth.vapoursynth4;

const temporalMedian = @import("temporal_median.zig");
const temporalSoften = @import("temporal_soften.zig");
const removeGrain = @import("remove_grain.zig");
const repairGrain = @import("repair.zig");
const fluxSmooth = @import("fluxsmooth.zig");
const degrainMedian = @import("degrain_median.zig");

const version = @import("version.zig").version;

export fn VapourSynthPluginInit2(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.configPlugin.?("com.adub.zsmooth", "zsmooth", "Smoothing functions in Zig", vs.makeVersion(version.major, version.minor), vs.VAPOURSYNTH_API_VERSION, 0, plugin);

    temporalMedian.registerFunction(plugin, vsapi);
    temporalSoften.registerFunction(plugin, vsapi);
    removeGrain.registerFunction(plugin, vsapi);
    repairGrain.registerFunction(plugin, vsapi);
    fluxSmooth.registerFunction(plugin, vsapi);
    degrainMedian.registerFunction(plugin, vsapi);
}
