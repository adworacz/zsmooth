const vapoursynth = @import("vapoursynth");
const vs = vapoursynth.vapoursynth4;

const temporalMedian = @import("temporal_median.zig");
const temporalSoften = @import("temporal_soften.zig");
const removeGrain = @import("remove_grain.zig");
const repairGrain = @import("repair.zig");
const verticalCleaner = @import("vertical_cleaner.zig");
const clense = @import("clense.zig");
const fluxSmooth = @import("fluxsmooth.zig");
const degrainMedian = @import("degrain_median.zig");
const interQuartileMean = @import("inter_quartile_mean.zig");
const ttempsmooth = @import("ttempsmooth.zig");
const median = @import("median.zig");
const temporalRepair = @import("temporal_repair.zig");
const smartMedian = @import("smart_median.zig");

const version = @import("version.zig").version;

export fn VapourSynthPluginInit2(plugin: *vs.Plugin, vsapi: *const vs.PLUGINAPI) void {
    _ = vsapi.configPlugin.?("com.adub.zsmooth", "zsmooth", "Smoothing functions in Zig", vs.makeVersion(version.major, version.minor), vs.VAPOURSYNTH_API_VERSION, 0, plugin);

    temporalMedian.registerFunction(plugin, vsapi);
    temporalSoften.registerFunction(plugin, vsapi);
    removeGrain.registerFunction(plugin, vsapi);
    repairGrain.registerFunction(plugin, vsapi);
    verticalCleaner.registerFunction(plugin, vsapi);
    clense.registerFunction(plugin, vsapi);
    fluxSmooth.registerFunction(plugin, vsapi);
    degrainMedian.registerFunction(plugin, vsapi);
    interQuartileMean.registerFunction(plugin, vsapi);
    ttempsmooth.registerFunction(plugin, vsapi);
    median.registerFunction(plugin, vsapi);
    temporalRepair.registerFunction(plugin, vsapi);
    smartMedian.registerFunction(plugin, vsapi);
}
