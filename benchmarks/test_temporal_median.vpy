import vapoursynth as vs
from vstools import depth

core = vs.core

# clip = core.lsmas.LWLibavSource("/home/adub/Videos/Audi R8.mp4")

length = 3000
clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGB24, length=length)
# clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGB48, length=length)
# clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGBH, length=length)
# clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGBS, length=length)
# clip = depth(clip, 16)
# clip = depth(clip, 32)
clip.set_output(0)

radius = 1

cppmedian = clip.tmedian.TemporalMedian(radius=radius)
cppmedian.set_output(1)

zsmooth = clip.zsmooth.TemporalMedian(radius=radius)
zsmooth.set_output(2)

neo = clip.neo_tmedian.TemporalMedian(radius=radius)
neo.set_output(3)

# core.std.MakeDiff(clip, zsmooth).set_output(4)
# core.std.MakeDiff(cppmedian, zsmooth).set_output(5)
