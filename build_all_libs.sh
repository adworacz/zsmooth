#!/bin/sh
set -eu

rm -rf zig-out build

mkdir build

# Build all platforms in parallel
zig build release --release=fast

# Windows
zip -9 -j build/zsmooth-x86_64-windows.zip zig-out/x86_64-windows-x86_64_v3/zsmooth.dll
zip -9 -j build/zsmooth-x86_64-windows-znver4.zip zig-out/x86_64-windows-znver4/zsmooth.dll

# Mac
zip -9 -j build/zsmooth-x86_64-macos.zip zig-out/x86_64-macos-default/libzsmooth.dylib
zip -9 -j build/zsmooth-aarch64-macos.zip zig-out/aarch64-macos-default/libzsmooth.dylib

# Linux GNU
zip -9 -j build/zsmooth-x86_64-linux-gnu.zip zig-out/x86_64-linux-gnu-x86_64_v3/libzsmooth.so
zip -9 -j build/zsmooth-x86_64-linux-gnu-znver4.zip zig-out/x86_64-linux-gnu-znver4//libzsmooth.so
zip -9 -j build/zsmooth-aarch64-linux-gnu.zip zig-out/aarch64-linux-gnu-default/libzsmooth.so


# Linux Musl
zip -9 -j build/zsmooth-x86_64-linux-musl.zip zig-out/x86_64-linux-musl-x86_64_v3/libzsmooth.so
zip -9 -j build/zsmooth-x86_64-linux-musl-znver4.zip zig-out/x86_64-linux-musl-znver4/libzsmooth.so
zip -9 -j build/zsmooth-aarch64-linux-musl.zip zig-out/aarch64-linux-musl-default/libzsmooth.so

pushd build

sha256sum *zsmooth* > zsmooth_checksums.sha256
popd
