const vapoursynth = @import("vapoursynth");

const vs = vapoursynth.vapoursynth4;
const vsh = vapoursynth.vshelper;

pub const PlanesError = error{
    IndexOutOfRange,
    SpecifiedTwice,
};

pub fn normalizePlanes(format: vs.VideoFormat, in: ?*const vs.Map, vsapi: ?*const vs.API) PlanesError![3]bool {
    //mapNumElements returns -1 if the element doesn't exist (aka, the user doesn't specify the option.)
    const requestedPlanesSize = vsapi.?.mapNumElements.?(in, "planes");
    const requestedPlanesIsEmpty = requestedPlanesSize <= 0;
    const numPlanes = format.numPlanes;
    var process = [_]bool{ requestedPlanesIsEmpty, requestedPlanesIsEmpty, requestedPlanesIsEmpty };

    if (!requestedPlanesIsEmpty) {
        for (0..@intCast(requestedPlanesSize)) |i| {
            const plane: u8 = vsh.mapGetN(u8, in, "planes", @intCast(i), vsapi) orelse unreachable;

            if (plane < 0 or plane > numPlanes) {
                return PlanesError.IndexOutOfRange;
            }

            if (process[plane]) {
                return PlanesError.SpecifiedTwice;
            }

            process[plane] = true;
        }
    }
    return process;
}
