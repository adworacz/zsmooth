import vapoursynth as vs
from vstools import depth
core = vs.core

clip = core.lsmas.LWLibavSource("/home/adub/Videos/Audi R8.mp4")

length = 3000
# clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGB24, length=length)
# clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGB48, length=length)
# clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGBS, length=length)
clip.set_output(0)

clip.rgvs.RemoveGrain(1).set_output(1)

clip.zmooth.RemoveGrain(1).set_output(2)
