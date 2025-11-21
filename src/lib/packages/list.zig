const std = @import("std");

const Locales = @import("locales");
const Constants = @import("constants");
const Structs = @import("structs");

const Utils = @import("utils");
const UtilsJson = Utils.UtilsJson;
const UtilsFs = Utils.UtilsFs;
const UtilsCompression = Utils.UtilsCompression;
const UtilsInjector = Utils.UtilsInjector;
const UtilsPackage = Utils.UtilsPackage;
const UtilsPrinter = Utils.UtilsPrinter;
const UtilsManifest = Utils.UtilsManifest;

const CachePackage = @import("lib/cachePackage.zig");
const DownloadPackage = @import("lib/downloadPackage.zig");
const Init = @import("init.zig");
const Uninstaller = @import("uninstall.zig");

pub const Lister = struct {
    allocator: std.mem.Allocator,
    json: UtilsJson.Json,
    printer: *UtilsPrinter.Printer,
    packageName: []const u8,

    pub fn init(allocator: std.mem.Allocator, printer: *UtilsPrinter.Printer, packageName: []const u8) anyerror!Lister {
        const json = try UtilsJson.Json.init(allocator);

        return Lister{ .json = json, .allocator = allocator, .printer = printer, .packageName = packageName };
    }

    pub fn list(self: *Lister) !void {
        // Load package manifest
        const parsedPkg = try self.json.parsePackage(self.packageName);
        if (parsedPkg == null) {
            try self.printer.append("Package not found...\n\n", .{}, .{ .color = 31 });
            return;
        }
        defer parsedPkg.?.deinit();

        try self.printer.append("Package Found! - {s}.json\n\n", .{self.packageName}, .{ .color = 32 });

        const versions = parsedPkg.?.value.versions;
        try self.printer.append("Available versions:\n", .{}, .{});
        if (versions.len == 0) {
            try self.printer.append("  NO VERSIONS FOUND!\n\n", .{}, .{ .color = 31 });
        } else {
            for (versions) |v| {
                try self.printer.append("  > version: {s} (zig: {s})\n", .{ v.version, v.zigVersion }, .{});
            }
        }

        return;
    }
};
