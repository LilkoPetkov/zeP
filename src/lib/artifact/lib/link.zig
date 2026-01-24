const std = @import("std");
const builtin = @import("builtin");

const Constants = @import("constants");
const Structs = @import("structs");

const Fs = @import("io").Fs;

const Context = @import("context");

/// Updates the symbolic link to point to the currently active Artifact installation
pub fn updateLink(artifact_type: Structs.Extras.ArtifactType, ctx: *Context) !void {
    // Load manifest and get absolute path
    const manifest = try ctx.manifest.readManifest(
        Structs.Manifests.Artifact,
        if (artifact_type == .zig) ctx.paths.zig_manifest else ctx.paths.zep_manifest,
    );
    if (manifest.value.path.len == 0) {
        return error.ManifestNotFound;
    }

    defer manifest.deinit();

    const absolute_path = try std.fs.realpathAlloc(ctx.allocator, manifest.value.path);
    defer ctx.allocator.free(absolute_path);

    if (builtin.os.tag == .windows) {
        const exe = try std.fmt.allocPrint(
            ctx.allocator,
            "{s}.exe",
            .{
                if (artifact_type == .zig) "zig" else "zep",
            },
        );
        defer ctx.allocator.free(exe);

        const artifact_path = try std.fs.path.join(ctx.allocator, &.{ absolute_path, exe });
        defer ctx.allocator.free(artifact_path);
        if (!Fs.existsFile(artifact_path)) {
            try ctx.printer.append(
                "{s} file does not exists! {s}\n",
                .{
                    if (artifact_type == .zig) "Zig" else "Zep", artifact_path,
                },
                .{},
            );
            return error.FileNotFound;
        }

        const sym_link_path = try std.fs.path.join(
            ctx.allocator,
            &.{
                ctx.paths.bin,
                exe,
            },
        );
        defer ctx.allocator.free(sym_link_path);
        Fs.deleteFileIfExists(sym_link_path) catch {};
        Fs.deleteDirIfExists(sym_link_path) catch {};

        try std.fs.cwd().symLink(artifact_path, sym_link_path, .{ .is_directory = false });
    } else {
        if (!std.fs.has_executable_bit) return error.InvalidOS;

        var artifact_target: []const u8 = "zig";
        if (artifact_type == .zep) {
            artifact_target = "zeP";
            const check_exe_path = try std.fs.path.join(ctx.allocator, &.{ absolute_path, "zeP" });
            defer ctx.allocator.free(check_exe_path);
            if (!Fs.existsFile(check_exe_path)) {
                artifact_target = "zep";
            }
        }

        const artifact_path = try std.fs.path.join(ctx.allocator, &.{ absolute_path, artifact_target });
        defer ctx.allocator.free(artifact_path);

        if (!Fs.existsFile(artifact_path)) {
            try ctx.printer.append(
                "{s} file does not exists! {s}\n",
                .{
                    if (artifact_type == .zig) "Zig" else "Zep", artifact_path,
                },
                .{},
            );
            return error.FileNotFound;
        }

        const artifact_target_file = try Fs.openFile(artifact_path);
        defer artifact_target_file.close();
        try artifact_target_file.chmod(0o755);

        const sym_link_path = try std.fs.path.join(
            ctx.allocator,
            &.{
                ctx.paths.bin,
                if (artifact_type == .zig) "zig" else "zep",
            },
        );
        defer ctx.allocator.free(sym_link_path);

        Fs.deleteFileIfExists(sym_link_path) catch {};
        Fs.deleteDirIfExists(sym_link_path) catch {};

        try std.fs.cwd().symLink(artifact_path, sym_link_path, .{ .is_directory = false });
    }
}
