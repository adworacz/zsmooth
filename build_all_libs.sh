#!/bin/sh
set -eu

rm -rf zig-out build

zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows -Dcpu=x86_64_v3
cp zig-out/lib/zsmooth.dll build/zsmooth.avx2.dll 

zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows -Dcpu=znver4
cp zig-out/lib/zsmooth.dll build/zsmooth.znver4.dll 

pushd build
zip -9 zsmooth.avx2.dll.zip zsmooth.avx2.dll
zip -9 zsmooth.znver4.dll.zip zsmooth.znver4.dll

sha256sum zsmooth*.dll* > zsmooth_checksums.sha256
popd
