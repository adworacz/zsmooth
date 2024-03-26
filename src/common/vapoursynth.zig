const vapoursynth = @import("vapoursynth");

const vs = vapoursynth.vapoursynth4;
const vsh = vapoursynth.vshelper;

/// Creates a new video frame with optional copying of source planes from a src
/// frame. The copies are goverened by the boolean values in the `process`
/// variable. If the value is true, then its expected to be proccessed by the
/// caller, and thus is *not* copied from the src frame.
///
/// If the value is false, then the plane is copied from the source frame.
pub fn newVideoFrame(process: *const [3]bool, src: ?*const vs.Frame, vi: *const vs.VideoInfo, core: ?*vs.Core, vsapi: ?*const vs.API) ?*vs.Frame {
    // Prepare array of frame pointers, with null for planes we will process,
    // and pointers to the source frame for planes we won't process.
    var plane_src = [_]?*const vs.Frame{
        if (process[0]) null else src,
        if (process[1]) null else src,
        if (process[2]) null else src,
    };
    const planes = [_]c_int{ 0, 1, 2 };

    return vsapi.?.newVideoFrame2.?(&vi.format, vi.width, vi.height, @ptrCast(&plane_src), @ptrCast(&planes), src, core);
}

pub const PlanesError = error{
    IndexOutOfRange,
    SpecifiedTwice,
};

/// Handles coercing plane specifications from user input into a usable
/// process array.
///
/// Specifically it handles input like:
/// planes=[1]
/// planes=[0,1,2]
/// planes=2
///
/// It will error if a plane is out of range (like 999) or
/// if the plane has been specified twice (like [1,1]).
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
