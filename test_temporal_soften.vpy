import vapoursynth as vs
from vstools import depth

core = vs.core


clip = core.lsmas.LWLibavSource("/home/adub/Videos/Audi R8.mp4")

# clip = core.std.BlankClip(width=1920,height=1080, length=1000)
# clip = clip.std.ShufflePlanes(0, vs.GRAY)
# clip = depth(clip, 16)
# clip = depth(clip, 32)
clip.set_output(0)

# TODO: Float support doesn't work just yet.

radius = 1
luma = 4
chroma = 8

cppsoften = clip.focus2.TemporalSoften2(radius=radius, luma_threshold=luma, chroma_threshold=chroma)
cppsoften.set_output(1)

zmooth = clip.zmooth.TemporalSoften2(radius=radius, luma_threshold=luma, chroma_threshold=chroma)
zmooth.set_output(2)


core.std.MakeDiff(clip, zmooth).set_output(4)
# core.std.MakeDiff(cppmedian, zmooth).set_output(5)
