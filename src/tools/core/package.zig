const std = @import("std");

pub const Package = @This();

const Logger = @import("logger");
const Constants = @import("constants");
const Locales = @import("locales");
const Structs = @import("structs");

const Fs = @import("io").Fs;
const Printer = @import("cli").Printer;
const Manifest = @import("manifest.zig");
const Hash = @import("hash.zig");
const Json = @import("json.zig");
const Fetch = @import("fetch.zig");

fn resolveVersion(
    package_name: []const u8,
    package_version: ?[]const u8,
    fetcher: *Fetch,
    printer: *Printer,
) !Structs.Packages.PackageVersions {
    try printer.append("Finding the package...\n", .{}, .{});

    const parsed_package = try fetcher.fetchPackage(package_name);
    defer parsed_package.deinit();

    try printer.append("Package Found! - {s}\n\n", .{package_name}, .{ .color = .green });

    const versions = parsed_package.value.versions;
    if (versions.len == 0) {
        printer.append("\nPackage has no version!\n", .{}, .{ .color = .red }) catch {};
        return error.NoPackageVersion;
    }

    try printer.append("Getting the package version...\n", .{}, .{});
    try printer.append("Target Version: {s}\n\n", .{package_version orelse "/ (using latest)"}, .{});
    const target_version = package_version orelse versions[0].version;
    var check_selected: ?Structs.Packages.PackageVersions = null;
    for (versions) |v| {
        if (std.mem.eql(u8, v.version, target_version)) {
            check_selected = v;
            break;
        }
    }

    const version = check_selected orelse return error.NotFound;

    try printer.append("Package version found!\n", .{}, .{ .color = .green });
    return version;
}

/// Handles Packages, returns null if package is not found.
/// Rolls back to latest version if none was specified.
/// Hashes are generated on init.
allocator: std.mem.Allocator,
printer: *Printer,

package_hash: []const u8,
package_name: []const u8,
package_version: []const u8,
package: Structs.Packages.PackageVersions,

id: []u8, // <-- package_name@package_version

pub fn init(
    allocator: std.mem.Allocator,
    printer: *Printer,
    fetcher: *Fetch,
    package_name: []const u8,
    package_version: ?[]const u8,
) !Package {
    const version = try resolveVersion(
        package_name,
        package_version,
        fetcher,
        printer,
    );

    // Create hash
    const id = try std.fmt.allocPrint(allocator, "{s}@{s}", .{
        package_name,
        version.version,
    });

    const hash = try Hash.hashDataByUrl(allocator, version.url);

    return Package{
        .allocator = allocator,
        .package_name = package_name,
        .package_hash = hash,
        .package_version = version.version,
        .package = version,
        .printer = printer,
        .id = id,
    };
}

pub fn deinit(self: *Package) void {
    self.allocator.free(self.id);
}

fn getPackagePathsAmount(
    self: *Package,
    paths: Constants.Paths.Paths,
    _manifest: *Manifest,
) !usize {
    var manifest = try _manifest.readManifest(
        Structs.Manifests.PackagesManifest,
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
    var buf: [128]u8 = undefined;
    const path = try std.fmt.bufPrint(
        &buf,
        "{s}/{s}",
        .{ paths.pkg_root, self.id },
    );
    if (!Fs.existsDir(path)) return error.NotInstalled;

    const amount = try self.getPackagePathsAmount(paths, manifest);
    if (amount > 0 and !force) {
        return error.InUse;
    }

    if (Fs.existsDir(path)) {
        try Fs.deleteTreeIfExists(path);
    }
}
