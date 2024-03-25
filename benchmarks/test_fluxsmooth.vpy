import vapoursynth as vs
from vstools import depth

core = vs.core

threshold = 20
# format = 'u8'
# output = 'all'

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
clip.set_output(0)


if format not in ['f16', 'f32']:
    flux = clip.flux.SmoothT(temporal_threshold=threshold)

zsmooth = clip.zsmooth.SmoothT(temporal_threshold=threshold);

match output:
    case 'flux':
        flux.set_output()
    case 'zsmooth':
        zsmooth.set_output()
    case _:
        clip.set_output(0)
        flux.set_output(1)
        zsmooth.set_output(2)

