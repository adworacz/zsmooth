#!/bin/sh
rm -rf zig-out
rm -f zsmooth.avx2.dll
rm -f zsmooth.avx512.dll

zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows -Dcpu=x86_64_v3
cp zig-out/lib/zsmooth.dll zsmooth.avx2.dll 

zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows -Dcpu=x86_64_v4
cp zig-out/lib/zsmooth.dll zsmooth.avx512.dll 
