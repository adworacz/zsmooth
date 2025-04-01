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

zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-gnu.2.17 -Dcpu=x86_64_v3
cp zig-out/lib/libzsmooth.so build/libzsmooth.x86_64-gnu.so

zig build -Doptimize=ReleaseFast -Dtarget=aarch64-linux-gnu.2.17
cp zig-out/lib/libzsmooth.so build/libzsmooth.aarch64-gnu.so

zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-musl -Dcpu=x86_64_v3
cp zig-out/lib/libzsmooth.so build/libzsmooth.x86_64-musl.so

zig build -Doptimize=ReleaseFast -Dtarget=aarch64-linux-musl
cp zig-out/lib/libzsmooth.so build/libzsmooth.aarch64-musl.so

pushd build
zip -9 zsmooth.avx2.dll.zip zsmooth.avx2.dll
zip -9 zsmooth.znver4.dll.zip zsmooth.znver4.dll
zip -9 libzsmooth.x86_64.dylib.zip libzsmooth.x86_64.dylib
zip -9 libzsmooth.aarch64.dylib.zip libzsmooth.aarch64.dylib
zip -9 libzsmooth.x86_64-gnu.so.zip libzsmooth.x86_64-gnu.so
zip -9 libzsmooth.aarch64-gnu.so.zip libzsmooth.aarch64-gnu.so
zip -9 libzsmooth.x86_64-musl.so.zip libzsmooth.x86_64-musl.so
zip -9 libzsmooth.aarch64-musl.so.zip libzsmooth.aarch64-musl.so

sha256sum *zsmooth* > zsmooth_checksums.sha256
popd
