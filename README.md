<div align="center">
    <p>Brought to you by <a href="https://flawless.media">Flawless Media - Digitizing and Restoration</a></p>
</div>

# Zsmooth - cross-platform, cross-architecture video smoothing functions for Vapoursynth, written in Zig

**Goals**
* Clean, easy to read code, with a standard scalar (non-SIMD) implementation for every algorithm.
* Support for 8-16 integer, and 16-32 float bit depths. (See FP16 note below)
* Tests for all filters, covering the scalar and vector implementations.
* Support for RGB, YUV, and GRAY colorspaces (assuming an algorithm isn't designed for a specific color space).
* Support Linux, Windows, and Mac.
* Support x86_64 and aarch64 CPU architectures, with all architectures supported by the Zig compiler being possible in theory.
* (Eventually) Vapoursynth and Avisynth support. (Whenever I get the spare time and motivation.)

**Note on FP16:** FP16 support is a work in progress. All functions support it but some are much slower than they need to be.
Future Zig versions should make this easier, see [this Zig issue](https://github.com/ziglang/zig/issues/19550) for more
details.

**Note on AVX2:** AVX2 is the assumed baseline for all pre-built x86_64 binaries. AVX2 has been available since 2013, so
there's very little hardware left that doesn't support it. If there's demand for pre-AVX2 builds, please open an issue
and explain (in detail) your needs and reasoning.

## Implemented Features/Functions
Please see this [pinned issue](https://github.com/adworacz/zsmooth/issues/7) for the current list, and up vote accordingly.

## Benchmarks
See [Benchmarks](BENCHMARKS.md)

## Table of Contents
* [Function Documentation](#function-documentation)
  * [CCD](#ccd)
  * [Clense / ForwardClense / BackwardClense](#clense--forwardclense--backwardclense)
  * [DegrainMedian](#degrainmedian)
  * [FluxSmooth(S|ST)](#fluxsmoothsst)
  * [InterQuartileMean](#interquartilemean)
  * [Median](#median)
  * [RemoveGrain](#removegrain)
  * [Repair](#repair)
  * [Smart Median](#smart-median)
  * [Temporal Median](#temporal-median)
  * [Temporal Repair](#temporal-repair)
  * [Temporal Soften](#temporal-soften)
  * [TTempSmooth](#ttempsmooth)
  * [VerticalCleaner](#verticalcleaner)
* [Building](#building)
   * [Native Builds](#native-builds)
   * [Cross Compiling](#cross-compiling)
* [References](#references)

## Function Documentation
### CCD
CCD, aka Camcorder Color Denoiser, is an excellent chroma denoiser originally written by 
Sergey Stolyarevsky for VirtualDub.

It's a chroma denoiser that works great on old sources such as VHSes and DVDs.

CCD works as a convolution (weighted average) of near pixels governed by the `ref_points` and `scale` parameters.

If the Euclidean distance between the RGB values of the center pixel and a given pixel in the convolution
matrix is less than the threshold, then this pixel is considered in the average. 

After denoising, the clip should be converted back to YUV / YCoCg, and the luma channel should
be copied from the input. This plugin only denoises, it does no YUV->RGB->YUV conversion nor luma copying.

```py
core.zsmooth.CCD(clip clip, [float threshold = 4, int temporal_radius = 0, scale = auto, points=[True, True, False]])
```
| Parameter | Type | Options (Default) | Description |
| --- | --- | --- | --- |
| clip | 8-16 bit integer, 16-32 bit float, RGB | | Clip to process |
| threshold | float | 0-inf (4) | Euclidean distance threshold for including pixels in the convolution. Higher values result in more denoising. Automatically scaled to all bit depths internally. |
| temporal_radius | int | 0-10 (0) | Temporal radius of processing. Higher values result in more denoising. |
| points | bool[3] | ([True, True, False]) | Specifies whether to use the low, medium, or high reference points (or any combination), respectively, in the processing matrix. See the note on points below for more information. The default uses the low and medium, but excludes the high points. Feel free to adjust based on your source. |
| scale | float | 0-inf (auto) | Multiplier for the size of the matrix. `scale=1` corresponds with a 25x25 matrix (just like the original CCD implementation by Sergey). `scale=2` is a 50x50 matrix, and so on. The default is automatic, which calculates a multiplier based off of the source height, as the original CCD was implemented for 240p content. It's recommended to use the auto calculation and/or adjust `points` to suit your source |

#### Points
This implementation of CCD supports a configurable set of reference points in the NxN matrix (25x25 for `scale=1`).

Using a 25x25 matrix as an example, low, medium, and high reference points (roughly) correspond to a spatial radius
of 4, 8, and 12 pixels, respectively.

Graph of all the points:

x => center pixel
^ => low
' => medium
° => high
```
°     °     °     °
   '     '     '
°     ^     ^     °
   '     x     '
°     ^     ^     °
   '     '     '
°     °     °     °
```

#### Implementation Note
This implementation of CCD is heavily inspired by End-of-Eternity's and `vs-jetpack`'s corresponding 
implementations, particularly the latter. Many many thanks to those authors.

Output is identical to `vs-jetpack` in spatial only mode (`temporal_radius = 0`). Output differs from 
the current version of `vs-jetpack` when temporal processing is engaged. In my testing, Zsmooth's implementation
retains more detail the `vs-jetpack`'s, almost to the degree that it seems like `vs-jetpack`'s version has a bug.

Also note that Zsmooth's `scale` param behaves differently that `vs-jetpack`'s. `vs-jetpack`'s `scale=0` is equivalent
to Zsmooth's `scale=1`, which results in the use of the original 25x25 matrix. `vs-jetpack`'s `scale=1` is equivalent 
to Zsmooth's auto scale (or `scale=None`), which computes a scale based on the input height. `scale > 1` behaves the
same for both.

### Clense / ForwardClense / BackwardClense

Clense is a temporal median of three frames. (previous, current and next)
ForwardClense is a modified version of Clense that works on current and next 2 frames. 
BackwardClense is a modified version of Clense that works on current and previous 2 frames. 

```py
core.zsmooth.Clense(clip clip, [clip previous, clip next, int[] planes])
core.zsmooth.ForwardClense(clip clip,[ int[] planes])
core.zsmooth.BackwardClense(clip clip,[ int[] planes])
```

| Parameter | Type | Options (Default) | Description |
| --- | --- | --- | --- |
| clip | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY | | Clip to process |
| previous | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY | (main clip) | Optional alternate clip from which to retrieve previous frames |
| next | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY | (main clip) | Optional alternate clip from which to retrieve next frames |
| planes | int[] | ([0, 1, 2]) | Which planes to process. Any unfiltered planes are copied from the input clip. |

### DegrainMedian
DegrainMedian is a spatio-temporal limited median denoiser. It uses various methods to replace every pixel with one
selected from its 3x3 neighbourhood, from either the current, previous, or next frame.

The first column and the last column are simply copied from the source frame. The first row and the last row are also
copied from the source frame. If interlaced=True, then the second row and the second-to-last row are also copied from
the source frame.

```py
core.zsmooth.DegrainMedian(clip clip[, float[] limit, int[] mode, bool interlaced, bool norow, bool scalep])
```

Modes:
| Mode | Description |
| --- | --- |
| 0 | Spatial-Temporal version of RemoveGrain mode 9. Essentially a line (or edge) sensitive, limited, clipping function. Clipping parameters are calculated from the minimum difference of the current pixels spatial-temporal neighbors, in a 3x3 grid. |
| 1 | Spatial-Temporal and stronger version of RemoveGrain mode 8 |
| 2 | Spatial-Temporal version of RemoveGrain Mode 8 | 
| 3 | Spatial-Temporal version of RemoveGrain Mode 7 |
| 4 | Spatial-Temporal version of RemoveGrain Mode 6 |
| 5 | Spatial-Temporal version of RemoveGrain Mode 5 |
 
| Parameter | Type | Options (Default) | Description |
| --- | --- | --- | --- |
| clip | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY | | Clip to process |
| limit | float[] | 0 - bit depth max ([7, 7, 7]) | The maximum amount that a pixel can change. A higher limit results in more smoothing. Can be specified as an array, with values corresonding to each plane of the input clip. |
| mode | int[] | 0 - 5, inclusive ([1,1,1]) | The processing mode. 0 is the strongest, 5 is the weakest. Can be specified as an array, with values corresponding to each plane. |
| interlaced | bool | (False) | If True, the top line and the bottom line of the 3x3 neighbourhood will come from the same field as the middle line. In other words, one line will be skipped between the top line and the middle line, and between the middle line and the bottom line. This parameter should only be used when the input clip contains interlaced video. |
| norow | bool | (False) | If True, the two pixels to the left and right of the original pixel will not be used in the calculations. The corresponding pixels from the previous and next frames are still used. | 
| scalep | bool | (False) | Parameter scaling. If set to true, all threshold values will be automatically scaled from 8-bit range (0-255) to the corresponding range of the input clip's bit depth. |

### FluxSmooth(S|ST)
FluxSmoothT (**T**\ emporal) examines each pixel and compares it to the corresponding pixel
in the previous and next frames. Smoothing occurs if both the previous frame's value and the next frame's value are greater,
or if both are less than the value in the current frame. 

Smoothing is done by averaging the pixel from the current frame with the pixels from the previous and/or next frames, if they are within *temporal_threshold*.

FluxSmoothST (**S**\ patio\ **T**\ emporal) does the same as FluxSmoothT, except the pixel's eight neighbours from 
the current frame are also included in the average, if they are within *spatial_threshold*.

The first and last rows and the first and last columns are not processed by FluxSmoothST.

```py
core.zsmooth.FluxSmoothT(clip clip[, float[] temporal_threshold = 7, float[] planes = [0,1,2], bool scalep=False])
core.zsmooth.FluxSmoothST(clip clip[, float[] temporal_threshold = 7, float[] spatial_threshold = 7, float[] planes = [0,1,2], bool scalep = False])
```

| Parameter | Type | Options (Default) | Description |
| --- | --- | --- | --- |
| clip | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY | | Clip to process |
| temporal_threshold | float[] | -1 - bit depth max ([7,7,7]) | Temporal neighbour pixels within this threshold from the current pixel are included in the average. Can be specified as an array, with values corresonding to each plane of the input clip. A negative value (such as -1) indicates that the plane should not be processed and will be copied from the input clip. |
| spatial_threshold | float[] | -1 - bit depth max ([7,7,7]) | Spatial neighbour pixels within this threshold from the current pixel are included in the average. A negative value (such as -1) indicates that the plane should not be processed and will be copied from the input clip. |
| planes | int[] | ([0, 1, 2]) | Which planes to process. Any unfiltered planes are copied from the input clip. |
| scalep | bool | (False) | Parameter scaling. If set to true, all threshold values will be automatically scaled from 8-bit range (0-255) to the corresponding range of the input clip's bit depth. |

#### Tip
While FluxSmoothT only supports a temporal radius of 1 (3 frames - previous, current, and next), one can 
combine `TemporalMedian` and `TemporalSoften` to create essentially the same effect over a larger radius.

```python
# Credit to Dogway and Didee for the idea:
# https://github.com/Dogway/Avisynth-Scripts/blob/c6a837107afbf2aeffecea182d021862e9c2fc36/ExTools.avsi#L2078
# https://forum.doom9.org/showthread.php?p=1471858
def fluxSmoothT(clip, threshold, radius):
    med = clip.zsmooth.TemporalMedian(radius)
    avg = clip.zsmooth.TemporalSoften(radius, threshold)

    from vsrgtools import limit_filter, LimitFilterMode
    return limit_filter(med, clip, avg, mode=LimitFilterMode.DIFF_MIN)
```

### InterQuartileMean
Performs an [interquartile mean](https://en.wikipedia.org/wiki/Interquartile_mean) of a grid. 

Edge pixels are processed using mirror padding.

An interquartile mean is a mean (average) where the darkest 1/4 and brightest 1/4 of pixels in the grid
are thrown out, and the remaining middle values are averaged. This prevents the extremes from skewing the average,
thus making InterQuartileMean a solid option as a (fast) prefilter.

```py
core.zsmooth.InterQuartileMean(clip clip[, int[] radius = [1,1,1], int[] planes = [0,1,2]])
```

| Parameter | Type | Options (Default) | Description |
| --- | --- | --- | --- |
| clip | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY | | Clip to process |
| radius | int[] | 0-3 ([1, 1, 1]) | The spatial radius of the filter. Radius 1 is a 3x3 grid, radius 2 is a 5x5 grid, and radius 3 is a 7x7 grid. Radius 0 disables filtering for the given plane.|
| planes | int[] | ([0, 1, 2]) | Which planes to process. Any unfiltered planes are copied from the input clip. |

Credit to Dogway's ["IQM3" and "IQM5" implementations](https://github.com/Dogway/Avisynth-Scripts/blob/c6a837107afbf2aeffecea182d021862e9c2fc36/ExTools.avsi#L3437-L3575) for the original idea.

#### Tip:
IQM3 and IQM5 can be combined together to provide better edge protection by taking the best of both worlds.

The following example shows various ways to threshold IQM, as well as combine multiple results together 
and threshold on a form of variance, which generally leads to better edge retention.

```python
iqm3 = clip.zsmooth.InterQuartileMean(1)
iqm5 = clip.zsmooth.InterQuartileMean(2)

# Adding a limit filter recreates the effect of Dogway's original 'ex_median("IQM3", 8)'
ths = 8 # 8 is Dogway's original default. Note that you should update this based on your clip's bit depth
iqm3 = core.vszip.LimitFilter(iqm3, clip, dark_thr=ths, bright_thr=ths)
iqm5 = core.vszip.LimitFilter(iqm5, clip, dark_thr=ths, bright_thr=ths)

# variance threshold - default is usually fine, effects edge retention more than anything
# Lower values generally retain more edges than higher values
# Needs to be updated base on bit depth
vthr = 5
iqmv = core.std.Expr([iqm3, clip, iqm5], f'y z - abs {thr} > x z ?')
```


### Median
Replaces each pixel with the median of the surrounding 3x3, 5x5, or 7x7 grid, based on the `radius` parameter.

Edge pixels are processed using mirror padding.

```py
core.zsmooth.Median(clip clip[, int[] radius = [1,1,1], int[] planes = [0,1,2]])
```

| Parameter | Type | Options (Default) | Description |
| --- | --- | --- | --- |
| clip | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY | | Clip to process |
| radius | int[] | 0-3 ([1, 1, 1]) | The spatial radius of the filter. Radius 1 is a 3x3 grid, radius 2 is a 5x5 grid, and radius 3 is a 7x7 grid. Radius 0 disables filtering for the given plane.|
| planes | int[] | ([0, 1, 2]) | Which planes to process. Any unfiltered planes are copied from the input clip. |

#### Tip

The `Median` and `RemoveGrain` filters can be combined to create the [MinBlur](http://avisynth.nl/index.php/MinBlur)
function like so:

```python
# http://avisynth.nl/index.php/MinBlur
# http://avisynth.nl/images/MinBlur.avsi
# https://github.com/Dogway/Avisynth-Scripts/blob/master/SMDegrain/SMDegrain.avsi#L740
def minblur(clip, radius, repair_edges=False):
    match radius:
        case 1:
            gauss = clip.zsmooth.RemoveGrain(12)
        case 2:
            gauss = clip.zsmooth.RemoveGrain(12).zsmooth.RemoveGrain(20)
        case 3:
            gauss = clip.zsmooth.RemoveGrain(12).zsmooth.RemoveGrain(20).zsmooth.RemoveGrain(20)
        case _:
            raise "minblur: Only radius 1-3 supported"

    median = clip.zsmooth.Median(radius)

    from vsrgtools import limit_filter, LimitFilterMode
    limited = limit_filter(gauss, clip, median, mode=LimitFilterMode.DIFF_MIN)

    # Restore edges if desired, Dogway recommends to disable this when using minblur as a prefilter.
    if repair_edges:
        return limited.zsmooth.Repair(clip.zsmooth.RemoveGrain(17), 9)

    return limited
```

### RemoveGrain 

RemoveGrain is a spatial denoising filter.

Modes 0-24 are implemented. Different modes can be
specified for each plane. If there are fewer modes than planes, the last
mode specified will be used for the remaining planes.

**Note on differences**: 
1. Edge pixels are properly processed using a "mirror"-based algorithm. Meaning that any pixel values that are absent at
   an edge are filled in by mirroring the data from the opposite side. Other implementations simply skip (copy) edge
   pixels verbatim.
2. This plugin operates slightly differently than RGSF, the 'single precision' floating
   point Vapoursynth implementation of RemoveGrain. Specifically, RGSF isn't actually 'single precision' -
   it's double precision. Even for operations that don't benefit from increased floating point precision.
   This means that RGSF is actually significantly slower than it needs to be for some/most operations.

The implementation in this plugin properly uses single precision floating point for all modes.
This is exactly the same approach that the Avisynth version of RgTools takes. It does mean that
for some operations, the output will very sligtly differ between RGSF and this plugin, as RGSF is
technically doing higher precision (but much slower) calculations.

```py
core.zsmooth.RemoveGrain(clip clip, int[] mode)
```

Parameters:
| Parameter | Type | Options (Default) | Description |
| --- | --- | --- | --- |
| clip | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY | | Clip to process |
| mode | int | 1-24 | For a description of each mode, see the docs from the original Vapoursynth documentation here: https://github.com/vapoursynth/vs-removegrain/blob/master/docs/rgvs.rst |

### Repair
Repairs unwanted artifacts from (but not limited to) RemoveGrain.

Modes 0-24 are implemented. Different modes can be
specified for each plane. If there are fewer modes than planes, the last
mode specified will be used for the remaining planes.

**Notes on differences**: 
This implementation of Repair is different than others in 2 key ways:
1. Edge pixels are properly processed using a "mirror"-based algorithm. Meaning that any pixel values that are absent at
   an edge are filled in by mirroring the data from the opposite side. Other implementations simply skip (copy) edge
   pixels verbatim.
2. Unlike RGSF, all calculations are done in single precision floating point. See the note on `RemoveGrain` for more
   information.

```py
core.zsmooth.Repair(clip clip, clip repairclip, int[] mode)
```

Parameters:
| Parameter | Type | Options (Default) | Description |
| --- | --- | --- | --- |
| clip | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY | | Clip to process |
| repairclip | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY | | Reference clip, often is (but not required to be) the original unprocesed clip |
| mode | int | 1-24 | For a description of each mode, see the docs from the original Vapoursynth documentation here: https://github.com/vapoursynth/vs-removegrain/blob/master/docs/rgvs.rst |

### Smart Median
A smart median, thresholded based on a modified form of variance. 

What this means is that `SmartMedian` preserves edges and details much better than a normal median.

Lower values for the threshold mean that only flat surfaces are smoothed with a median, while higher
values mean that flat surfaces *and* some finer details/edges are smoothed with a median.

The threshold value applies on a curve, so the largest changes happen with lower thresholding values,
with changes ramping slower in higher thresholds.

Setting the threshold to bit depth max (or 255 in 8-bit scale / with `scalep=True`) returns a result that's 
*close* (but still less smoothed) to what's returned by `Median` for the same radius.

Edge pixels are processed using mirror padding.

Credit to Dogway for the [original idea](https://github.com/Dogway/Avisynth-Scripts/blob/c6a837107afbf2aeffecea182d021862e9c2fc36/ExTools.avsi#L4268-L4270)

```py
core.zsmooth.SmartMedian(clip clip[, int[] radius = [1,1,1], int[] threshold = [50,50,50], bool scalep = False, int[] planes = [0,1,2]])
```

| Parameter | Type | Options (Default) | Description |
| --- | --- | --- | --- |
| clip | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY | | Clip to process |
| radius | int[] | 0-3 ([1, 1, 1]) | The per-plane spatial radius of the filter. Radius 1 is a 3x3 grid, radius 2 is a 5x5 grid, and radius 3 is a 7x7 grid. Radius 0 disables filtering for the given plane.|
| threshold | int[] | 0-bit depth max, or 0-255 with `scalep=True`([50, 50, 50] for radius 1, [128, 128, 128] for radius 2+) | The variance threshold. Pixels with a variance under the threshold are smoothed, and over the threshold are returned as is.|
| scalep | bool | (False) | Parameter scaling. If set to true, all threshold values will be automatically scaled from 8-bit range (0-255) to the corresponding range of the input clip's bit depth. |
| planes | int[] | ([0, 1, 2]) | Which planes to process. Any unfiltered planes are copied from the input clip. |

### Temporal Median
TemporalMedian is a temporal denoising filter. It replaces every pixel with the median of its temporal neighbourhood.

This filter will introduce ghosting, so use with caution.

```py
core.zsmooth.TemporalMedian(clip clip[, int radius = 1, int[] planes = [0, 1, 2], bool scenechange = False])
```

| Parameter | Type | Options (Default) | Description |
| --- | --- | --- | --- |
| clip | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY | | Clip to process |
| radius | int | 1 - 10 (1) | Size of the temporal window from which to calculate the median. First and last _radius_ frames of a clip are not filtered. |
| planes | int[] | ([0, 1, 2]) | Which planes to process. Any unfiltered planes are copied from the input clip. |
| scenechange | bool | (False) | Whether to compensate for scene changes. In short, if this is set to `True`, then Temporal Median will include any frames that lie beyond a scene change when filtering the current frame. This ensures that frames from other scenes don't "pollute" the current frame. This feature requires that the input clip have the `_SceneChangePrev` and `_SceneChangeNext` properties set on all input frames.|

### Temporal Repair
**EXPERIMENTAL - MAY HAVE BUGS**

Applies **static** detail from the repair clip to the input clip.

Ranking of modes based on restoration amount (how much of repair clip is restored onto input clip), from least to most: 

```
<-- less restoration                        more restoration -->
                         2, 1, 0, 3, 4
<-- more motion/noise sensitive, less motion/noise sensitive -->
```

Put another way, the sensitivity to motion or noise in the repair clip decreases from left to right in those modes. This
means that more areas are considered 'static' and thus repaired. So much more of the repair clip shows up for mode 4
than mode 2.

Some modes are temporal only (0, 4) while other modes use a combination of spatial and temporal information (1, 2, 3). 
"Spatial" means that they additionally utilize the surrounding 8 pixels (in the current, previous, and next frames) in
all calculations.

* Mode 0 - Temporal. Restores less than Mode 3 and 4. This is the default mode.
* Mode 1 - Spatial and temporal. Restores less than Mode 0.
* Mode 2 - Spatial and temporal. Restore the least amount of static detail of all modes. Often used for restoring static
detail after a deinterlacer.
* Mode 3 - Spatial and temporal. Restores more detail than any other modes except for mode 4. Also used
post-deinterlacing, use it if you want to preserve more detail than mode 2.
* Mode 4 - Temporal. more conservative in its evaluation of motion than Mode 0, so retains more of the repair clip
except in high motion areas. Could be useful to smooth only high motion areas to improve compression.

```py
core.zsmooth.TemporalRepair(clip clip, clip repairclip, [, int[] mode = 0, int[] planes = [0, 1, 2]])
```

| Parameter | Type | Options (Default) | Description |
| --- | --- | --- | --- |
| clip       | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY |             | Clip to process                                                                                                                                             |
| repairclip | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY |             | Reference clip, often is (but not required to be) the original unprocesed clip. Static detail from this clip will be repaired/restored onto the input clip. |
| mode       | int[]                                             | 0-4 (0)     | Mode/method for restoration. See above documentation to understand how each mode relates to each other.                                                     |
| planes     | int[]                                             | ([0, 1, 2]) | Which planes to process. Any unfiltered planes are copied from the input clip.                                                                              |

### Temporal Soften

TemporalSoften averages radius * 2 + 1 frames. 
A pixel is included in the average only if the absolute difference between
it and the middle frame's corresponding pixel is less than the threshold.

If the `scenechange` parameter is `-1`, or greater than 0, TemporalSoften will not average
frames from different scenes. 

Setting `scenechange`to `-1` skips the internal invocation of SCDetect from [Misc
filters](https://github.com/vapoursynth/vs-miscfilters-obsolete) and uses the standard "_SceneChangePrev" and
"_SceneChangeNext" properties, which should be set by other scene detection filters prior to invoking TemporalSoften.

```py
core.zsmooth.TemporalSoften(clip clip[, int radius = 4, float[] threshold = [], int scenechange = 0, bool scalep=False])
```

| Parameter | Type | Options (Default) | Description |
| --- | --- | --- | --- |
| clip | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY | | Clip to process |
| radius | int | 1 - 7 (4) | Size of the temporal window. This is an upper bound. At the beginning and end of the clip, only legally accessible frames are incorporated into the radius. So if radius if 4, then on the first frame, only frames 0, 1, 2, and 3 are incorporated into the result. |
| threshold | float[] | 0 - 255 8-bit, 0 - 65535 16-bit, 0.0 - 1.0 float ([4,4,4] RGB, [4, 8, 8] YUV, [4] GRAY) | If the difference between the pixel in the current frame and any of its temporal neighbors is less than this threshold, it will be included in the mean. If the difference is greater, it will not be included in the mean.  If set to 0, the plane is copied from the source.|
| scenechange | int |  -1 - 255 (-1) | Zero (0) disables scene change detection, negative one (-1) respects any existing scene change properties ("_SceneChangePrev", "_SceneChangeNext") and does not call SCDetect from Misc filters. If greater than zero, it is calculated as a percentage internally (scenechange/255) to qualify if a frame is a scenechange or not. Currently requires the SCDetect filter from the Miscellaneous filters plugin. |
| scalep | bool | (False) | Parameter scaling. If set to true, all threshold values will be automatically scaled from 8-bit range (0-255) to the corresponding range of the input clip's bit depth. |

### TTempSmooth
TTempSmooth is a motion adaptive (it only works on stationary parts of the picture), temporal smoothing filter.

It's essentially a fancy lookup table internally, but it works by computing a set of weights based on the input
parameters, and then applying those weights based on the temporal differences of the input clip (or pfclip, if
provided).

Higher weights contribute more to the final pixel value, and lower weights contribute less.

The parameters are related to each other, with `maxr` and `strength` governing the temporal distance and temporal
weight, respectively. Frames closer to the center have a higher weight, and frames further from the center have a lower
weight.

`thresh` and `mdiff` govern the weights concerning the difference in pixel values between frames. Smaller differences
are weighted higher and larger differences are weighted lower.

Note that there are essentially two modes - a simple temporal weighted mode, and a temporal + difference weighted mode.

The former is activated when `mdiff >= threshold - 1`. This disables all difference weighting, and simply weights pixels
that have a temporal difference below `threshold` based on how far they are from the center. This is the fastest mode.

The latter is activated when `mdiff < threshold - 1`. In this mode, temporal weights *and* difference weights are
applied. So in addition to the weights applied in the previous mode, the amount that a pixel differs from the center
effects how much weight is given to it. Again, smaller differences have higher weights.

```py
core.zsmooth.TTempSmooth(vnode clip[, int maxr=3, int[] thresh=[4, 5, 5], int[] mdiff=[2, 3, 3], int strength=2, float scthresh=12.0, bint fp=True, vnode pfclip=None, int[] planes=[0, 1, 2]])
```

| Parameter | Type | Options (Default) | Description |
| --- | --- | --- | --- |
| clip     | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY |                         | Clip to process                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| radius   | int[]                                             | 1                       | The spatial radius of the filter. Currently only 1 (3x3) is supported, but future versions will include higher radii                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| maxr     | int                                               | 1-7 (3)                 | This sets the maximum temporal radius. By the way it works TTempSmooth automatically varies the radius used... this sets the maximum boundary. At 1 TTempSmooth will be (at max) including pixels from 1 frame away in the average (3 frames total will be considered counting the current frame). At 7 it would be including pixels from up to 7 frames away (15 frames total will be considered). With the way it checks motion there isn't much danger in setting this high, it's basically a quality vs. speed option. Lower settings are faster while larger values tend to create a more stable image.                                                                                                                                                        |
| thresh   | int[]                                             | ([4, 5, 5])             | (8-bit scale) Your standard thresholds for differences of pixels between frames. TTempSmooth checks 2 frame distance as well as single frame, so these can usually be set slightly higher than with most other temporal smoothers and still avoid artifacts. Valid settings are from 1 to 256. Also important is the fact that as long as `mdiff` is less than the threshold value then pixels with larger differences from the original will have less weight in the average. Thus, even with rather large thresholds pixels just under the threshold won't have much weight, helping to reduce artifacts. If a single value is specified, it will be used for all planes. If two values are given then the second value will be used for the third plane as well. |
| mdiff    | int[]                                             | ([2, 3, 3])             | (8-bit scale) Any pixels with differences less than or equal to `mdiff` will be blurred at maximum. Usually, the larger the difference to the center pixel the smaller the weight in the average. `mdiff` makes TTempSmooth treat pixels that have a difference of less than or equal to `mdiff` as though they have a difference of 0. In other words, it shifts the zero difference point outwards. Set `mdiff` to a value equal to or greater than `thresh-1` to completely disable inverse pixel difference weighting. Valid settings are from 0 to 255. If a single value is specified, it will be used for all planes. If two values are given then the second value will be used for the third plane as well.                                                |
| strength | int                                               | 1-8 (2)                 | TTempSmooth uses inverse distance weighting when deciding how much weight to give to each pixel value. The strength option lets you shift the drop off point away from the center to give a stronger smoothing effect and add weight to the outer pixels. It does for the spatial weights what `mdiff` does for the difference weights.
| scthresh | float                                             | -1.0 - 0 - 100.0 (12.0) | The standard scenechange threshold as a percentage of maximum possible change of the luma plane. A good range of values is between 8 and 15. Set `scthresh` to 0.0 to disable scenechange detection. Set `scthresh` to -1 to disable calls to `misc.SCDetect` internally and just use existing `_SceneChangePrev/Next` properties (useful for when said properties have already been set prior to calling this function).
| fp       | bool                                              | True                    | Setting `fp=True` will add any weight not given to the outer pixels back onto the center pixel when computing the final value. Setting `fp=False` will just do a normal weighted average. `fp=True` is much better for reducing artifacts in motion areas and usually produces overall better results.
| pfclip   | same format clip as `clip`                        | (none)                  | This allows you to specify a separate clip for TTempSmooth to use when calculating pixel differences. This applies to checking the motion thresholds, calculating inverse difference weights, and detecting scenechanges. Basically, the `pfclip` will be used to determine the weights in the average but the weights will be applied to the original input clip's pixel values.
| planes   | int[]                                             | ([0, 1, 2])             | Which planes to process. Any unfiltered planes are copied from the input clip.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |

Example of the impact of `strength` on the temporal weights, with the center frame being in the middle of each line:

* 1 = 0.13 0.14 0.16 0.20 0.25 0.33 0.50 1.00 0.50 0.33 0.25 0.20 0.16 0.14 0.13
* 2 = 0.14 0.16 0.20 0.25 0.33 0.50 1.00 1.00 1.00 0.50 0.33 0.25 0.20 0.16 0.14
* 3 = 0.16 0.20 0.25 0.33 0.50 1.00 1.00 1.00 1.00 1.00 0.50 0.33 0.25 0.20 0.16
* 4 = 0.20 0.25 0.33 0.50 1.00 1.00 1.00 1.00 1.00 1.00 1.00 0.50 0.33 0.25 0.20
* 5 = 0.25 0.33 0.50 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 0.50 0.33 0.25
* 6 = 0.33 0.50 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 0.50 0.33
* 7 = 0.50 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 0.50
* 8 = 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00

The values shown are for `maxr=7`, when using smaller radius values the weights outside of the range are simply dropped. Thus, setting `strength` to a value of `maxr+1` or higher will give you equal spatial weighting of all pixels in the kernel.

### VerticalCleaner

VerticalCleaner is a fast vertical median filter.

Different modes can be specified for each plane. If there are fewer modes
than planes, the last mode specified will be used for the remaining planes.

**Mode 0**
   The input plane is simply passed through.

**Mode 1**
   Vertical median.

**Mode 2**
   Relaxed vertical median (preserves more detail).

Let b1, b2, c, t1, t2 be a vertical sequence of pixels. The center pixel c is
to be modified in terms of the 4 neighbours. For simplicity let us assume
that b2 <= t1. Then in mode 1, c is clipped with respect to b2 and t1, i.e. c
is replaced by max(b2, min(c, t1)). In mode 2 the clipping intervall is
widened, i.e. mode 2 is more conservative than mode 1. If b2 > b1 and t1 > t2,
then c is replaced by max(b2, min(c, max(t1,d1))), where d1 = min(b2 + (b2 -
b1), t1 + (t1 - t2)). In other words, only if the gradient towards the center
is positive on both clipping ends, then the upper clipping bound may be
larger. If b2 < b1 and t1 < t2, then c is replaced by max(min(b2, d2), min(c,
t1)), where d2 = max(b2 - (b1 - b2), t1 - (t2 - t1)). In other words, only if
the gradient towards the center is negative on both clipping ends, then the
lower clipping bound may be smaller.

In mode 1 the top and the bottom line are always left unchanged. In mode 2
the two first and the two last lines are always left unchanged.

```py
core.zsmooth.VerticalCleaner(clip clip, int[] mode)
```

Parameters:
| Parameter | Type | Options (Default) | Description |
| --- | --- | --- | --- |
| clip | 8-16 bit integer, 16-32 bit float, RGB, YUV, GRAY | | Clip to process |
| mode | int | 0-2 | Mode 0 is passthrough, Mode 1 is a vertical median, Mode 2 is a relaxed vertical median that preserves more detail |


## Building
All build artifacts are placed under `zig-out/lib`.

### Native builds
To build for the operating system and architecture of the current machine:

```sh
zig build -Doptimize=ReleaseFast
```

### Cross-compiling
Zig has excellent cross-compilation support, letting us create Windows, Mac, or Linux compatible libraries from any of
those same operating systems and architectures.

To generate Windows compatible DLLs, with AVX2 support:

```sh
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows -Dcpu=x86_64_v3
```

To generate Windows compatible DLLs with AVX512 support:

```sh
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows -Dcpu=x86_64_v4
# or the following for specific targeting of AMD Zen4 CPUs
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows -Dcpu=znver4
```

See https://en.wikipedia.org/wiki/AVX-512#CPUs_with_AVX-512 for a better breakdown on which CPUs support AVX512
features.

To generate Mac (x86_64) compatible libraries:

```sh
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-macos
```

To generate Mac (aarch64) ARM compatible libraries:

```sh
zig build -Doptimize=ReleaseFast -Dtarget=aarch64-macos 
```

To generate Mac (aarch64) ARM compatible libraries for a specific CPU (like M1, M2, etc):

```sh
zig build -Doptimize=ReleaseFast -Dtarget=aarch64-macos -Dcpu=apple_m1
```

Use `zig targets` to see an exhaustive list of all architectures, CPUs, and operating systems that Zig supports.

## References
The following open source software provided great inspiration and guidance, and this plugin wouldn't exist
without the hard work of their authors.

* Avisynth RemoveGrain: https://github.com/pinterf/RgTools
* Vapoursynth RemoveGrain: https://github.com/vapoursynth/vs-removegrain
* Vapoursynth TemporalSoften: https://github.com/dubhater/vapoursynth-temporalsoften2
* Vapoursynth TemporalMedian: https://github.com/dubhater/vapoursynth-temporalmedian
* Neo Temporal Median: https://github.com/HomeOfAviSynthPlusEvolution/neo_TMedian
* Vapoursynth FluxSmooth: https://github.com/dubhater/vapoursynth-fluxsmooth/
* Dogway's `ex_median` functions: https://github.com/Dogway/Avisynth-Scripts/blob/c6a837107afbf2aeffecea182d021862e9c2fc36/ExTools.avsi#L2456
* End-of-Eternity's CCD implementation: https://github.com/End-of-Eternity/vs-ccd
* `vs-jetpack`'s CCD implementation: https://github.com/Jaded-Encoding-Thaumaturgy/vs-jetpack/blob/e0f47d86930150fd0bf92b0845ccc2b0491f7807/vsdenoise/ccd.py#L95

## 1.0 Release TODO
Things to do for the 1.0 release

1. Set `scalep=True` for all filters, since that's what everyone wants to use 99% of the time.

