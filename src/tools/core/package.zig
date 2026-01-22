const std = @import("std");

pub const Package = @This();

const Constants = @import("constants");
const Structs = @import("structs");

const Logger = @import("logger").logly.Logger;
const Fs = @import("io").Fs;
const Printer = @import("cli").Printer;
const Manifest = @import("manifest.zig");
const Hash = @import("hash.zig");
const Json = @import("json.zig");
const Fetch = @import("fetch.zig");

fn resolveVersion(
    allocator: std.mem.Allocator,
    package_name: []const u8,
    package_version: ?[]const u8,
    fetcher: *Fetch,
    printer: *Printer,
    logger: *Logger,
) !Structs.Packages.Version {
    try logger.info("Fetching package version...", @src());
    try printer.append("Finding the package...\n", .{}, .{});
    const parsed_package = try fetcher.fetchPackage(package_name, logger);
    defer parsed_package.deinit();
    try logger.infof("Package fetched!", .{}, @src());

    try printer.append(
        "Package Found! - {s}\n",
        .{package_name},
        .{ .color = .green },
    );

    const versions = parsed_package.value.versions;
    if (versions.len == 0) {
        try logger.err("Fetching package has no version...", @src());
        printer.append("Package has no version!\n", .{}, .{ .color = .red }) catch {};
        return error.NoPackageVersion;
    }

    try logger.infof("Getting package version!", .{}, @src());
    try printer.append("Getting the package version...\n", .{}, .{});
    try printer.append("Target Version: {s}\n\n", .{package_version orelse "/ (using latest)"}, .{});
    const target_version = package_version orelse versions[0].version;
    var check_selected: ?Structs.Packages.Version = null;
    for (versions) |v| {
        if (std.mem.eql(u8, v.version, target_version)) {
            check_selected = v;
            break;
        }
    }

    const v = check_selected orelse return error.NotFound;
    const version = Structs.Packages.Version{
        .version = try allocator.dupe(u8, v.version),
        .url = try allocator.dupe(u8, v.url),
        .zig_version = try allocator.dupe(u8, v.zig_version),
        .root_file = try allocator.dupe(u8, v.root_file),
        .sha256sum = try allocator.dupe(u8, v.sha256sum),
    };

    try logger.infof("Package version = {s}!", .{version.version}, @src());
    try printer.append("Package version found!\n", .{}, .{ .color = .green });
    return version;
}

/// Handles Packages, returns null if package is not found.
/// Rolls back to latest version if none was specified.
/// Hashes are generated on init.
allocator: std.mem.Allocator,
printer: *Printer,

package_name: []const u8,
package: Structs.Packages.Version,

id: []u8, // <-- package_name@package_version

pub fn init(
    allocator: std.mem.Allocator,
    printer: *Printer,
    fetcher: *Fetch,
    logger: *Logger,
    package_name: []const u8,
    package_version: ?[]const u8,
) !Package {
    const version = try resolveVersion(
        allocator,
        package_name,
        package_version,
        fetcher,
        printer,
        logger,
    );

    // Create hash
    const id = try std.fmt.allocPrint(allocator, "{s}@{s}", .{
        package_name,
        version.version,
    });

    const hash = try Hash.hashDataByUrl(
        allocator,
        version.url,
        logger,
    );
    try logger.infof("Hash found! [{s}]", .{hash}, @src());

    return Package{
        .allocator = allocator,
        .package_name = package_name,
        .package = version,
        .printer = printer,
        .id = id,
    };
}

pub fn deinit(self: *Package) void {
    self.allocator.free(self.id);

    self.allocator.free(self.package.root_file);
    self.allocator.free(self.package.sha256sum);
    self.allocator.free(self.package.url);
    self.allocator.free(self.package.version);
    self.allocator.free(self.package.zig_version);
}

fn getPackagePathsAmount(
    self: *Package,
    paths: Constants.Paths.Paths,
    _manifest: *Manifest,
) !usize {
    var manifest = try _manifest.readManifest(
        Structs.Manifests.Packages,
        paths.pkg_manifest,
    );
    defer manifest.deinit();

    var package_paths_amount: usize = 0;
    for (manifest.value.packages) |package| {
        if (std.mem.eql(u8, package.name, self.id)) {
            package_paths_amount = package.paths.len;
            break;
        }
    }

    return package_paths_amount;
}

pub fn deletePackage(
    self: *Package,
    paths: Constants.Paths.Paths,
    manifest: *Manifest,
    force: bool,
) !void {
    const path = try std.fmt.allocPrint(
        self.allocator,
        "{s}/{s}",
        .{ paths.pkg_root, self.id },
    );
    defer self.allocator.free(path);

    if (!Fs.existsDir(path)) return error.NotInstalled;

    const amount = try self.getPackagePathsAmount(paths, manifest);
    if (amount > 0 and !force) {
        return error.InUse;
    }

    if (Fs.existsDir(path)) {
        try Fs.deleteTreeIfExists(path);
    }
}
