import vapoursynth as vs
from vspreview.api import is_preview

core = vs.core
core.max_cache_size = 1024
core.num_threads = 1

length = 30000

if is_preview():
    mode = 0
    # format = 'u8'
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

from vstools import depth
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
# smoothed = clip.zsmooth.RemoveGrain(12)
smoothed = clip
smoothed.set_output(8)

zsmooth = smoothed.zsmooth.TemporalRepair(clip, mode)
smoothed.zsmooth.TemporalRepair(clip, 0).set_output(3)
smoothed.zsmooth.TemporalRepair(clip, 1).set_output(4)
smoothed.zsmooth.TemporalRepair(clip, 2).set_output(5)
smoothed.zsmooth.TemporalRepair(clip, 3).set_output(6)
smoothed.zsmooth.TemporalRepair(clip, 4).set_output(7)

match output:
    case 'zsmooth':
        zsmooth.set_output()
    case 'all':
        clip.set_output(0)
        zsmooth.set_output(2)
    case _:
        raise f"Unrecognized output type: {output}"
