import vapoursynth as vs
from vstools import depth

core = vs.core

# radius = 1
# output = 'all'

# format = 'u8'

length = 1000
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

if format != 'f16':
    tmedian = clip.tmedian.TemporalMedian(radius=radius)
    neo = clip.neo_tmedian.TemporalMedian(radius=radius)

zsmooth = clip.zsmooth.TemporalMedian(radius=radius)

match output:
    case 'zsmooth':
        zsmooth.set_output()
    case 'tmedian':
        tmedian.set_output()
    case 'neo':
        neo.set_output()
    case 'all':
        clip.set_output(0)
        tmedian.set_output(1)
        zsmooth.set_output(2)
        neo.set_output(3)
