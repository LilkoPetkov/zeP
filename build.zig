const __zepinj__ = @import(".zep/injector.zig");
const std = @import("std");

fn addCFilesFromDir(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    dir_path: []const u8,
) void {
    var dir = std.fs.cwd().openDir(dir_path, .{
        .iterate = true,
    }) catch unreachable;
    defer dir.close();

    var it = dir.iterate();
    while (it.next() catch unreachable) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".c")) continue;

        const full = b.pathJoin(&.{ dir_path, entry.name });
        lib.addCSourceFile(
            .{
                .file = .{ .cwd_relative = full },
                .flags = &.{"-DZSTD_DISABLE_ASM"},
            },
        );
    }
}

pub fn build(builder: *std.Build) void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});
    const zep_executeable_module = builder.createModule(.{
        .root_source_file = builder.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    __zepinj__.imp(builder, zep_executeable_module);

    const zep_executeable = builder.addExecutable(.{
        .name = "zep",
        .root_module = zep_executeable_module,
    });

    const locales_mod = builder.createModule(.{ .root_source_file = builder.path("src/locales.zig") });
    const constants_mod = builder.createModule(.{ .root_source_file = builder.path("src/constants/_index.zig") });

    const loggers_mod = builder.createModule(.{ .root_source_file = builder.path("src/logger.zig") });
    __zepinj__.imp(builder, loggers_mod);
    loggers_mod.addImport("constants", constants_mod);

    const structs_mod = builder.createModule(.{ .root_source_file = builder.path("src/structs/_index.zig") });
    structs_mod.addImport("constants", constants_mod);

    const ios_mod = builder.createModule(.{ .root_source_file = builder.path("src/tools/io/_index.zig") });
    const clis_mod = builder.createModule(.{ .root_source_file = builder.path("src/tools/cli/_index.zig") });
    clis_mod.addImport("io", ios_mod);
    clis_mod.addImport("constants", constants_mod);
    clis_mod.addImport("locales", locales_mod);

    const cores_mod = builder.createModule(.{ .root_source_file = builder.path("src/tools/core/_index.zig") });
    cores_mod.addImport("io", ios_mod);
    cores_mod.addImport("cli", clis_mod);
    cores_mod.addImport("constants", constants_mod);
    cores_mod.addImport("locales", locales_mod);
    cores_mod.addImport("structs", structs_mod);

    cores_mod.addIncludePath(.{
        .cwd_relative = "c/zstd/lib",
    });

    const args_mod = builder.createModule(.{ .root_source_file = builder.path("src/args.zig") });
    __zepinj__.imp(builder, args_mod);

    const context_mod = builder.createModule(.{ .root_source_file = builder.path("src/context.zig") });
    context_mod.addImport("constants", constants_mod);
    context_mod.addImport("cli", clis_mod);
    context_mod.addImport("core", cores_mod);
    context_mod.addImport("logger", loggers_mod);

    const zstd = builder.addLibrary(.{
        .name = "zstd",
        .root_module = builder.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    zstd.addIncludePath(.{
        .cwd_relative = "c/zstd/lib",
    });

    addCFilesFromDir(builder, zstd, "c/zstd/lib/common");
    addCFilesFromDir(builder, zstd, "c/zstd/lib/compress");
    addCFilesFromDir(builder, zstd, "c/zstd/lib/decompress");

    zstd.linkLibC();
    cores_mod.linkLibrary(zstd);
    zep_executeable.linkLibrary(zstd);
    zep_executeable.linkLibC();

    zep_executeable.root_module.addImport("locales", locales_mod);
    zep_executeable.root_module.addImport("constants", constants_mod);
    zep_executeable.root_module.addImport("structs", structs_mod);
    zep_executeable.root_module.addImport("core", cores_mod);
    zep_executeable.root_module.addImport("io", ios_mod);
    zep_executeable.root_module.addImport("cli", clis_mod);
    zep_executeable.root_module.addImport("logger", loggers_mod);
    zep_executeable.root_module.addImport("context", context_mod);
    zep_executeable.root_module.addImport("args", args_mod);

    builder.installArtifact(zep_executeable);
}
