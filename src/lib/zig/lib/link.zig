const std = @import("std");
const builtin = @import("builtin");

const Constants = @import("constants");
const Structs = @import("structs");

const Fs = @import("io").Fs;
const Manifest = @import("core").Manifest;

/// Updates the symbolic link to point to the currently active Zig installation
pub fn updateLink() !void {
    var allocator = std.heap.page_allocator;
    var paths = try Constants.Paths.paths(allocator);
    defer paths.deinit();

    // Load manifest and get absolute path
    const manifest = try Manifest.readManifest(Structs.Manifests.ZigManifest, allocator, paths.zig_manifest);
    if (manifest.value.path.len == 0) {
        std.debug.print("\nManifest path is not defined! Use\n $ zep zig switch <zig-version>\nTo fix!\n", .{});
        std.process.exit(0);
        return;
    }

    defer manifest.deinit();

    const absolute_path = try std.fs.realpathAlloc(allocator, manifest.value.path);
    defer allocator.free(absolute_path);

    if (builtin.os.tag == .windows) {
        const zig_exe = try std.fmt.allocPrint(allocator, "{s}/zig.exe", .{absolute_path});
        defer allocator.free(zig_exe);
        if (!Fs.existsFile(zig_exe)) return;

        const link_exe_path_directory = try std.fmt.allocPrint(allocator, "{s}/e/", .{paths.zig_root});
        if (!Fs.existsDir(link_exe_path_directory)) {
            try std.fs.cwd().makePath(link_exe_path_directory);
        }

        const link_exe_path = try std.fmt.allocPrint(allocator, "{s}/e/zig.exe", .{paths.zig_root});
        defer allocator.free(link_exe_path);
        if (Fs.existsFile(link_exe_path)) {
            try std.fs.cwd().deleteFile(link_exe_path);
        }

        try std.fs.cwd().symLink(zig_exe, link_exe_path, .{ .is_directory = false });
    } else {
        const zig_exe = try std.fmt.allocPrint(allocator, "{s}/zig", .{absolute_path});
        defer allocator.free(zig_exe);
        if (!Fs.existsFile(zig_exe)) return;

        const zig_exe_target = try std.fs.cwd().openFile(zig_exe, .{});
        defer zig_exe_target.close();
        try zig_exe_target.chmod(755);

        const sym_link_path = try std.fs.path.join(allocator, &.{ paths.base, "bin", "zig" });
        defer allocator.free(sym_link_path);

        try std.fs.cwd().symLink(zig_exe, sym_link_path, .{ .is_directory = false });
    }
}
