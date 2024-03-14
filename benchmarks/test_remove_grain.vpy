import vapoursynth as vs
from vstools import depth
core = vs.core

# clip = core.lsmas.LWLibavSource("/home/adub/Videos/Audi R8.mp4")
#
length = 3000
clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGB24, length=length)
# clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGB48, length=length)
# clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGBH, length=length)
# clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGBS, length=length)
# clip = depth(clip, 16)
# clip = depth(clip, 32)
clip.set_output(0)

mode = 11
# clip.rgvs.RemoveGrain(mode).set_output(1)
# Note - RGSF uses double precision for some modes, which might be part of the reason for certain differences.
# clip.rgsf.RemoveGrain(mode).set_output(1)

# Mode 4
# if mode == 4:
#     clip.std.Median().set_output(1)
if mode in [11, 12]:
    clip.std.Convolution(matrix=[1, 2, 1, 2, 4, 2, 1, 2, 1]).set_output(1)



clip.zmooth.RemoveGrain(mode).set_output(2)
