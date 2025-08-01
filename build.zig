const std = @import("std");
const x86 = std.Target.x86;

pub const min_zig_version = std.SemanticVersion{ .major = 0, .minor = 14, .patch = 0 };

const targets = [_]std.Target.Query{
    .{ .os_tag = .macos, .cpu_arch = .aarch64 },
    .{ .os_tag = .macos, .cpu_arch = .x86_64 },
    .{ .os_tag = .linux, .cpu_arch = .aarch64, .abi = .gnu },
    .{ .os_tag = .linux, .cpu_arch = .aarch64, .abi = .musl },
    .{ .os_tag = .linux, .cpu_arch = .x86_64, .cpu_model = std.Target.Query.CpuModel{ .explicit = &x86.cpu.x86_64_v3 }, .abi = .gnu },
    .{ .os_tag = .linux, .cpu_arch = .x86_64, .cpu_model = std.Target.Query.CpuModel{ .explicit = &x86.cpu.x86_64_v3 }, .abi = .musl },
    .{ .os_tag = .linux, .cpu_arch = .x86_64, .cpu_model = std.Target.Query.CpuModel{ .explicit = &x86.cpu.znver4 }, .abi = .gnu },
    .{ .os_tag = .linux, .cpu_arch = .x86_64, .cpu_model = std.Target.Query.CpuModel{ .explicit = &x86.cpu.znver4 }, .abi = .musl },
    .{ .os_tag = .windows, .cpu_arch = .x86_64, .cpu_model = std.Target.Query.CpuModel{ .explicit = &x86.cpu.x86_64_v3 } },
    .{ .os_tag = .windows, .cpu_arch = .x86_64, .cpu_model = std.Target.Query.CpuModel{ .explicit = &x86.cpu.znver4 } },
};

pub fn build(b: *std.Build) !void {
    ensureZigVersion() catch return;
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const optimize_float = b.option(bool, "optimize-float", "Enables 'fast-math' optimizations for floating point arithmetic, at the expense of accuracy. Defaults to enabled/true.") orelse true;
    const options = b.addOptions();
    options.addOption(bool, "optimize_float", optimize_float);

    const vapoursynth_dep = b.dependency("vapoursynth", .{
        .target = target,
        .optimize = optimize,
    });

    const zsmooth_options: std.Build.SharedLibraryOptions = .{
        .name = "zsmooth",
        .root_source_file = b.path("src/zsmooth.zig"),
        .target = target,
        .optimize = optimize,

        // Improve build times by giving an upper bound to memory,
        // thus enabling multi-threaded builds.
        .max_rss = 1024 * 1024 * 1024 * 2, // 2GB

        // This application is single threaded (as VapourSynth handles the threading for us)
        // so might as well mark it so in case we ever import data
        // structures that *might* have thread safety built in,
        // in which case setting this value will optimize out any threading
        // or locking constructs.
        .single_threaded = true,
    };

    const lib = b.addSharedLibrary(zsmooth_options);

    lib.root_module.addImport("vapoursynth", vapoursynth_dep.module("vapoursynth"));
    lib.root_module.addOptions("config", options);
    lib.root_module.strip = lib.root_module.optimize == .ReleaseFast; //Strip debug symbols in ReleaseFast.
    lib.linkLibC(); // Necessary to use the C memory allocator.

    b.installArtifact(lib);

    // Release (build all platforms)
    const release = b.step("release", "Build release artifacts for all supported platforms");
    for (targets) |t| {
        var opts = zsmooth_options;
        opts.target = b.resolveTargetQuery(t);
        const release_lib = b.addSharedLibrary(opts);

        release_lib.root_module.addImport("vapoursynth", vapoursynth_dep.module("vapoursynth"));
        release_lib.root_module.addOptions("config", options);
        release_lib.root_module.strip = release_lib.root_module.optimize == .ReleaseFast;
        release_lib.linkLibC(); // Necessary to use the C memory allocator.

        const cpu_model_name = switch(t.cpu_model){
            .baseline => "baseline",
            .determined_by_arch_os => "default",
            .native => "native",
            .explicit => t.cpu_model.explicit.name,
        };
        const output_dir = try std.fmt.allocPrint(b.allocator, "{s}-{s}", .{ try t.zigTriple(b.allocator), cpu_model_name });

        const target_output = b.addInstallArtifact(release_lib, .{
            .dest_dir = .{ //
                .override = .{ //
                    .custom = output_dir,
                },
            },
        });

        release.dependOn(&target_output.step);
    }

    // Test setup
    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/zsmooth.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_unit_tests.root_module.addImport("vapoursynth", vapoursynth_dep.module("vapoursynth"));
    lib_unit_tests.root_module.addOptions("config", options);
    lib_unit_tests.linkLibC();

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn ensureZigVersion() !void {
    var installed_ver = @import("builtin").zig_version;
    installed_ver.build = null;

    if (installed_ver.order(min_zig_version) == .lt) {
        std.log.err("\n" ++
            \\---------------------------------------------------------------------------
            \\
            \\Installed Zig compiler version is too old.
            \\
            \\Min. required version: {any}
            \\Installed version: {any}
            \\
            \\Please install newer version and try again.
            \\Latest version can be found here: https://ziglang.org/download/
            \\
            \\---------------------------------------------------------------------------
            \\
        , .{ min_zig_version, installed_ver });
        return error.ZigIsTooOld;
    }
}
