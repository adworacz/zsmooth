#!/usr/bin/env bun
import { exit } from 'node:process'
import { parseArgs } from 'node:util'

const { values: cliArgs } = parseArgs({
  options: {
    filter: {
      type: "string",
      multiple: true,
    },
    format: {
      type: "string",
      multiple: true,
    },
    "frame-count-scale": {
      type: "string",
      default: "1.0"
    },
    plugin: {
      type: "string",
      multiple: true,
    },
    "exclude-plugin": {
      type: "string",
      multiple: true
    }
  }
})

const DEFAULT_NUM_FRAMES = Math.round(2000 * Number.parseFloat(cliArgs['frame-count-scale']))
const ITERATIONS = 3

type Benchmarks = {
  filter: string
  specs: {
    plugin: string
    format: 'u8' | 'u16' | 'f16' | 'f32'
    args: string[]
    frames: number
  }[]
  benchmarkPath: string
}

type Results = {
  filter: string
  plugin: string
  format: 'u8' | 'u16' | 'f16' | 'f32'
  args: string
  min: number
  max: number
  median: number
  average: number
  stdDev: number
}


const BENCHMARKS: Benchmarks[] = [
  {
    filter: 'TemporalMedian',
    benchmarkPath: 'test_temporal_median.vpy',
    // Notes:
    // * neo_tmedian is significantly slower, so reducing it's frame count to not significantly slow down testing.
    // * both tmedian and neo_tmedian are significantly slower on radius 10 (zsmooth has vectorized sorting networks instead), so also reducing their frame counts.
    //
    // biome-ignore format:
    specs: [
      { plugin: 'zsmooth'     , format:'u8'  , args: ['radius=1']  , frames: DEFAULT_NUM_FRAMES          , } ,
      { plugin: 'tmedian'     , format:'u8'  , args: ['radius=1']  , frames: DEFAULT_NUM_FRAMES          , } ,
      { plugin: 'neo_tmedian' , format:'u8'  , args: ['radius=1']  , frames: DEFAULT_NUM_FRAMES / 4      , } ,
      { plugin: 'zsmooth'     , format:'u8'  , args: ['radius=10'] , frames: DEFAULT_NUM_FRAMES          , } ,
      { plugin: 'tmedian'     , format:'u8'  , args: ['radius=10'] , frames: DEFAULT_NUM_FRAMES / 30     , } ,
      { plugin: 'neo_tmedian' , format:'u8'  , args: ['radius=10'] , frames: DEFAULT_NUM_FRAMES / 30     , } ,

      { plugin: 'zsmooth'     , format:'u16' , args: ['radius=1']  , frames: DEFAULT_NUM_FRAMES / 2      , } ,
      { plugin: 'tmedian'     , format:'u16' , args: ['radius=1']  , frames: DEFAULT_NUM_FRAMES / 2      , } ,
      { plugin: 'neo_tmedian' , format:'u16' , args: ['radius=1']  , frames: DEFAULT_NUM_FRAMES / 2 / 4  , } ,
      { plugin: 'zsmooth'     , format:'u16' , args: ['radius=10'] , frames: DEFAULT_NUM_FRAMES / 2      , } ,
      { plugin: 'tmedian'     , format:'u16' , args: ['radius=10'] , frames: DEFAULT_NUM_FRAMES / 2 / 30 , } ,
      { plugin: 'neo_tmedian' , format:'u16' , args: ['radius=10'] , frames: DEFAULT_NUM_FRAMES / 2 / 30 , } ,

      { plugin: 'zsmooth'     , format:'f32' , args: ['radius=1']  , frames: DEFAULT_NUM_FRAMES / 4      , } ,
      { plugin: 'tmedian'     , format:'f32' , args: ['radius=1']  , frames: DEFAULT_NUM_FRAMES / 4      , } ,
      { plugin: 'neo_tmedian' , format:'f32' , args: ['radius=1']  , frames: DEFAULT_NUM_FRAMES / 4 / 4  , } ,
      { plugin: 'zsmooth'     , format:'f32' , args: ['radius=10'] , frames: DEFAULT_NUM_FRAMES / 4      , } ,
      { plugin: 'tmedian'     , format:'f32' , args: ['radius=10'] , frames: DEFAULT_NUM_FRAMES / 4 / 30 , } ,
      { plugin: 'neo_tmedian' , format:'f32' , args: ['radius=10'] , frames: DEFAULT_NUM_FRAMES / 4 / 30 , } ,
    ],
  },
  {
    filter: 'TemporalSoften',
    benchmarkPath: 'test_temporal_soften.vpy',
    // Notes:
    // focus2 is slower than zsmooth, so reducing frame count to not wait unnecessarily for benchmark data.
    //
    // biome-ignore format:
    specs: [
      { plugin: 'zsmooth' , format:'u8'  , args: ['radius=1'] , frames: DEFAULT_NUM_FRAMES         , } ,
      { plugin: 'focus2'  , format:'u8'  , args: ['radius=1'] , frames: DEFAULT_NUM_FRAMES         , } ,
      { plugin: 'std'     , format:'u8'  , args: ['radius=1'] , frames: DEFAULT_NUM_FRAMES         , } ,
      { plugin: 'zsmooth' , format:'u8'  , args: ['radius=7'] , frames: DEFAULT_NUM_FRAMES         , } ,
      { plugin: 'focus2'  , format:'u8'  , args: ['radius=7'] , frames: DEFAULT_NUM_FRAMES / 2     , } ,
      { plugin: 'std'     , format:'u8'  , args: ['radius=7'] , frames: DEFAULT_NUM_FRAMES / 2     , } ,

      { plugin: 'zsmooth' , format:'u16' , args: ['radius=1'] , frames: DEFAULT_NUM_FRAMES / 2     , } ,
      { plugin: 'focus2'  , format:'u16' , args: ['radius=1'] , frames: DEFAULT_NUM_FRAMES / 2     , } ,
      { plugin: 'std'     , format:'u16' , args: ['radius=1'] , frames: DEFAULT_NUM_FRAMES / 2     , } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['radius=7'] , frames: DEFAULT_NUM_FRAMES / 2     , } ,
      { plugin: 'focus2'  , format:'u16' , args: ['radius=7'] , frames: DEFAULT_NUM_FRAMES / 2 / 2 , } ,
      { plugin: 'std'     , format:'u16' , args: ['radius=7'] , frames: DEFAULT_NUM_FRAMES / 2 / 2 , } ,

      { plugin: 'zsmooth' , format:'f32' , args: ['radius=1'] , frames: DEFAULT_NUM_FRAMES / 4     , } ,
      { plugin: 'std'     , format:'f32' , args: ['radius=1'] , frames: DEFAULT_NUM_FRAMES / 4     , } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['radius=7'] , frames: DEFAULT_NUM_FRAMES / 4     , } ,
      { plugin: 'std'     , format:'f32' , args: ['radius=7'] , frames: DEFAULT_NUM_FRAMES / 4     , } ,
    ],
  },
  {
    filter: 'FluxSmooth',
    benchmarkPath: 'test_fluxsmooth.vpy',
    // biome-ignore format:
    specs: [
      { plugin: 'zsmooth' , format:'u8'  , args: ['function=FluxSmoothT']  , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'flux'    , format:'u8'  , args: ['function=FluxSmoothT']  , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'zsmooth' , format:'u8'  , args: ['function=FluxSmoothST'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'flux'    , format:'u8'  , args: ['function=FluxSmoothST'] , frames: DEFAULT_NUM_FRAMES , } ,

      { plugin: 'zsmooth' , format:'u16' , args: ['function=FluxSmoothT']  , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'flux'    , format:'u16' , args: ['function=FluxSmoothT']  , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['function=FluxSmoothST'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'flux'    , format:'u16' , args: ['function=FluxSmoothST'] , frames: DEFAULT_NUM_FRAMES / 2, } ,

      { plugin: 'zsmooth' , format:'f32' , args: ['function=FluxSmoothT']  , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['function=FluxSmoothST'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
    ],
  },
  {
    filter: 'Clense',
    benchmarkPath: 'test_clense.vpy',
    // biome-ignore format:
    specs: [
      { plugin: 'zsmooth' , format:'u8'  , args: ['function=Clense']         , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'rg'      , format:'u8'  , args: ['function=Clense']         , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'zsmooth' , format:'u8'  , args: ['function=ForwardClense']  , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'rg'      , format:'u8'  , args: ['function=ForwardClense']  , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'zsmooth' , format:'u8'  , args: ['function=BackwardClense'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'rg'      , format:'u8'  , args: ['function=BackwardClense'] , frames: DEFAULT_NUM_FRAMES , } ,

      { plugin: 'zsmooth' , format:'u16' , args: ['function=Clense']         , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'rg'      , format:'u16' , args: ['function=Clense']         , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['function=ForwardClense']  , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'rg'      , format:'u16' , args: ['function=ForwardClense']  , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['function=BackwardClense'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'rg'      , format:'u16' , args: ['function=BackwardClense'] , frames: DEFAULT_NUM_FRAMES / 2, } ,

      { plugin: 'zsmooth' , format:'f32' , args: ['function=Clense']         , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'rg'      , format:'f32' , args: ['function=Clense']         , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['function=ForwardClense']  , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'rg'      , format:'f32' , args: ['function=ForwardClense']  , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['function=BackwardClense'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'rg'      , format:'f32' , args: ['function=BackwardClense'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
    ],
  },
  {
    filter: 'VerticalCleaner',
    benchmarkPath: 'test_vertical_cleaner.vpy',
    // biome-ignore format:
    specs: [
      { plugin: 'zsmooth' , format:'u8'  , args: ['mode=1'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'rg'      , format:'u8'  , args: ['mode=1'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'zsmooth' , format:'u8'  , args: ['mode=2'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'rg'      , format:'u8'  , args: ['mode=2'] , frames: DEFAULT_NUM_FRAMES , } ,

      { plugin: 'zsmooth' , format:'u16' , args: ['mode=1'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'rg'      , format:'u16' , args: ['mode=1'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['mode=2'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'rg'      , format:'u16' , args: ['mode=2'] , frames: DEFAULT_NUM_FRAMES / 2, } ,

      { plugin: 'zsmooth' , format:'f32' , args: ['mode=1'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'rg'      , format:'f32' , args: ['mode=1'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['mode=2'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'rg'      , format:'f32' , args: ['mode=2'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
    ],
  },
  {
    filter: 'RemoveGrain',
    benchmarkPath: 'test_remove_grain.vpy',
    // biome-ignore format:
    specs: [
      { plugin: 'zsmooth' , format:'u8'  , args: ['mode=1']  , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'rg'      , format:'u8'  , args: ['mode=1']  , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'zsmooth' , format:'u8'  , args: ['mode=4']  , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'rg'      , format:'u8'  , args: ['mode=4']  , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'std'     , format:'u8'  , args: ['mode=4']  , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'zsmooth' , format:'u8'  , args: ['mode=12'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'rg'      , format:'u8'  , args: ['mode=12'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'std'     , format:'u8'  , args: ['mode=12'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'zsmooth' , format:'u8'  , args: ['mode=17'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'rg'      , format:'u8'  , args: ['mode=17'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'zsmooth' , format:'u8'  , args: ['mode=20'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'rg'      , format:'u8'  , args: ['mode=20'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'std'     , format:'u8'  , args: ['mode=20'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'zsmooth' , format:'u8'  , args: ['mode=22'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'rg'      , format:'u8'  , args: ['mode=22'] , frames: DEFAULT_NUM_FRAMES , } ,

      { plugin: 'zsmooth' , format:'u16' , args: ['mode=1']  , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'rg'      , format:'u16' , args: ['mode=1']  , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['mode=4']  , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'rg'      , format:'u16' , args: ['mode=4']  , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'std'     , format:'u16' , args: ['mode=4']  , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['mode=12'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'rg'      , format:'u16' , args: ['mode=12'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'std'     , format:'u16' , args: ['mode=12'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['mode=17'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'rg'      , format:'u16' , args: ['mode=17'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['mode=20'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'rg'      , format:'u16' , args: ['mode=20'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'std'     , format:'u16' , args: ['mode=20'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['mode=22'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'rg'      , format:'u16' , args: ['mode=22'] , frames: DEFAULT_NUM_FRAMES / 2, } ,

      { plugin: 'zsmooth' , format:'f32' , args: ['mode=1']  , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'rg'      , format:'f32' , args: ['mode=1']  , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['mode=4']  , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'rg'      , format:'f32' , args: ['mode=4']  , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'std'     , format:'f32' , args: ['mode=4']  , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['mode=12'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'rg'      , format:'f32' , args: ['mode=12'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'std'     , format:'f32' , args: ['mode=12'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['mode=17'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'rg'      , format:'f32' , args: ['mode=17'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['mode=20'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'rg'      , format:'f32' , args: ['mode=20'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'std'     , format:'f32' , args: ['mode=20'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['mode=22'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'rg'      , format:'f32' , args: ['mode=22'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
    ],
  },
  {
    filter: 'Repair',
    benchmarkPath: 'test_repair.vpy',
    // biome-ignore format:
    specs: [
      { plugin: 'zsmooth' , format:'u8'  , args: ['mode=1']  , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'rg'      , format:'u8'  , args: ['mode=1']  , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'zsmooth' , format:'u8'  , args: ['mode=12'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'rg'      , format:'u8'  , args: ['mode=12'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'zsmooth' , format:'u8'  , args: ['mode=13'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'rg'      , format:'u8'  , args: ['mode=13'] , frames: DEFAULT_NUM_FRAMES , } ,

      { plugin: 'zsmooth' , format:'u16' , args: ['mode=1']  , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'rg'      , format:'u16' , args: ['mode=1']  , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['mode=12'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'rg'      , format:'u16' , args: ['mode=12'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['mode=13'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'rg'      , format:'u16' , args: ['mode=13'] , frames: DEFAULT_NUM_FRAMES / 2, } ,

      { plugin: 'zsmooth' , format:'f32' , args: ['mode=1']  , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'rg'      , format:'f32' , args: ['mode=1']  , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['mode=12'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'rg'      , format:'f32' , args: ['mode=12'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['mode=13'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'rg'      , format:'f32' , args: ['mode=13'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
    ],
  },
  {
    filter: 'DegrainMedian',
    benchmarkPath: 'test_degrain_median.vpy',
    // biome-ignore format:
    specs: [
      { plugin: 'zsmooth' , format:'u8' , args: ['mode=0'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'dgm'     , format:'u8' , args: ['mode=0'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'zsmooth' , format:'u8' , args: ['mode=1'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'dgm'     , format:'u8' , args: ['mode=1'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'zsmooth' , format:'u8' , args: ['mode=2'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'dgm'     , format:'u8' , args: ['mode=2'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'zsmooth' , format:'u8' , args: ['mode=3'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'dgm'     , format:'u8' , args: ['mode=3'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'zsmooth' , format:'u8' , args: ['mode=4'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'dgm'     , format:'u8' , args: ['mode=4'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'zsmooth' , format:'u8' , args: ['mode=5'] , frames: DEFAULT_NUM_FRAMES , } ,
      { plugin: 'dgm'     , format:'u8' , args: ['mode=5'] , frames: DEFAULT_NUM_FRAMES , } ,

      { plugin: 'zsmooth' , format:'u16' , args: ['mode=0'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'dgm'     , format:'u16' , args: ['mode=0'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['mode=1'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'dgm'     , format:'u16' , args: ['mode=1'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['mode=2'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'dgm'     , format:'u16' , args: ['mode=2'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['mode=3'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'dgm'     , format:'u16' , args: ['mode=3'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['mode=4'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'dgm'     , format:'u16' , args: ['mode=4'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['mode=5'] , frames: DEFAULT_NUM_FRAMES / 2, } ,
      { plugin: 'dgm'     , format:'u16' , args: ['mode=5'] , frames: DEFAULT_NUM_FRAMES / 2, } ,

      { plugin: 'zsmooth' , format:'f32' , args: ['mode=0'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['mode=1'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['mode=2'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['mode=3'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['mode=4'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['mode=5'] , frames: DEFAULT_NUM_FRAMES / 4, } ,
    ],
  },
  {
    filter: 'InterQuartileMean',
    benchmarkPath: 'test_inter_quartile_mean.vpy',
    // biome-ignore format:
    specs: [
      { plugin: 'zsmooth' , format:'u8'  , args: [] , frames: DEFAULT_NUM_FRAMES     , } ,
      { plugin: 'zsmooth' , format:'u16' , args: [] , frames: DEFAULT_NUM_FRAMES / 2 , } ,
      { plugin: 'zsmooth' , format:'f32' , args: [] , frames: DEFAULT_NUM_FRAMES / 4 , } ,
    ],
  },
  {
    filter: 'TTempSmooth',
    benchmarkPath: 'test_ttempsmooth.vpy',
    // biome-ignore format:
    specs: [
      // ttempsmooth is noticeably slower than other filters, so / 4 to keep it within the same time scale.
      // the original plugin is about 3x slower, so / 3 to keep the same time scale.
      { plugin: 'zsmooth' , format:'u8'  , args: ['radius=1', 'threshold=4', 'mdiff=2'] , frames: DEFAULT_NUM_FRAMES / 4      , } ,
      { plugin: 'ttmpsm'  , format:'u8'  , args: ['radius=1', 'threshold=4', 'mdiff=2'] , frames: DEFAULT_NUM_FRAMES / 4 / 3  , } ,
      { plugin: 'zsmooth' , format:'u8'  , args: ['radius=1', 'threshold=4', 'mdiff=4'] , frames: DEFAULT_NUM_FRAMES / 4      , } ,
      { plugin: 'ttmpsm'  , format:'u8'  , args: ['radius=1', 'threshold=4', 'mdiff=4'] , frames: DEFAULT_NUM_FRAMES / 4 / 3  , } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['radius=1', 'threshold=4', 'mdiff=2'] , frames: DEFAULT_NUM_FRAMES / 4      , } ,
      { plugin: 'ttmpsm'  , format:'u16' , args: ['radius=1', 'threshold=4', 'mdiff=2'] , frames: DEFAULT_NUM_FRAMES / 4 / 3  , } ,
      { plugin: 'zsmooth' , format:'u16' , args: ['radius=1', 'threshold=4', 'mdiff=4'] , frames: DEFAULT_NUM_FRAMES / 4      , } ,
      { plugin: 'ttmpsm'  , format:'u16' , args: ['radius=1', 'threshold=4', 'mdiff=4'] , frames: DEFAULT_NUM_FRAMES / 4 / 3  , } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['radius=1', 'threshold=4', 'mdiff=2'] , frames: DEFAULT_NUM_FRAMES / 4      , } ,
      { plugin: 'ttmpsm'  , format:'f32' , args: ['radius=1', 'threshold=4', 'mdiff=2'] , frames: DEFAULT_NUM_FRAMES / 4 / 3  , } ,
      { plugin: 'zsmooth' , format:'f32' , args: ['radius=1', 'threshold=4', 'mdiff=4'] , frames: DEFAULT_NUM_FRAMES / 4      , } ,
      { plugin: 'ttmpsm'  , format:'f32' , args: ['radius=1', 'threshold=4', 'mdiff=4'] , frames: DEFAULT_NUM_FRAMES / 4 / 3  , } ,
    ],
  }
]

const benchmarksToRun = BENCHMARKS.filter((bench) => !cliArgs.filter || cliArgs.filter?.includes(bench.filter))

console.log(`Benchmarking ${benchmarksToRun.length} filters`)

const results: Results[] = []
for (const filter of benchmarksToRun) {

  const specsToRun = filter.specs
    .filter((spec) => !cliArgs.plugin || cliArgs.plugin?.includes(spec.plugin))
    .filter((spec) => !cliArgs.format || cliArgs.format.includes(spec.format))

  for (const spec of specsToRun) {
    const fpsValues: number[] = []
    const args = [`output=${spec.plugin}`, `format=${spec.format}`].concat(spec.args)
    const vspipeArgs = args.flatMap((arg) => ['-a', arg])

    for (let i = 0; i < ITERATIONS; i++) {
      const { stderr } = Bun.spawnSync(
        [
          'vspipe',
          ...vspipeArgs,
          '-e',
          Math.round(spec.frames).toString(),
          '-r',
          '1',
          filter.benchmarkPath,
          '--',
        ],
        { stderr: 'pipe' },
      )

      const fps = /(\d+\.?\d+?) fps/.exec(stderr.toString())?.[1]

      if (!fps) {
        throw new Error(`Unable to determine FPS from stderr: ${stderr}`)
      }

      fpsValues.push(Number.parseFloat(fps))
    }

    // Sort the results
    fpsValues.sort((a,b) => a - b)

    const min = fpsValues[0]
    const max = fpsValues[fpsValues.length - 1]
    const median = fpsValues[Math.trunc(fpsValues.length / 2)]
    const average =
      fpsValues.reduce((prev, curr) => prev + curr) / fpsValues.length

    // https://en.wikipedia.org/wiki/Standard_deviation
    const differences_squared = fpsValues.map((fps) => (fps - average) * (fps - average))
    const variance = differences_squared.reduce((prev, curr) => prev + curr) / fpsValues.length
    const std_deviation = Math.sqrt(variance)

    const stringifiedArgs = spec.args.join(' ')

    console.log(
      `${filter.filter} ${spec.plugin} ${spec.format} [${stringifiedArgs}] Min: ${min}, Max: ${max}, Median: ${median}, Average: ${average}, StdDev: ${std_deviation}`,
    )
    results.push({
      filter: filter.filter,
      plugin: spec.plugin,
      format: spec.format,
      args: stringifiedArgs,
      min,
      max,
      median,
      average,
      stdDev: std_deviation,
    })
  }
}

if (results.length === 0) {
  exit()
}

console.table(results)

const headers = [
  'Filter',
  'Plugin',
  'Format',
  'Args',
  'Min',
  'Max',
  'Median',
  'Average',
  'Standard Deviation',
]

const csvHeaders = headers.join(',')
const csvEntries = results.reduce(
  (accum, result) =>
    `${accum}"${result.filter}", "${result.plugin}", "${result.format}", "${result.args}", ${result.min}, ${result.max}, ${result.median}, ${result.average}, ${result.stdDev}\n`,
  '',
)

const markdownHeaders = `| ${headers.join(' | ')} |`
const markdownTableSeperator = `| ${headers.map(() => ':---: |').join(' ')}`
const markdownEntries = results.reduce(
  (accum, result) =>
    `${accum}| ${result.filter} | ${result.plugin} | ${result.format} | ${result.args} | ${result.min} | ${result.max} | ${result.median} | ${result.average} | ${result.stdDev} |\n`,
  '',
)


const benchmarkResultsCsvFilename = 'benchmark_results.csv'
const benchmarkResultsMarkdownFilename = 'benchmark_results.md'

console.log(`Writing resuls to ${benchmarkResultsCsvFilename}`)
Bun.write(benchmarkResultsCsvFilename, `${csvHeaders}\n${csvEntries}`)

console.log(`Writing resuls to ${benchmarkResultsMarkdownFilename}`)
Bun.write(benchmarkResultsMarkdownFilename, `${markdownHeaders}\n${markdownTableSeperator}\n${markdownEntries}`)
