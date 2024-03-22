import vapoursynth as vs
from vstools import depth

core = vs.core

# clip = core.lsmas.LWLibavSource("/home/adub/Videos/Audi R8.mp4")

# format = 'u8'
# radius = 1

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
        print("Unrecognized format")
        exit(1)

# clip = depth(clip, 16)
# clip = depth(clip, 16, sample_type=vs.FLOAT)
# clip = depth(clip, 32)
clip.set_output(0)


cppmedian = clip.tmedian.TemporalMedian(radius=radius)
cppmedian.set_output(1)

zsmooth = clip.zsmooth.TemporalMedian(radius=radius)
zsmooth.set_output(2)

neo = clip.neo_tmedian.TemporalMedian(radius=radius)
neo.set_output(3)

