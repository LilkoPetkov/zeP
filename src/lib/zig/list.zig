const std = @import("std");

const Structs = @import("structs");
const Constants = @import("constants");

const Fs = @import("io").Fs;
const Printer = @import("cli").Printer;
const Manifest = @import("core").Manifest;

/// Lists installed Zig versions
pub const ZigLister = struct {
    allocator: std.mem.Allocator,
    printer: *Printer,

    // ------------------------
    // Initialize ZigLister
    // ------------------------
    pub fn init(allocator: std.mem.Allocator, printer: *Printer) !ZigLister {
        return ZigLister{ .allocator = allocator, .printer = printer };
    }

    // ------------------------
    // Deinitialize ZigLister
    // ------------------------
    pub fn deinit(_: *ZigLister) void {
        // currently no deinit required
    }

    // ------------------------
    // Print all installed Zig versions
    // Marks the version currently in use
    // ------------------------
    pub fn listVersions(self: *ZigLister) !void {
        try self.printer.append("\nAvailable Zig Versions:\n", .{}, .{});
        var paths = try Constants.Paths.paths(self.allocator);
        defer paths.deinit();

        const versions_directory = try std.fmt.allocPrint(self.allocator, "{s}/d/", .{paths.zig_root});
        defer self.allocator.free(versions_directory);

        if (!Fs.existsDir(versions_directory)) {
            try self.printer.append("No versions installed!\n\n", .{}, .{});
            return;
        }

        const manifest = try Manifest.readManifest(Structs.Manifests.ZigManifest, self.allocator, paths.zig_manifest);
        defer manifest.deinit();
        if (manifest.value.path.len == 0) {
            std.debug.print("\nManifest path is not defined! Use\n $ zep zig switch <zig-version>\nTo fix!\n", .{});
            std.process.exit(0);
            return;
        }

        var dir = try Fs.openDir(versions_directory);
        defer dir.close();
        var it = dir.iterate();

        while (try it.next()) |entry| {
            if (entry.kind != .directory) continue;

            const version_name = try self.allocator.dupe(u8, entry.name);
            const version_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ versions_directory, version_name });
            defer self.allocator.free(version_path);

            var version_directory = try Fs.openDir(version_path);
            defer version_directory.close();

            const in_use_version = std.mem.containsAtLeast(u8, manifest.value.path, 1, version_name);
            try self.printer.append("{s}{s}\n", .{ version_name, if (in_use_version) " (in-use)" else "" }, .{});

            var version_iterator = version_directory.iterate();
            var has_targets: bool = false;

            while (try version_iterator.next()) |versionEntry| {
                has_targets = true;
                const target_name = try self.allocator.dupe(u8, versionEntry.name);
                const in_use_target = std.mem.containsAtLeast(u8, manifest.value.path, 1, target_name);
                try self.printer.append("  > {s}{s}\n", .{ target_name, if (in_use_version and in_use_target) " (in-use)" else "" }, .{});
            }

            if (!has_targets) {
                try self.printer.append("  NO TARGETS AVAILABLE\n", .{}, .{ .color = 31 });
            }
        }

        try self.printer.append("\n", .{}, .{});
    }
};
