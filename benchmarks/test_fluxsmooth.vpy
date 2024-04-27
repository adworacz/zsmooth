import vapoursynth as vs
from vstools import depth, get_depth
from vspreview.api import is_preview

core = vs.core

threshold = 20
# threshold = 20 << 8
# threshold = 20 / 255.0
# format = 'u8'
# output = 'all'

if is_preview():
    output = 'all'

length = 3000
match format:
    case 'u8':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGB24, length=length)
    case 'u16':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGB48, length=length)
    case 'f16':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGBH, length=length)
    case 'f32':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGBS, length=length)
    case _:
        clip = core.lsmas.LWLibavSource("/home/adub/Videos/Audi R8.mp4")

# clip = depth(clip, 16)
# clip = depth(clip, 16, sample_type=vs.FLOAT)
# clip = depth(clip, 32)

# Use 720 x 480 to check stride issues.
# clip = clip.resize.Lanczos(720, 480)

clip.set_output(0)

if format not in ['f16', 'f32'] and get_depth(clip) != 32:
    flux = clip.flux.SmoothT(temporal_threshold=threshold)
    # flux = clip.flux.SmoothST(temporal_threshold=threshold, spatial_threshold=threshold)

zsmooth = clip.zsmooth.FluxSmoothT(scalep=True, temporal_threshold=threshold);
# zsmooth = clip.zsmooth.FluxSmoothST(scalep=True, temporal_threshold=threshold, spatial_threshold=threshold)
# zsmooth = clip.zsmooth.FluxSmoothST(scalep=True, temporal_threshold=1, spatial_threshold=-1);

match output:
    case 'flux':
        flux.set_output()
    case 'zsmooth':
        zsmooth.set_output()
    case _:
        clip.set_output(0)
        if get_depth(clip) != 32:
            flux.set_output(1)
        zsmooth.set_output(2)


