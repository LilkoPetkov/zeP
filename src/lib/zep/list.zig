const std = @import("std");

const Structs = @import("structs");
const Constants = @import("constants");

const Printer = @import("cli").Printer;
const Fs = @import("io").Fs;
const Json = @import("core").Json.Json;

/// Lists installed Zep versions
pub const ZepLister = struct {
    allocator: std.mem.Allocator,
    printer: *Printer,

    // ------------------------
    // Initialize ZepLister
    // ------------------------
    pub fn init(allocator: std.mem.Allocator, printer: *Printer) !ZepLister {
        return ZepLister{ .allocator = allocator, .printer = printer };
    }

    // ------------------------
    // Deinitialize ZepLister
    // ------------------------
    pub fn deinit(_: *ZepLister) void {
        // currently no deinit required
    }

    // ------------------------
    // Print all installed Zep versions
    // Marks the version currently in use
    // ------------------------
    pub fn listVersions(self: *ZepLister) !void {
        try self.printer.append("\nAvailable Zep Versions:\n", .{}, .{});
        var paths = try Constants.Paths.paths(self.allocator);
        defer paths.deinit();

        const versions_directory = try std.fmt.allocPrint(self.allocator, "{s}/v/", .{paths.zep_root});
        defer self.allocator.free(versions_directory);

        if (!Fs.existsDir(versions_directory)) {
            try self.printer.append("No versions installed!\n\n", .{}, .{});
            return;
        }

        if (!Fs.existsFile(paths.zep_manifest)) {
            var json = try Json.init(self.allocator);
            try json.writePretty(paths.zep_manifest, Structs.Manifests.ZepManifest{
                .version = "",
                .path = "",
            });
        }

        const manifest_target = paths.zep_manifest;
        const open_manifest = try Fs.openFile(manifest_target);
        defer open_manifest.close();

        const read_open_manifest = try open_manifest.readToEndAlloc(self.allocator, Constants.Default.mb);
        const parsed_manifest: std.json.Parsed(Structs.Manifests.ZepManifest) = try std.json.parseFromSlice(Structs.Manifests.ZepManifest, self.allocator, read_open_manifest, .{});
        defer parsed_manifest.deinit();

        const dir = try std.fs.cwd().openDir(versions_directory, std.fs.Dir.OpenOptions{ .iterate = true });
        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .directory) continue;

            const version_name = try self.allocator.dupe(u8, entry.name);
            // Mark version as in-use if it matches the manifest
            if (std.mem.containsAtLeast(u8, parsed_manifest.value.path, 1, version_name)) {
                try self.printer.append("{s} (in-use)\n", .{version_name}, .{});
            } else {
                try self.printer.append("{s}\n", .{version_name}, .{});
            }
        }

        try self.printer.append("\n", .{}, .{});
    }
};
