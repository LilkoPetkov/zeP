const std = @import("std");

const Constants = @import("constants");
const Fs = @import("io").Fs;
const Printer = @import("cli").Printer;

/// Handles uninstalling Zig versions
pub const ZigUninstaller = struct {
    allocator: std.mem.Allocator,
    printer: *Printer,

    // ------------------------
    // Initialize ZigUninstaller
    // ------------------------
    pub fn init(allocator: std.mem.Allocator, printer: *Printer) !ZigUninstaller {
        return ZigUninstaller{
            .allocator = allocator,
            .printer = printer,
        };
    }

    // ------------------------
    // Deinitialize ZigUninstaller
    // ------------------------
    pub fn deinit(_: *ZigUninstaller) void {
        // currently no deinit required
    }

    // ------------------------
    // Uninstall a Zig version by deleting its folder
    // ------------------------
    pub fn uninstall(self: *ZigUninstaller, path: []const u8) !void {
        try self.printer.append("Deleting Zig version at path: {s}\n", .{path}, .{});

        // Recursively delete folder
        try Fs.deleteTreeIfExists(path);
        try self.printer.append("Zig version deleted successfully.\n\n", .{}, .{ .color = 32 });
    }
};
