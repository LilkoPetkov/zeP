const std = @import("std");

const Constants = @import("constants");
const Locales = @import("locales");
const Structs = @import("structs");

const Fs = @import("io").Fs;
const Printer = @import("cli").Printer;
const Hash = @import("hash.zig");
const Manifest = @import("manifest.zig");
const Json = @import("json.zig").Json;

/// Handles Packages, returns null if package is not found.
/// Rolls back to latest version if none was specified.
/// Hashes are generated on init.
pub const Package = struct {
    allocator: std.mem.Allocator,
    json: Json,

    package_hash: []u8,
    package_name: []const u8,
    package_version: []const u8,
    package: Structs.Packages.PackageVersions,

    id: []u8, // <-- package_name@package_version

    printer: *Printer,

    pub fn init(
        allocator: std.mem.Allocator,
        package_name: []const u8,
        package_version: ?[]const u8,
        printer: *Printer,
    ) !Package {
        try printer.append("\nFinding the package...\n", .{}, .{});

        // JSON context
        var json = try Json.init(allocator);

        // Load package manifest
        const parsed_package = try json.parsePackage(package_name) orelse {
            try printer.append("Package not found...\n\n", .{}, .{ .color = 31 });
            return error.PackageNotFound;
        };
        defer parsed_package.deinit();

        try printer.append("Package Found! - {s}.json\n\n", .{package_name}, .{ .color = 32 });

        const versions = parsed_package.value.versions;
        if (versions.len == 0) {
            printer.append("\nPackage has no version!\n", .{}, .{ .color = 31 }) catch {};
            return error.PackageVersion;
        }

        // Pick target version
        const target_version = package_version orelse versions[0].version;

        try printer.append("Getting the package version...\n", .{}, .{});
        try printer.append("Target Version: ", .{}, .{});

        if (package_version) |v| {
            try printer.append("{s}", .{v}, .{});
        } else {
            try printer.append("/ (no version specified, using latest)", .{}, .{});
        }
        try printer.append("\n\n", .{}, .{});

        // Find version struct
        var selected: ?Structs.Packages.PackageVersions = null;
        for (versions) |v| {
            if (std.mem.eql(u8, v.version, target_version)) {
                selected = v;
                break;
            }
        }

        if (selected == null) {
            try printer.append("Package version was not found...\n\n", .{}, .{ .color = 31 });
            return error.PackageVersion;
        }

        try printer.append("Package version found!\n\n", .{}, .{ .color = 32 });

        // Create hash
        const hash = try Hash.hashData(allocator, selected.?.url);

        // Compute id
        const id = try std.fmt.allocPrint(allocator, "{s}@{s}", .{
            package_name,
            target_version,
        });

        return Package{
            .allocator = allocator,
            .json = json,
            .package_name = package_name,
            .package_version = target_version,
            .package_hash = hash,
            .package = selected.?,
            .printer = printer,
            .id = id,
        };
    }

    pub fn deinit(_: *Package) void {}

    fn getPackageNames(self: *Package) !std.ArrayList([]const u8) {
        var paths = try Constants.Paths.paths(self.allocator);
        defer paths.deinit();

        if (!Fs.existsFile(paths.zep_manifest)) {
            var tmp = try std.fs.cwd().createFile(paths.zep_manifest, .{});
            defer tmp.close();
            try self.json.writePretty(paths.zep_manifest, Structs.Manifests.ZepManifest{
                .path = "",
                .version = "",
            });
        }

        const manifest_target = paths.zep_manifest;
        const open_manifest = try Fs.openFile(manifest_target);
        defer open_manifest.close();

        const read_open_manifest = try open_manifest.readToEndAlloc(self.allocator, Constants.Default.mb);
        const parsed_manifest = try std.json.parseFromSlice(Structs.Manifests.ZepManifest, self.allocator, read_open_manifest, .{});
        defer parsed_manifest.deinit();
        const local_path = try std.fmt.allocPrint(self.allocator, "{s}/packages/", .{parsed_manifest.value.path});
        defer self.allocator.free(local_path);

        const dir = try Fs.openDir(local_path);
        defer dir.close();

        var names = std.ArrayList([]const u8).init(self.allocator);
        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
            const name = entry.name[0 .. entry.name.len - 5];
            try names.append(try self.allocator.dupe(u8, name));
        }

        return names;
    }

    fn getCustomPackageNames(self: *Package) !std.ArrayList([]const u8) {
        var paths = try Constants.Paths.paths(self.allocator);
        defer paths.deinit();

        const dir = try Fs.openDir(paths.custom);
        defer dir.close();

        var names = std.ArrayList([]const u8).init(self.allocator);
        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
            const name = entry.name[0 .. entry.name.len - 5];
            try names.append(try self.allocator.dupe(u8, name));
        }

        return names;
    }

    pub fn findPackage(self: *Package) !?[]const u8 {
        const local_package_names = try self.getPackageNames();
        defer {
            for (local_package_names.items) |n| self.allocator.free(n);
            local_package_names.deinit();
        }
        var local_suggestions = std.ArrayList([]const u8).init(self.allocator);
        defer local_suggestions.deinit();
        for (local_package_names.items) |pn| {
            const dist = hammingDistance(pn, self.package_name);
            if (dist == 0) {
                const found = try self.allocator.dupe(u8, pn);
                return found;
            } else if (dist < 3) {
                try local_suggestions.append(pn);
            }
        }

        const custom_package_names = try self.getCustomPackageNames();
        defer {
            for (custom_package_names.items) |n| self.allocator.free(n);
            custom_package_names.deinit();
        }

        try self.printer.append(try custom_package_names.toOwnedSlice(), .{}, .{});
        var custom_suggestions = std.ArrayList([]const u8).init(self.allocator);
        defer custom_suggestions.deinit();
        for (custom_package_names.items) |pn| {
            const dist = hammingDistance(pn, self.package_name);
            if (dist == 0) {
                const found = try self.allocator.dupe(u8, pn);
                return found;
            } else if (dist < 3) {
                try custom_suggestions.append(pn);
            }
        }

        if (local_suggestions.items.len == 0 and custom_suggestions.items.len == 0) {
            try self.printer.append("(404) No package named '{s}' found.\nCheck for typos!\n", .{self.package_name}, .{});
            return null;
        }
        try self.printer.append("(404) No package named '{s}' found.\nDid you mean:\n", .{self.package_name}, .{});
        for (local_suggestions.items) |s| {
            try self.printer.append("- {s} (local)\n", .{s}, .{});
        }
        try self.printer.append("\n", .{}, .{});
        for (custom_suggestions.items) |s| {
            try self.printer.append("- {s} (custom)\n", .{s}, .{});
        }
        try self.printer.append("\n", .{}, .{});

        return null;
    }

    fn getPackagePathsAmount(self: *Package) !usize {
        var paths = try Constants.Paths.paths(self.allocator);
        defer paths.deinit();

        var package_manifest = try Manifest.readManifest(Structs.Manifests.PackagesManifest, self.allocator, paths.pkg_manifest);
        defer package_manifest.deinit();

        var package_paths_amount: usize = 0;
        for (package_manifest.value.packages) |package| {
            if (std.mem.eql(u8, package.name, self.id)) {
                package_paths_amount = package.paths.len;
                break;
            }
            continue;
        }

        return package_paths_amount;
    }

    pub fn deletePackage(self: *Package, force: bool) !void {
        var paths = try Constants.Paths.paths(self.allocator);
        defer paths.deinit();
        const path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ paths.pkg_root, self.id });
        defer self.allocator.free(path);

        const amount = try self.getPackagePathsAmount();
        if (amount > 0 and !force) {
            try self.printer.append("\nWARNING: Atleast 1 project is using {s} [{d}]. Uninstalling it globally now might have serious consequences.\n\n", .{ self.id, amount }, .{ .color = 31 });
            try self.printer.append("Use - if you do not care\n $ zep fglobal-uninstall [target]@[version]\n\n", .{}, .{ .color = 33 });
            return;
        }

        if (Fs.existsDir(path)) {
            try Fs.deleteTreeIfExists(path);
        }
    }
};

fn absDiff(x: usize, y: usize) usize {
    return @as(usize, @abs(@as(i64, @intCast(x)) - @as(i64, @intCast(y))));
}

fn hammingDistance(s1: []const u8, s2: []const u8) usize {
    const min_len = if (s1.len < s2.len) s1.len else s2.len;
    var dist = absDiff(s1.len, s2.len);
    var i: usize = 0;
    while (i < min_len) : (i += 1) {
        if (s1[i] != s2[i]) dist += 1;
    }
    return dist;
}
