// MIGRATE FROM OLD zeP PATH SETTINGS TO NEW ONES
// FOR Linux
// ~/.local/zeP => ~/.zep
// ~/.local/bin/zep => ~/.zep/bin/zep
// ~/.local/bin/zig => ~/.zep/bin/zig
//
//
// FOR Windows
// C:\Users\Public\AppData\Local\zeP => C:\Users\realg\.zep
// C:\Users\...\zeP\zep\e\zep => C:\Users\realg\.zep\bin\zep
// C:\Users\...\zeP\zig\e\zig => C:\Users\realg\.zep\bin\zig
//
//
// FOR macOS
// ~/Library/Application Support/zeP => ~/.zep
// ~/Library/Application Support/bin => ~/.zep/bin
//
//
// PACKAGES
// Also move the package symlinks to the appropriate places;
// from    ./.zep/clap => C:\...\zeP\pkg\clap@0.11.0
// to      ./.zep/clap => C:\...\.zep\pkg\clap@0.11.0
//

const std = @import("std");
const builtin = @import("builtin");

const Constants = @import("constants");
const Paths = Constants.Paths;
const Structs = @import("structs");
const Context = @import("context").Context;
const Fs = @import("io").Fs;

pub fn migratePaths(ctx: *Context) !void {
    const newbase = ctx.paths.base;
    const oldbase = try Paths.oldbase(ctx.allocator);
    const new_pkg_root = ctx.paths.pkg_root;
    if (!Fs.existsDir(new_pkg_root)) {
        const old_pkg_root = try std.fs.path.join(ctx.allocator, &.{ oldbase, "pkg" });
        if (Fs.existsDir(old_pkg_root)) {
            try std.fs.cwd().rename(old_pkg_root, new_pkg_root);
        }
    }

    const new_auth_root = ctx.paths.auth_root;
    if (!Fs.existsDir(new_auth_root)) {
        const old_auth_root = try std.fs.path.join(ctx.allocator, &.{ oldbase, "auth" });
        if (Fs.existsDir(old_auth_root)) {
            try std.fs.cwd().rename(old_auth_root, new_auth_root);
        }
    }

    const new_log_root = ctx.paths.logs_root;
    if (!Fs.existsDir(new_log_root)) {
        const old_log_root = try std.fs.path.join(ctx.allocator, &.{ oldbase, "logs" });
        if (Fs.existsDir(old_log_root)) {
            try std.fs.cwd().rename(old_log_root, new_log_root);
        }
    }

    const new_prebuilt = ctx.paths.prebuilt;
    if (!Fs.existsDir(new_prebuilt)) {
        const old_prebuilt = try std.fs.path.join(ctx.allocator, &.{ oldbase, "prebuilt" });
        if (Fs.existsDir(old_prebuilt)) {
            try std.fs.cwd().rename(old_prebuilt, new_prebuilt);
        }
    }

    const new_cached = ctx.paths.cached;
    if (!Fs.existsDir(new_cached)) {
        const old_cached = try std.fs.path.join(ctx.allocator, &.{ oldbase, "cached" });
        if (Fs.existsDir(old_cached)) {
            try std.fs.cwd().rename(old_cached, new_cached);
        }
    }

    const new_custom = ctx.paths.custom;
    if (!Fs.existsDir(new_custom)) {
        const old_custom = try std.fs.path.join(ctx.allocator, &.{ oldbase, "custom" });
        if (Fs.existsDir(old_custom)) {
            try std.fs.cwd().rename(old_custom, old_custom);
        }
    }

    if (Fs.existsFile(ctx.paths.pkg_manifest)) {
        const manifest = try ctx.manifest.readManifest(
            Structs.Manifests.Packages,
            ctx.paths.pkg_manifest,
        );
        defer manifest.deinit();
        for (manifest.value.packages) |package| {
            const new_package_path = try std.fs.path.join(
                ctx.allocator,
                &.{
                    newbase,
                    "pkg",
                    package.name,
                },
            );
            if (!Fs.existsDir(new_package_path)) continue;

            const package_paths = package.paths;
            for (package_paths) |package_path| {
                if (!Fs.existsDir(package_path)) continue;
                var dir = try std.fs.cwd().openDir(package_path, .{});
                defer dir.close();
                var buf: [128]u8 = undefined;
                const symlinked = try std.fs.cwd().readLink(package_path, &buf);
                if (std.mem.eql(u8, symlinked, new_package_path)) continue;

                Fs.deleteSymlinkIfExists(package_path);
                try std.fs.symLinkAbsolute(new_package_path, package_path, .{
                    .is_directory = true,
                });
            }
        }
    }
}
