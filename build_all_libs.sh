#!/bin/sh
set -eu

rm -rf zig-out build

mkdir build

zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows -Dcpu=x86_64_v3
zip -9 -j build/zsmooth-x86_64-windows.zip zig-out/lib/zsmooth.dll 

zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows -Dcpu=znver4
zip -9 -j build/zsmooth-znver4-x86_64-windows.zip zig-out/lib/zsmooth.dll 

zig build -Doptimize=ReleaseFast -Dtarget=x86_64-macos
zip -9 -j build/zsmooth-x86_64-macos.zip zig-out/lib/libzsmooth.dylib

zig build -Doptimize=ReleaseFast -Dtarget=aarch64-macos
zip -9 -j build/zsmooth-aarch64-macos.zip zig-out/lib/libzsmooth.dylib

zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-gnu.2.17 -Dcpu=x86_64_v3
zip -9 -j build/zsmooth-x86_64-linux-gnu.zip zig-out/lib/libzsmooth.so

zig build -Doptimize=ReleaseFast -Dtarget=aarch64-linux-gnu.2.17
zip -9 -j build/zsmooth-aarch64-linux-gnu.zip zig-out/lib/libzsmooth.so

zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-musl -Dcpu=x86_64_v3
zip -9 -j build/zsmooth-x86_64-linux-musl.zip zig-out/lib/libzsmooth.so

zig build -Doptimize=ReleaseFast -Dtarget=aarch64-linux-musl
zip -9 -j build/zsmooth-aarch64-linux-musl.zip zig-out/lib/libzsmooth.so

pushd build

sha256sum *zsmooth* > zsmooth_checksums.sha256
popd
