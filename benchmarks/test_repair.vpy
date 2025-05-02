import vapoursynth as vs
from vstools import get_sample_type, depth
from vspreview.api import is_preview

core = vs.core
core.max_cache_size = 1024
core.num_threads = 1

length = 30000

if is_preview():
    mode = "1"
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
        # clip = core.lsmas.LWLibavSource("/home/adub/Videos/Audi R8.mp4")
        clip = core.bs.VideoSource("/home/adub/Videos/Audi R8.mp4")

# clip = depth(clip, 10)
# clip = depth(clip, 16)
# clip = depth(clip, 16, sample_type=vs.FLOAT)
# clip = depth(clip, 32)

# Use 720 x 480 to check stride issues.
# clip = clip.resize.Lanczos(720, 480, format=vs.YUV444P16)
# clip = clip.resize.Lanczos(720, 480)

clip.set_output(0)

# Make a nice and blury clip to feed to repair functions, since the blur should
# provide a lot of change and thus make repair operations more evident.
repair_clip = clip.std.Convolution(matrix=[1, 2, 1, 2, 4, 2, 1, 2, 1])

# if (format not in ['f16', 'f32']):
if (get_sample_type(clip) == vs.INTEGER):
    rg = clip.rgvs.Repair(repair_clip, mode)
else:
    # # Note - RGSF uses double precision for some modes, which might be part of the reason for certain differences.
    rg = clip.rgsf.Repair(repair_clip, mode)

zsmooth = clip.zsmooth.Repair(repair_clip, mode)

match output:
    case 'zsmooth':
        zsmooth.set_output()
    case 'rg':
        rg.set_output()
    case 'all':
        clip.set_output(0)
        rg.set_output(1)
        zsmooth.set_output(2)
    case _:
        raise f"Unrecognized output type: {output}"
