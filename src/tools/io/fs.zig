const std = @import("std");

/// validates if a File exists
/// => Errors will return false
pub fn existsFile(path: []const u8) bool {
    const cwd = std.fs.cwd();
    var f = cwd.openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return false,
    };
    defer f.close();
    return true;
}

/// validates if a Dir exists
/// => Errors will return false
pub fn existsDir(path: []const u8) bool {
    const cwd = std.fs.cwd();
    var d = cwd.openDir(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return false,
    };
    defer d.close();
    return true;
}

/// Checks if a File exists
/// and creates it if it
/// does not [THE WHOLE PATH]
/// return -rw
pub fn openOrCreateFile(path: []const u8) !std.fs.File {
    if (!existsFile(path)) {
        const parent = std.fs.path.dirname(path) orelse "";
        try std.fs.cwd().makePath(parent);
        return try std.fs.cwd().createFile(path, std.fs.File.CreateFlags{ .read = true });
    }
    return try std.fs.cwd().openFile(path, std.fs.File.OpenFlags{ .mode = .read_write });
}

/// Checks if a File exists
/// and creates it if it
/// does not [NO PATH]
/// return -rw
pub fn openFile(path: []const u8) !std.fs.File {
    if (!existsFile(path)) {
        return try std.fs.cwd().createFile(path, std.fs.File.CreateFlags{ .read = true });
    }
    return try std.fs.cwd().openFile(path, std.fs.File.OpenFlags{ .mode = .read_write });
}

/// Checks if a Dir exists
/// and creates it if it
/// does not [THE WHOLE PATH]
/// return -rw
pub fn openOrCreateDir(path: []const u8) !std.fs.Dir {
    if (!existsDir(path)) {
        try std.fs.cwd().makePath(path);
    }
    return try std.fs.cwd().openDir(path, std.fs.Dir.OpenOptions{ .iterate = true });
}

/// Checks if a Dir exists
/// and creates it if it
/// does not [NO PATH]
/// return -rw
pub fn openDir(path: []const u8) !std.fs.Dir {
    if (!existsDir(path)) {
        try std.fs.cwd().makeDir(path);
    }
    return try std.fs.cwd().openDir(path, std.fs.Dir.OpenOptions{ .iterate = true });
}

/// Deletes file if it exists
pub fn deleteFileIfExists(path: []const u8) !void {
    if (existsFile(path))
        try std.fs.cwd().deleteFile(path);
}

/// Deletes dir [no tree] if it exists
pub fn deleteDirIfExists(path: []const u8) !void {
    if (existsDir(path))
        try std.fs.cwd().deleteDir(path);
}

/// Deletes tree if it exists
pub fn deleteTreeIfExists(path: []const u8) !void {
    if (existsDir(path))
        try std.fs.cwd().deleteTree(path);
}
