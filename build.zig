const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zeP",
        .root_module = exe_mod,
    });

    const localesMod = b.createModule(.{ .root_source_file = b.path("src/locales.zig") });
    const constantsMod = b.createModule(.{ .root_source_file = b.path("src/constants/_index.zig") });
    const structsMod = b.createModule(.{ .root_source_file = b.path("src/structs/_index.zig"), .imports = &.{
        std.Build.Module.Import{ .name = "constants", .module = constantsMod },
    } });

    const iosMod = b.createModule(.{ .root_source_file = b.path("src/tools/io/_index.zig"), .imports = &.{
        std.Build.Module.Import{ .name = "constants", .module = constantsMod },
    } });
    const clisMod = b.createModule(.{ .root_source_file = b.path("src/tools/cli/_index.zig"), .imports = &.{
        std.Build.Module.Import{ .name = "structs", .module = structsMod },
        std.Build.Module.Import{ .name = "constants", .module = constantsMod },
        std.Build.Module.Import{ .name = "locales", .module = localesMod },
        std.Build.Module.Import{ .name = "io", .module = iosMod },
    } });

    const coresMod = b.createModule(.{ .root_source_file = b.path("src/tools/core/_index.zig"), .imports = &.{
        std.Build.Module.Import{ .name = "structs", .module = structsMod },
        std.Build.Module.Import{ .name = "locales", .module = localesMod },
        std.Build.Module.Import{ .name = "constants", .module = constantsMod },
        std.Build.Module.Import{ .name = "io", .module = iosMod },
        std.Build.Module.Import{ .name = "cli", .module = clisMod },
    } });

    exe.root_module.addImport("locales", localesMod);
    exe.root_module.addImport("constants", constantsMod);
    exe.root_module.addImport("structs", structsMod);
    exe.root_module.addImport("core", coresMod);
    exe.root_module.addImport("io", iosMod);
    exe.root_module.addImport("cli", clisMod);

    @import(".zep/injector.zig").injectExtraImports(b, exe);
    b.installArtifact(exe);
}
