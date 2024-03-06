import vapoursynth as vs
from vstools import depth

core = vs.core


clip = core.lsmas.LWLibavSource("/home/adub/Videos/Audi R8.mp4")
# clip = clip.std.ShufflePlanes(0, vs.GRAY)
# clip = depth(clip, 16)
# clip = depth(clip, 32)
clip.set_output(0)

# TODO: Float support doesn't work just yet.

radius = 1

# cppmedian = clip.tmedian.TemporalMedian(radius=radius)
# cppmedian.set_output(1)

zmooth = clip.zmooth.TemporalSoften2(radius=radius)
zmooth.set_output(2)


core.std.MakeDiff(clip, zmooth).set_output(4)
# core.std.MakeDiff(cppmedian, zmooth).set_output(5)
