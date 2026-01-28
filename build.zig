const std = @import("std");
const x86 = std.Target.x86;
const zon = @import("build.zig.zon");

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
    ensureZigVersion(try .parse(zon.minimum_zig_version)) catch return;
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const optimize_float = b.option(bool, "optimize-float", "Enables 'fast-math' optimizations for floating point arithmetic, at the expense of accuracy. Defaults to enabled/true.") orelse true;
    const options = b.addOptions();
    options.addOption(bool, "optimize_float", optimize_float);
    options.addOption(std.SemanticVersion, "version", try .parse(zon.version));

    const vapoursynth_dep = b.dependency("vapoursynth", .{
        .target = target,
        .optimize = optimize,
    });

    const root_module_options: std.Build.Module.CreateOptions = .{
        .root_source_file = b.path("src/zsmooth.zig"),
        .target = target,
        .optimize = optimize,

        // This application is single threaded (as VapourSynth handles the threading for us)
        // so might as well mark it so in case we ever import data
        // structures that *might* have thread safety built in,
        // in which case setting this value will optimize out any threading
        // or locking constructs.
        .single_threaded = true,

        .strip = optimize == .ReleaseFast,
    };
    const root_module = b.createModule(root_module_options);

    root_module.addImport("vapoursynth", vapoursynth_dep.module("vapoursynth"));
    root_module.addOptions("config", options);

    // const zsmooth_options: std.Build.SharedLibraryOptions = .{
    const lib_options: std.Build.LibraryOptions = .{
        .name = "zsmooth",
        .root_module = root_module,

        // Ensure we build a shared (*.so) library.
        .linkage = .dynamic,

        // Improve build times by giving an upper bound to memory,
        // thus enabling multi-threaded builds.
        .max_rss = 1024 * 1024 * 1024 * 2, // 2GB
    };

    const lib = b.addLibrary(lib_options);

    lib.linkLibC(); // Necessary to use the C memory allocator.

    // Add check step for quick n easy build checking without
    // emitting binary output.
    //
    // Allows ZLS to provide better inline errors.
    //
    // https://zigtools.org/zls/guides/build-on-save/
    const check = b.step("check", "Check if zsmooth compiles");
    check.dependOn(&lib.step);

    b.installArtifact(lib);

    // Release (build all platforms)
    const release = b.step("release", "Build release artifacts for all supported platforms");
    for (targets) |t| {
        // copy root module options so we can operate on them separately.
        var target_root_module_options = root_module_options;
        target_root_module_options.target = b.resolveTargetQuery(t);

        const target_root_module = b.createModule(target_root_module_options);
        target_root_module.addImport("vapoursynth", vapoursynth_dep.module("vapoursynth"));
        target_root_module.addOptions("config", options);

        // copy lib options so we can operate on them separately.
        var target_lib_options = lib_options;
        target_lib_options.root_module = target_root_module;

        const release_lib = b.addLibrary(target_lib_options);

        release_lib.linkLibC(); // Necessary to use the C memory allocator.

        const cpu_model_name = switch (t.cpu_model) {
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
        .root_module = root_module,
    });
    lib_unit_tests.linkLibC();

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn ensureZigVersion(min_zig_version: std.SemanticVersion) !void {
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
