import vapoursynth as vs
from vstools import depth
from vspreview.api import is_preview

core = vs.core
core.max_cache_size = 1024
core.num_threads = 1

mode = 1
length = 3000

if is_preview():
    output = 'all'

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

# clip = depth(clip, 10)
# clip = depth(clip, 16)
# clip = depth(clip, 16, sample_type=vs.FLOAT)
# clip = depth(clip, 32)

# Use 720 x 480 to check stride issues.
# clip = clip.resize.Lanczos(720, 480, format=vs.YUV444P16)
# clip = clip.resize.Lanczos(720, 480)

clip.set_output(0)

if (format not in ['f16', 'f32']):
    rg = clip.rgvs.RemoveGrain(mode)
else:
    # Note - RGSF uses double precision for some modes, which might be part of the reason for certain differences.
    rg = clip.rgsf.RemoveGrain(mode)

if mode == 4:
    std = clip.std.Median()
if mode in [11, 12]:
    std = clip.std.Convolution(matrix=[1, 2, 1, 2, 4, 2, 1, 2, 1])
if mode == 19:
    std = clip.std.Convolution(matrix=[1, 1, 1, 1, 0, 1, 1, 1, 1])
if mode == 20:
    std = clip.std.Convolution(matrix=[1, 1, 1, 1, 1, 1, 1, 1, 1])

zsmooth = clip.zsmooth.RemoveGrain(mode)

match output:
    case 'zsmooth':
        zsmooth.set_output()
    case 'rg':
        rg.set_output()
    case 'all':
        clip.set_output(0)
        rg.set_output(1)
        if mode in [4, 11, 12, 19, 20]:
            std.set_output(2)
        zsmooth.set_output(3)



