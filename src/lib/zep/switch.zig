const std = @import("std");
const Link = @import("lib/link.zig");

const Structs = @import("structs");
const Constants = @import("constants");
const Utils = @import("utils");
const UtilsPrinter = Utils.UtilsPrinter;
const UtilsFs = Utils.UtilsFs;
const UtilsManifest = Utils.UtilsManifest;

/// Handles switching between installed Zep versions
pub const ZepSwitcher = struct {
    allocator: std.mem.Allocator,
    printer: *UtilsPrinter.Printer,

    // ------------------------
    // Initialize ZepSwitcher
    // ------------------------
    pub fn init(allocator: std.mem.Allocator, printer: *UtilsPrinter.Printer) !ZepSwitcher {
        return ZepSwitcher{ .allocator = allocator, .printer = printer };
    }

    // ------------------------
    // Deinitialize ZepSwitcher
    // ------------------------
    pub fn deinit(_: *ZepSwitcher) void {
        // currently no deinit required
    }

    // ------------------------
    // Switch active Zep version
    // Updates manifest and system PATH
    // ------------------------
    pub fn switchVersion(self: *ZepSwitcher, version: []const u8) !void {
        // Update manifest with new version
        try self.printer.append("Modifying Manifest...\n", .{}, .{});

        const path = try std.fmt.allocPrint(self.allocator, "{s}/v/{s}/", .{ Constants.ROOT_ZEP_ZEP_FOLDER, version });
        try UtilsManifest.writeManifest(
            Structs.ZepManifest,
            self.allocator,
            Constants.ROOT_ZEP_ZEP_MANIFEST,
            Structs.ZepManifest{
                .version = version,
                .path = path,
            },
        );

        self.printer.pop(1); // Remove temporary log
        try self.printer.append("Manifest up to date!\n", .{}, .{ .color = 32 });

        // Update system PATH to point to new version
        try self.printer.append("Switching to installed version...\n", .{}, .{});
        try Link.updateLink();
        self.printer.pop(1); // Remove temporary log
        try self.printer.append("Switched to installed version successfully!\n", .{}, .{ .color = 32 });
    }
};
