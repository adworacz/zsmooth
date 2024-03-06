Welcome to Zmooth, home of various smoothing filters for Vapoursynth written in Zig.

Goals:
1. Clean, easy to read code, with a standard scalar (non-SIMD) implementation for every algorithm.
2. SIMD (Vectors, in Zig parlance) algorithm implementations for all supported sample types and bit depths.
3. Support for 8-16 bit integer, and 16-32 bit floating point bit depths.
4. Tests for all filters.

TODO:
[x] TemporalMedian
[] TemporalSoften
[] FluxSmooth
[] MiniDeen
[] RemoveGrain?
[] Dogway's IQMST/IQMS functions?
[] Avisynth support.

Take a stance on internal value scaling. Current thinking is to scale internally, but provide a "scale" parameter to
disable internal scaling.
