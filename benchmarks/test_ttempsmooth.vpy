import vapoursynth as vs

core = vs.core
core.max_cache_size = 1024
core.num_threads = 1

# Identical if temporal only weights (threshold = mdiff)
# Identical if temporal difference with strength = radius (equal weights for all frames)
# Different if temporal differene with strength < radius, which would produce different weights for each frame.
from vspreview.api import is_preview
if is_preview():
    radius = 1
    output = 'all'
    threshold = [4,5,5]
    # threshold = [20,20,20]
    mdiff = [2,3,3]
    # mdiff = threshold
    output = 'all'

# format = 'u8'

# strength = radius + 1
strength = 1
fp = True

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

from vstools import depth
# clip = depth(clip, 16)
# clip = depth(clip, 16, sample_type=vs.FLOAT)
# clip = depth(clip, 32)

# Use 720 x 480 to check stride issues.
# clip = clip.resize.Lanczos(720, 480, format=vs.YUV444P16)
# clip = clip.resize.Lanczos(720, 480)

clip.set_output(0)

if format != 'f16':
    if output in ['ttmpsm', 'all']:
        ttempsmooth = clip.ttmpsm.TTempSmooth(maxr=radius, thresh=threshold, mdiff=mdiff, strength=strength, fp=fp)

zsmooth = clip.zsmooth.TTempSmooth(maxr=radius, thresh=threshold, mdiff=mdiff, strength=strength, fp=fp)

match output:
    case 'zsmooth':
        zsmooth.set_output()
    case 'ttmpsm':
        ttempsmooth.set_output()
    case 'all':
        ttempsmooth.set_output(1)
        zsmooth.set_output(2)
    case _:
        raise f"Unrecognized output type: {output}"
    
