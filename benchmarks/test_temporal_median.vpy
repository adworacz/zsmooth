import vapoursynth as vs
from vstools import depth
from vspreview.api import is_preview

core = vs.core
core.max_cache_size = 1024
core.num_threads = 1

if is_preview():
    radius = 1
    output = 'all'
#format = 'u8'

length = 3000
match format:
    case 'u8':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGB24, color=[255, 255, 255], length=length)
        # clip = core.std.BlankClip(width=1920,height=1080, format=vs.YUV420P8, color=[255, 128, 128], length=length)
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

# Use 720 x 480 to check stride issues.
# clip = clip.resize.Lanczos(720, 480, format=vs.YUV444P16)
# clip = clip.resize.Lanczos(720, 480)

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
