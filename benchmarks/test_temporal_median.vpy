import vapoursynth as vs

core = vs.core
core.max_cache_size = 1024
core.num_threads = 1

from vspreview.api import is_preview
if is_preview():
    radius = 1
    output = 'all'
#format = 'u8'
radius = 1
output = 'zsmooth'

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
        # clip = core.bs.VideoSource("/home/adub/Videos/Audi R8.mp4")
        clip = core.lsmas.LWLibavSource("/home/adub/Videos/Downfall of The Democrats ｜ The Truth About The 2024 Election [UkUkEvf7Ma4].webm")

#from vstools import depth
# clip = depth(clip, 16)
# clip = depth(clip, 16, sample_type=vs.FLOAT)
# clip = depth(clip, 32)

# Use 720 x 480 to check stride issues.
# clip = clip.resize.Lanczos(720, 480, format=vs.YUV444P16)
# clip = clip.resize.Lanczos(720, 480)

clip.set_output(0)

if format != 'f16':
    if output in ['tmedian', 'all']:
        tmedian = clip.tmedian.TemporalMedian(radius=radius)
    if output in ['neo_tmedian', 'all']:
        neo = clip.neo_tmedian.TemporalMedian(radius=radius)

# TODO actually use 
zsmooth = clip.zsmooth.TemporalMedian(radius=radius, scenechange=True)

match output:
    case 'zsmooth':
        zsmooth.set_output()
    case 'tmedian':
        tmedian.set_output()
    case 'neo_tmedian':
        neo.set_output()
    case 'all':
        tmedian.set_output(1)
        zsmooth.set_output(2)
        neo.set_output(3)
    case _:
        raise f"Unrecognized output type: {output}"
    
