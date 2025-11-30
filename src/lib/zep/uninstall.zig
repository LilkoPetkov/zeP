const std = @import("std");

const Constants = @import("constants");

const Fs = @import("io").Fs;
const Printer = @import("cli").Printer;

/// Handles uninstalling Zep versions
pub const ZepUninstaller = struct {
    allocator: std.mem.Allocator,
    printer: *Printer,

    // ------------------------
    // Initialize ZepUninstaller
    // ------------------------
    pub fn init(allocator: std.mem.Allocator, printer: *Printer) !ZepUninstaller {
        return ZepUninstaller{
            .allocator = allocator,
            .printer = printer,
        };
    }

    // ------------------------
    // Deinitialize ZepUninstaller
    // ------------------------
    pub fn deinit(_: *ZepUninstaller) void {
        // currently no deinit required
    }

    // ------------------------
    // Uninstall a Zep version by deleting its folder
    // ------------------------
    pub fn uninstall(self: *ZepUninstaller, version: []const u8) !void {
        try self.printer.append("Deleting Zep version {s} now...\n", .{version}, .{});

        var paths = try Constants.Paths.paths(self.allocator);
        defer paths.deinit();

        // Recursively delete folder
        const path = try std.fmt.allocPrint(self.allocator, "{s}/v/{s}", .{ paths.zep_root, version });
        defer self.allocator.free(path);
        try Fs.deleteTreeIfExists(path);

        try self.printer.append("Zep version deleted successfully.\n\n", .{}, .{ .color = 32 });
    }
};
