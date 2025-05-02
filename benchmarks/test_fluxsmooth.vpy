import vapoursynth as vs
from vstools import depth, get_depth, get_sample_type
from vspreview.api import is_preview

core = vs.core
core.max_cache_size = 1024
core.num_threads = 1

threshold = 20
# threshold = 20 << 8
# threshold = 20 / 255.0
# format = 'u8'
# output = 'all'

if is_preview():
    output = 'all'
    function = 'FluxSmoothT'

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

if get_sample_type(clip) == vs.INTEGER:
    if function == 'FluxSmoothT':
        flux = clip.flux.SmoothT(temporal_threshold=threshold)
    else: 
        flux = clip.flux.SmoothST(temporal_threshold=threshold, spatial_threshold=threshold)

if function == 'FluxSmoothT':
    zsmooth = clip.zsmooth.FluxSmoothT(scalep=True, temporal_threshold=threshold);
else:
    zsmooth = clip.zsmooth.FluxSmoothST(scalep=True, temporal_threshold=threshold, spatial_threshold=threshold)

match output:
    case 'flux':
        flux.set_output()
    case 'zsmooth':
        zsmooth.set_output()
    case 'all':
        clip.set_output(0)
        if get_sample_type(clip) == vs.INTEGER:
            flux.set_output(1)
        zsmooth.set_output(2)
    case _:
        raise f"Unrecognized output type: {output}"

