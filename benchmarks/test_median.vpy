import vapoursynth as vs

core = vs.core
core.max_cache_size = 1024
core.num_threads = 1

# format = 'u8'
#radius = 1
length = 30000

from vspreview.api import is_preview
if is_preview():
    radius = 1
    format='u8'
    output = 'all'

match format:
    case 'u8':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.YUV420P8, color=[255, 128, 128], length=length)
    case 'u16':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.YUV420P16, color=[255, 128, 128], length=length)
    case 'f16':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.YUV420PH, color=[1.0, 0, 0], length=length)
    case 'f32':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.YUV420PS, color=[1.0, 0, 0], length=length)
    case _:
        # clip = core.lsmas.LWLibavSource("/home/adub/Videos/Audi R8.mp4")
        clip = core.bs.VideoSource("/home/adub/Videos/Audi R8.mp4")

# from vstools import depth
# clip = depth(clip, 10)
# clip = depth(clip, 16)
# clip = depth(clip, 16, sample_type=vs.FLOAT)
# clip = depth(clip, 32)

# Use 720 x 480 to check stride issues.
# clip = clip.resize.Lanczos(720, 480, format=vs.YUV444P16)
# clip = clip.resize.Lanczos(720, 480)

clip.set_output(0)

std = clip.std.Median()

zsmooth = clip.zsmooth.Median(int(radius))

match output:
    case 'zsmooth':
        zsmooth.set_output()
    case 'std':
        std.set_output()
    case 'all':
        clip.set_output(0)
        std.set_output(1)
        zsmooth.set_output(3)
    case _:
        raise f"Unrecognized output type: {output}"

