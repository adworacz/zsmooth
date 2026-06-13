#!/bin/sh
set -eu

rm -rf zig-out build

mkdir build

# Build all platforms in parallel
zig build release -Doptimize=ReleaseFast

# Windows
zip -9 -j build/zsmooth-x86_64-windows.zip zig-out/x86_64-windows-haswell/zsmooth.dll
zip -9 -j build/zsmooth-x86_64-windows-znver4.zip zig-out/x86_64-windows-znver4/zsmooth.dll

# Mac
zip -9 -j build/zsmooth-x86_64-macos.zip zig-out/x86_64-macos-default/libzsmooth.dylib
zip -9 -j build/zsmooth-aarch64-macos.zip zig-out/aarch64-macos-default/libzsmooth.dylib

# Linux GNU
zip -9 -j build/zsmooth-x86_64-linux-gnu.zip zig-out/x86_64-linux-gnu.2.17-haswell/libzsmooth.so
zip -9 -j build/zsmooth-x86_64-linux-gnu-znver4.zip zig-out/x86_64-linux-gnu.2.17-znver4//libzsmooth.so
zip -9 -j build/zsmooth-aarch64-linux-gnu.zip zig-out/aarch64-linux-gnu.2.17-default/libzsmooth.so


# Linux Musl
zip -9 -j build/zsmooth-x86_64-linux-musl.zip zig-out/x86_64-linux-musl-haswell/libzsmooth.so
zip -9 -j build/zsmooth-x86_64-linux-musl-znver4.zip zig-out/x86_64-linux-musl-znver4/libzsmooth.so
zip -9 -j build/zsmooth-aarch64-linux-musl.zip zig-out/aarch64-linux-musl-default/libzsmooth.so

pushd build

sha256sum *zsmooth* > zsmooth_checksums.sha256
popd

# Build all of the wheels in parallel
ZSTARGET=aarch64-linux-gnu python -m build &
ZSTARGET=aarch64-linux-musl python -m build &
ZSTARGET=x86_64-linux-gnu python -m build &
ZSTARGET=x86_64-linux-musl python -m build &
ZSTARGET=aarch64-macos python -m build &
ZSTARGET=x86_64-macos python -m build &
ZSTARGET=x86_64-windows python -m build &

# Wait for the jobs to complete
wait

# Dedicated sdist build to ensure we get a clean/unclobbered sdist (since the above builds race)
rm -rf dist
python -m build --sdist
