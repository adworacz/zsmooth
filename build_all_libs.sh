#!/bin/sh
set -eu

rm -rf zig-out build

mkdir build

zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows -Dcpu=x86_64_v3
cp zig-out/lib/zsmooth.dll build/zsmooth.avx2.dll 

zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows -Dcpu=znver4
cp zig-out/lib/zsmooth.dll build/zsmooth.znver4.dll 

zig build -Doptimize=ReleaseFast -Dtarget=x86_64-macos
cp zig-out/lib/libzsmooth.dylib build/libzsmooth.x86_64.dylib

zig build -Doptimize=ReleaseFast -Dtarget=aarch64-macos
cp zig-out/lib/libzsmooth.dylib build/libzsmooth.aarch64.dylib

pushd build
zip -9 zsmooth.avx2.dll.zip zsmooth.avx2.dll
zip -9 zsmooth.znver4.dll.zip zsmooth.znver4.dll
zip -9 libzsmooth.x86_64.dylib.zip libzsmooth.x86_64.dylib
zip -9 libzsmooth.aarch64.dylib.zip libzsmooth.aarch64.dylib

sha256sum *zsmooth* > zsmooth_checksums.sha256
popd
