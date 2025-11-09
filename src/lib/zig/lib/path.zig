const std = @import("std");
const builtin = @import("builtin");

const Manifest = @import("manifest.zig");

const Utils = @import("utils");
const UtilsFs = Utils.UtilsFs;

pub fn modifyPath() !void {
    const allocator = std.heap.page_allocator;

    const manifest = try Manifest.getManifest();
    defer manifest.deinit();
    const absPath = try std.fs.realpathAlloc(allocator, manifest.value.path);
    const combinedPath = try std.fmt.allocPrint(allocator, "{s}/zig.exe", .{absPath});

    if (builtin.os.tag == .windows) {
        const argv = &[4][]const u8{ "powershell.exe", "-File", "scripts/p/path.ps1", combinedPath };
        var process = std.process.Child.init(argv, allocator);
        try process.spawn();
        _ = try process.wait();
        _ = try process.kill();
    } else {
        const argv = &[6][]const u8{ "chmod", "+x", "scripts/p/path.sh", "||", "./scripts/p/path.sh", combinedPath };
        var process = std.process.Child.init(argv, allocator);
        try process.spawn();
        _ = try process.wait();
        _ = try process.kill();
    }
}
