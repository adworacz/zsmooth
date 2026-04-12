import shutil
import subprocess
from pathlib import Path
from typing import Any

from hatchling.builders.hooks.plugin.interface import BuildHookInterface
from packaging import tags
import os

targets = {
    # Linux
    'aarch64-linux-gnu': {
        'zig_target': 'aarch64-linux-gnu.2.17', 
        'python_platform_tag': 'manylinux_2_17_aarch64',
    },
    'aarch64-linux-musl': {
        'zig_target': 'aarch64-linux-musl', 
        'python_platform_tag': 'musllinux_1_2_aarch64',
    },
    'x86_64-linux-gnu': {
        'zig_target': 'x86_64-linux-gnu.2.17', 
        'python_platform_tag': 'manylinux_2_17_x86_64',
        'cpus': ['x86_64_v3']
    },
    'x86_64-linux-musl': {
        'zig_target': 'x86_64-linux-musl', 
        'python_platform_tag': 'musllinux_1_2_x86_64',
        'cpus': ['x86_64_v3']
    },

    # Mac
    'aarch64-macos': {
        'zig_target': 'aarch64-macos', 
        'python_platform_tag': 'macosx_11_0_aarch64',
    },
    'x86_64-macos': {
        'zig_target': 'x86_64-macos', 
        'python_platform_tag': 'macosx_11_0_x86_64',
    },

    # Windows
    'x86_64-windows': {
        'zig_target': 'x86_64-windows', 
        'python_platform_tag': 'win32',
        'cpus': ['x86_64_v3'],
    },
}


class CustomHook(BuildHookInterface[Any]):
    """
    Custom build hook to compile the Zig project and package the resulting binaries.
    """

    source_dir = Path("zig-out")
    target_dir = Path("vapoursynth/plugins/zsmooth")

    def initialize(self, version: str, build_data: dict[str, Any]) -> None:
        """
        Called before the build process starts.
        Sets build metadata and executes the Zig compilation.
        """
        # https://hatch.pypa.io/latest/plugins/builder/wheel/#build-data
        build_data["pure_python"] = False

        # Cross-compilation support
        if "ZSTARGET" in os.environ:
            # Ex: ZSTARGET="x86_64-linux-gnu"
            zstarget = os.environ["ZSTARGET"]

            if zstarget not in targets:
                raise ValueError(f"Unsupported target {zstarget}")

            target = targets[zstarget]
            zig_target = target['zig_target']
            python_platform_tag = target['python_platform_tag']
            cpu = target['cpus'][0] if target['cpus'] else None

            build_data["tag"] = f"py3-none-{python_platform_tag}"

            subprocess.run(["python-zig", "build", "-Doptimize=ReleaseFast", f"-Dtarget={zig_target}", f"-Dcpu={cpu}" if cpu else ""], check=True)
        # Build for *this* machine
        else:
            build_data["tag"] = f"py3-none-{next(tags.platform_tags())}"

            subprocess.run(["python-zig", "build", "-Doptimize=ReleaseFast"], check=True)

        # Ensure the target directory exists and copy the compiled binaries
        self.target_dir.mkdir(parents=True, exist_ok=True)
        for file_path in self.source_dir.rglob("*"):
            if file_path.is_file():
                shutil.copy2(file_path, self.target_dir)

        # Write a manifest to ensure instruction set-based loading works as desired
        # https://github.com/vapoursynth/vapoursynth/discussions/1196
        manifest_path = Path(self.target_dir, "manifest.vs")
        with open(manifest_path, "wt") as manifest:
            manifest.writelines([
                "[VapourSynth Manifest V1]\n"
                "libzsmooth\n"
            ])

    def finalize(self, version: str, build_data: dict[str, Any], artifact_path: str) -> None:
        """
        Called after the build process finishes.
        Cleans up temporary build artifacts.
        """
        shutil.rmtree(self.target_dir.parent, ignore_errors=True)
