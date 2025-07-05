import vapoursynth as vs

core = vs.core
core.max_cache_size = 1024
core.num_threads = 1

# format = 'u8'
threshold = 20 
length = 30000

from vspreview.api import is_preview
if is_preview():
    output = 'all'
    # format = 'u8'

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
        # clip = core.bs.VideoSource("/home/adub/Videos/Audi R8.mp4")
        clip = core.bs.VideoSource("/home/adub/Videos/test.webm")
        from vstools import initialize_clip
        clip = initialize_clip(clip)
        # clip = clip.resize.Point(format=vs.RGB24)
        clip = clip.resize.Point(format=vs.RGBS)

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
if output in ['ccd', 'all']:
    ccd = clip.ccd.CCD(threshold)

if output in ['jetpack', 'all']:
    from vsdenoise import ccd as jetccd, CCDPoints
    jetpack = jetccd(clip, thr = threshold, scale=0, ref_points = CCDPoints.LOW | CCDPoints.MEDIUM, planes=[0,1,2]) # Scale=0 for jetpack is the same as scale=1 for zsmooth.

zsmooth = clip.zsmooth.CCD(threshold, scale=1, points=[True, True, False]) # Use scale=1 to make apples-to-apples comparison of output and performance with ccd.CCD

match output:
    case 'zsmooth':
        zsmooth.set_output()
    case 'ccd':
        ccd.set_output()
    case 'jetpack':
        jetpack.set_output()
    case 'all':
        clip.set_output(0)
        ccd.set_output(1)
        jetpack.set_output(2)
        zsmooth.set_output(3)
    case _:
        raise f"Unrecognized output type: {output}"

