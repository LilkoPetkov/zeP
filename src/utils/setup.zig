const std = @import("std");
const builtin = @import("builtin");

const Constants = @import("constants");
const UtilsFs = @import("fs.zig");

fn mkdir(path: []const u8) !void {
    if (try UtilsFs.checkDirExists(path)) return;
    try std.fs.cwd().makePath(path);
}

pub fn setup() !void {
    const paths = [5][]const u8{ Constants.ROOT_ZEP_FOLDER, Constants.ROOT_ZEP_CACHE_FOLDER, Constants.ROOT_ZEP_PKG_FOLDER, Constants.ROOT_ZEP_ZEPPED_FOLDER, Constants.ROOT_ZEP_ZIG_FOLDER };
    for (paths) |p| {
        try mkdir(p);
    }
}
