const std = @import("std");
const Logger = @import("logger");

/// validates if a File exists
/// => Errors will return false
pub fn existsFile(path: []const u8) bool {
    const cwd = std.fs.cwd();
    var f = cwd.openFile(path, .{}) catch return false;
    defer f.close();
    return true;
}

/// validates if a Dir exists
/// => Errors will return false
pub fn existsDir(path: []const u8) bool {
    const cwd = std.fs.cwd();
    var d = cwd.openDir(path, .{}) catch return false;
    defer d.close();
    return true;
}

/// Checks if a File exists and creates it if it does not [THE WHOLE PATH]
pub fn openOrCreateFile(path: []const u8) !std.fs.File {
    if (!existsFile(path)) {
        const parent = std.fs.path.dirname(path) orelse "";
        if (parent.len > 0) try std.fs.cwd().makePath(parent);
        const f = try std.fs.cwd().createFile(path, std.fs.File.CreateFlags{ .read = true });
        return f;
    }
    const f = try std.fs.cwd().openFile(path, std.fs.File.OpenFlags{ .mode = .read_write });
    return f;
}

/// Checks if a File exists and creates it if it does not [NO PATH]
pub fn openFile(path: []const u8) !std.fs.File {
    if (!existsFile(path)) {
        const f = try std.fs.cwd().createFile(path, std.fs.File.CreateFlags{ .read = true });
        return f;
    }
    const f = try std.fs.cwd().openFile(path, std.fs.File.OpenFlags{ .mode = .read_write });
    return f;
}

/// Checks if a File exists and creates it if it does not [NO PATH]
pub fn fileTruncate(path: []const u8) !std.fs.File {
    const f = try std.fs.cwd().createFile(path, std.fs.File.CreateFlags{ .read = true, .truncate = true });
    return f;
}

/// Checks if a Dir exists and creates it if it does not [THE WHOLE PATH]
pub fn openOrCreateDir(path: []const u8) !std.fs.Dir {
    if (!existsDir(path)) {
        try std.fs.cwd().makePath(path);
    }
    const d = try std.fs.cwd().openDir(path, std.fs.Dir.OpenOptions{ .iterate = true });
    return d;
}

/// Checks if a Dir exists and creates it if it does not [NO PATH]
pub fn openDir(path: []const u8) !std.fs.Dir {
    if (!existsDir(path)) {
        try std.fs.cwd().makeDir(path);
    }
    const d = try std.fs.cwd().openDir(path, std.fs.Dir.OpenOptions{ .iterate = true });
    return d;
}

/// Deletes file if it exists
pub fn deleteFileIfExists(path: []const u8) !void {
    if (existsFile(path)) {
        try std.fs.cwd().deleteFile(path);
    }
}

/// Deletes dir [no tree] if it exists
pub fn deleteDirIfExists(path: []const u8) !void {
    if (existsDir(path)) {
        try std.fs.cwd().deleteDir(path);
    }
}

/// Deletes tree if it exists
pub fn deleteTreeIfExists(path: []const u8) !void {
    if (existsDir(path)) {
        try std.fs.cwd().deleteTree(path);
    }
}

/// Deletes symlink if it exists
pub fn deleteSymlinkIfExists(path: []const u8) void {
    _ = std.fs.cwd().access(path, .{}) catch {
        std.fs.cwd().deleteDir(path) catch {};
        std.fs.cwd().deleteFile(path) catch {};
        return;
    };
    std.fs.cwd().deleteDir(path) catch {};
    std.fs.cwd().deleteFile(path) catch {};
}
