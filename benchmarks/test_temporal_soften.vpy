import vapoursynth as vs
from vspreview.api import is_preview

core = vs.core
core.max_cache_size = 1024
core.num_threads = 1

if is_preview():
    radius = 7
    output = 'all'

# format = 'u8'

length = 30000
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

# clip = depth(clip, 16)
# clip = depth(clip, 16, sample_type=vs.FLOAT)
# clip = depth(clip, 32)

# Use 720 x 480 to check stride issues.
# clip = clip.resize.Lanczos(720, 480)

clip.set_output(0)


if format not in ['f16', 'f32']:
    focus2 = clip.focus2.TemporalSoften2(radius=radius)

zsmooth = clip.zsmooth.TemporalSoften(radius=radius);

match output:
    case 'focus2':
        focus2.set_output()
    case 'zsmooth':
        zsmooth.set_output()
    case 'all':
        clip.set_output(0)
        focus2.set_output(1)
        zsmooth.set_output(2)
    case _:
        raise f"Unrecognized output type: {output}"


