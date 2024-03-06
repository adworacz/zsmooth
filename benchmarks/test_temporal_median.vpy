import vapoursynth as vs
from vstools import depth

core = vs.core

# clip = core.std.BlankClip()

clip = core.lsmas.LWLibavSource("/home/adub/Videos/Audi R8.mp4")
# clip = clip.std.ShufflePlanes(0, vs.GRAY)
clip.set_output(0)

# clip = depth(clip, 16)
# clip = depth(clip, 32)

radius = 1

cppmedian = clip.tmedian.TemporalMedian(radius=radius)
cppmedian.set_output(1)

zmooth = clip.zmooth.TemporalMedian(radius=radius)
zmooth.set_output(2)

neo = clip.neo_tmedian.TemporalMedian(radius=radius)
neo.set_output(3)

core.std.MakeDiff(clip, zmooth).set_output(4)
core.std.MakeDiff(cppmedian, zmooth).set_output(5)
