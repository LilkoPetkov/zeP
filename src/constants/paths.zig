const std = @import("std");
const builtin = @import("builtin");

pub fn oldbase(allocator: std.mem.Allocator) ![]const u8 {
    var base: []const u8 = undefined;
    if (builtin.os.tag == .windows) {
        base = "C:\\Users\\Public\\AppData\\Local\\zeP";
    } else if (builtin.os.tag == .linux) {
        const home = std.posix.getenv("HOME") orelse return error.MissingHome;
        base = try std.fs.path.join(allocator, &.{ home, ".local", "zeP" });
    } else if (builtin.os.tag == .macos) {
        const home = std.posix.getenv("HOME") orelse return error.MissingHome;
        base = try std.fs.path.join(allocator, &.{ home, "Library", "Application Support", "zeP" });
    } else {
        const home = std.posix.getenv("HOME") orelse return error.MissingHome;
        base = home;
    }

    return base;
}

pub fn oldbinaries(allocator: std.mem.Allocator) ![]const u8 {
    var binaries: []const u8 = undefined;
    if (builtin.os.tag == .windows) {
        binaries = "C:\\Users\\Public\\AppData\\Local\\zeP";
    } else {
        const home = std.posix.getenv("HOME") orelse return error.MissingHome;
        binaries = try std.fs.path.join(allocator, &.{ home, ".local", "bin" });
    }

    return binaries;
}

/// Returns absolute paths of specific
/// operating system.
pub fn paths(allocator: std.mem.Allocator) !Paths {
    var base: []const u8 = undefined;

    if (builtin.os.tag == .windows) {
        var env_map = try std.process.getEnvMap(allocator);
        defer env_map.deinit();

        const home = env_map.get("HOMEPATH") orelse return error.MissingHome;
        const chome = try std.fmt.allocPrint(allocator, "C:{s}", .{home});
        base = try std.fs.path.join(allocator, &.{ chome, ".zep" });
    } else {
        const home = std.posix.getenv("HOME") orelse return error.MissingHome;
        base = try std.fs.path.join(allocator, &.{ home, ".zep" });
    }

    return .{
        .allocator = allocator,
        .base = base,
        .bin = try std.fs.path.join(allocator, &.{ base, "bin" }),
        .prebuilt = try std.fs.path.join(allocator, &.{ base, "prebuilt" }),
        .custom = try std.fs.path.join(allocator, &.{ base, "custom" }),

        .cached = try std.fs.path.join(allocator, &.{ base, "cached" }),
        .pkg_cached = try std.fs.path.join(allocator, &.{ base, "cached", "pkg" }),
        .meta_cached = try std.fs.path.join(allocator, &.{ base, "cached", "metadata" }),

        .pkg_root = try std.fs.path.join(allocator, &.{ base, "pkg" }),
        .zig_root = try std.fs.path.join(allocator, &.{ base, "zig" }),
        .zep_root = try std.fs.path.join(allocator, &.{ base, "zep" }),
        .auth_root = try std.fs.path.join(allocator, &.{ base, "auth" }),
        .logs_root = try std.fs.path.join(allocator, &.{ base, "logs" }),

        .pkg_manifest = try std.fs.path.join(allocator, &.{ base, "pkg", "manifest.json" }),
        .zig_manifest = try std.fs.path.join(allocator, &.{ base, "zig", "manifest.json" }),
        .zep_manifest = try std.fs.path.join(allocator, &.{ base, "zep", "manifest.json" }),
        .auth_manifest = try std.fs.path.join(allocator, &.{ base, "auth", "manifest.json" }),
    };
}

pub const Paths = struct {
    allocator: std.mem.Allocator,

    base: []const u8,
    bin: []const u8,
    prebuilt: []const u8,
    custom: []const u8,
    cached: []const u8,

    pkg_cached: []const u8,
    meta_cached: []const u8,

    pkg_root: []const u8,
    zig_root: []const u8,
    zep_root: []const u8,
    logs_root: []const u8,
    auth_root: []const u8,

    pkg_manifest: []const u8,
    zig_manifest: []const u8,
    zep_manifest: []const u8,
    auth_manifest: []const u8,

    pub fn deinit(self: *Paths) void {
        // self.allocator.free(self.base);
        self.allocator.free(self.prebuilt);
        self.allocator.free(self.bin);
        self.allocator.free(self.custom);
        self.allocator.free(self.cached);
        self.allocator.free(self.pkg_cached);
        self.allocator.free(self.meta_cached);

        self.allocator.free(self.pkg_root);
        self.allocator.free(self.zig_root);
        self.allocator.free(self.zep_root);
        self.allocator.free(self.logs_root);
        self.allocator.free(self.auth_root);

        self.allocator.free(self.pkg_manifest);
        self.allocator.free(self.zig_manifest);
        self.allocator.free(self.zep_manifest);
        self.allocator.free(self.auth_manifest);
    }
};
