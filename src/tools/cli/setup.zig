const std = @import("std");
const builtin = @import("builtin");

const Constants = @import("constants");

const Fs = @import("io").Fs;
const Printer = @import("printer.zig").Printer;

/// Runs on install.
/// Sets up basic folders for faster
/// usage.
pub fn setup(allocator: std.mem.Allocator, printer: *Printer) !void {
    var paths = try Constants.Paths.paths(allocator);
    defer paths.deinit();

    const create_paths = [5][]const u8{
        paths.root,
        paths.zep_root,
        paths.zepped,
        paths.pkg_root,
        paths.zig_root,
    };
    for (create_paths) |p| {
        _ = Fs.openOrCreateDir(p) catch |err| {
            switch (err) {
                error.AccessDenied => {
                    try printer.append("Creating {s} Failed! (Admin Privelege required)\n", .{p}, .{});
                    return;
                },
                else => return,
            }
        };
    }
}
