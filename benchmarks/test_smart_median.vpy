import vapoursynth as vs

core = vs.core
core.max_cache_size = 1024
core.num_threads = 1

# format = 'u8'
# radius = 1
length = 30000

from vspreview.api import is_preview
if is_preview():
    output = 'all'
    # format = 'u8' # around 645-650 fps, radius 1
    radius = 1

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

from vstools import depth
# clip = depth(clip, 10)
# clip = depth(clip, 16)
# clip = depth(clip, 16, sample_type=vs.FLOAT)
# clip = depth(clip, 32)

# Use 720 x 480 to check stride issues.
# clip = clip.resize.Lanczos(720, 480, format=vs.YUV444P16)
# clip = clip.resize.Lanczos(720, 480)

clip.set_output(0)

threshold = 50
zsmooth = clip.zsmooth.SmartMedian(radius, threshold, scalep=True)

match output:
    case 'zsmooth':
        zsmooth.set_output()
    case 'all':
        clip.set_output(0)
        zsmooth.set_output(2)
    case _:
        raise f"Unrecognized output type: {output}"

