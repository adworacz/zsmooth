import vapoursynth as vs
from vstools import depth
from vspreview.api import is_preview

core = vs.core
core.max_cache_size = 1024
core.num_threads = 1

if is_preview():
    output = 'all'
limit = 4
mode = 0
#format = 'u8'

length = 1000
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

clip = depth(clip, 16)
# clip = depth(clip, 16, sample_type=vs.FLOAT)
# clip = depth(clip, 32)

# Use 720 x 480 to check stride issues.
# clip = clip.resize.Lanczos(720, 480, format=vs.YUV444P16)
# clip = clip.resize.Lanczos(720, 480)

clip.set_output(0)

if format != 'f16' and format != 'f32':
    dgm = clip.dgm.DegrainMedian(limit=limit, mode=mode)

zsmooth = clip.zsmooth.DegrainMedian(limit=limit, mode=mode, scalep=True)

match output:
    case 'zsmooth':
        zsmooth.set_output()
    case 'dgm':
        dgm.set_output()
    case 'all':
        clip.set_output(0)
        dgm.set_output(1)
        zsmooth.set_output(2)
