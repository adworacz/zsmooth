import vapoursynth as vs
from vstools import depth

core = vs.core

clip = core.lsmas.LWLibavSource("/home/adub/Videos/Audi R8.mp4")

length = 1500
# clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGB24, length=length)
# clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGB48, length=length)
# clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGBH, length=length)
# clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGBS, length=length)
# clip = depth(clip, 16)
# clip = depth(clip, 32)
clip.set_output(0)

radius = 7

cppsoften = clip.focus2.TemporalSoften2(radius=radius)
cppsoften.set_output(1)

zsmooth = clip.zsmooth.TemporalSoften(radius=radius);
zsmooth.set_output(2)

