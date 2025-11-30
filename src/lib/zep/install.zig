const std = @import("std");
const builtin = @import("builtin");

const Constants = @import("constants");

const Printer = @import("cli").Printer;

/// Installer for Zep versions
pub const ZepInstaller = struct {
    allocator: std.mem.Allocator,
    printer: *Printer,

    // ------------------------
    // Initialize ZepInstaller
    // ------------------------
    pub fn init(
        allocator: std.mem.Allocator,
        printer: *Printer,
    ) !ZepInstaller {
        return ZepInstaller{
            .allocator = allocator,
            .printer = printer,
        };
    }

    // ------------------------
    // Deinitialize
    // ------------------------
    pub fn deinit(_: *ZepInstaller) void {
        // currently no deinit required
    }

    // ------------------------
    // Public install function
    // ------------------------
    pub fn install(self: *ZepInstaller, version: []const u8) !void {
        _ = version;
        try self.printer.append("\nNot properly configured yet!\n", .{}, .{ .color = 31 });
        return;
    }
};
