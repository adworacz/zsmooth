import vapoursynth as vs

core = vs.core
core.max_cache_size = 1024
core.num_threads = 1

# format = 'u8'
length = 30000

from vspreview.api import is_preview
if is_preview():
    output = 'all'
    temporal_radius = 0
    # format = 'u8'

# Handle strings passed in by vspipe args.
temporal_radius = int(temporal_radius)

match format:
    case 'u8':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGB24, color=[255, 255, 255], length=length)
    case 'u16':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGB48, color=[255, 255, 255], length=length)
    case 'f16':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGBH, color=[1.0, 1.0, 1.0], length=length)
    case 'f32':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.RGBS, color=[1.0, 1.0, 1.0], length=length)
    case _:
        # clip = core.lsmas.LWLibavSource("/home/adub/Videos/Audi R8.mp4")
        # clip = core.lsmas.LWLibavSource("/home/adub/Videos/test.webm")
        clip = core.bs.VideoSource("/home/adub/Videos/Audi R8.mp4", cachemode=3)
        #clip = core.bs.VideoSource("/home/adub/Videos/test.mp4")

from vstools import depth
# clip = depth(clip, 10)
# clip = depth(clip, 16)
# clip = depth(clip, 16, sample_type=vs.FLOAT)
# clip = depth(clip, 32)

# Use 720 x 480 to check stride issues.
# clip = clip.resize.Lanczos(720, 480, format=vs.YUV444P16)
# clip = clip.resize.Lanczos(720, 480)

clip.set_output(0)

# Requires akarin...
if output in ['cnr2', 'all']:
    cnr2 = clip.cnr2.Cnr2(mode='oxx')

zsmooth = clip.zsmooth.Cnr3(mode='oxx')

match output:
    case 'zsmooth':
        zsmooth.set_output()
    case 'ccd':
        cnr2.set_output()
    case 'all':
        clip.set_output(0)
        cnr2.set_output(1)
        zsmooth.set_output(3)
    case _:
        raise f"Unrecognized output type: {output}"

