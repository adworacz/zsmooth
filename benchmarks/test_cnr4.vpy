import vapoursynth as vs

core = vs.core
core.max_cache_size = 1024
# core.num_threads = 1

# Handle strings passed in by vspipe args.
# radius = 3
# tmode = 0
# output = 'all'
# format = 'u8'
length = 30000

from vspreview.api import is_preview as vsp_ispreview
# from vsview import is_preview as vsv_ispreview
# if (vsv_ispreview() or vsp_ispreview()):
if vsp_ispreview():
    output = 'all'
    radius = 3
    tmode = 0
    # format = 'u8'

radius = int(radius)
tmode = int(tmode)

match format:
    case 'u8':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.YUV420P8, color=[255, 255, 255], length=length)
    case 'u16':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.YUV420P16, color=[255, 255, 255], length=length)
    case 'f16':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.YUV420PH, color=[1.0, 1.0, 1.0], length=length)
    case 'f32':
        clip = core.std.BlankClip(width=1920,height=1080, format=vs.YUV420PS, color=[1.0, 1.0, 1.0], length=length)
    case _:
        # clip = core.lsmas.LWLibavSource("/home/adub/Videos/Audi R8.mp4")
        # clip = core.lsmas.LWLibavSource("/home/adub/Videos/test.webm")
        clip = core.bs.VideoSource("/home/adub/Videos/Audi R8.mp4", cachemode=3)
        # clip = core.bs.VideoSource("/home/adub/Videos/test.webm", cachemode=3)
        #clip = core.bs.VideoSource("/home/adub/Videos/test.mp4")
        from vstools import initialize_clip
        clip = initialize_clip(clip, bits=8)

from vstools import depth, sc_detect
# clip = depth(clip, 10)
# clip = depth(clip, 16)
# clip = depth(clip, 16, sample_type=vs.FLOAT)
# clip = depth(clip, 32)

# Use 720 x 480 to check stride issues.
# clip = clip.resize.Lanczos(720, 480, format=vs.YUV444P16)
# clip = clip.resize.Lanczos(720, 480)

clip.set_output(0)

sense=[35, -1,  -1]
str=[192, -1, -1]

if output in ['cnr2', 'all']:
    cnr2 = clip.cnr2.Cnr2(mode='oxx', ln=sense[0])

# clip = sc_detect(clip)

# 7394
zsmooth = clip.zsmooth.Cnr4(mode='oxx', scenechange=False, tmode=tmode, wmode=1, sense=sense, str=str, radius=radius)

match output:
    case 'zsmooth':
        zsmooth.set_output()
    case 'cnr2':
        cnr2.set_output()
    case 'all':
        clip.set_output(0)
        cnr2.set_output(1)
        zsmooth.set_output(3)
    case _:
        raise f"Unrecognized output type: {output}"

