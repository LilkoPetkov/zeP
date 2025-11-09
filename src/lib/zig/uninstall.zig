const std = @import("std");

const Constants = @import("constants");

const Utils = @import("utils");
const UtilsFs = Utils.UtilsFs;
const UtilsPrinter = Utils.UtilsPrinter;

pub const ZigUninstaller = struct {
    allocator: std.mem.Allocator,
    printer: *UtilsPrinter.Printer,

    pub fn init(allocator: std.mem.Allocator, printer: *UtilsPrinter.Printer) !ZigUninstaller {
        return ZigUninstaller{
            .allocator = allocator,
            .printer = printer,
        };
    }

    pub fn deinit(self: *ZigUninstaller) void {
        _ = self;
        defer {
            // self.printer.deinit();
        }
    }

    pub fn uninstall(self: *ZigUninstaller, path: []const u8) !void {
        try self.printer.append("Deleting version..\n");

        try UtilsFs.delTree(path);
        try self.printer.append("Deleted version...\n\n");
    }
};
