const std = @import("std");

pub const Package = @This();

const Constants = @import("constants");
const Structs = @import("structs");

const Logger = @import("logger").logly.Logger;
const Fs = @import("io").Fs;
const Printer = @import("cli").Printer;
const Hash = @import("core").Hash;

const Context = @import("context").Context;

fn resolveVersion(
    ctx: *Context,
    package_name: []const u8,
    package_version: ?[]const u8,
) !Structs.Packages.Version {
    if (package_version) |v| {
        const lock = try ctx.manifest.readManifest(
            Structs.ZepFiles.Lock,
            Constants.Extras.package_files.lock,
        );
        defer lock.deinit();
        const id = try std.fmt.allocPrint(
            ctx.allocator,
            "{s}@{s}",
            .{ package_name, v },
        );
        defer ctx.allocator.free(id);
        for (lock.value.packages) |p| {
            if (!std.mem.eql(u8, p.name, id)) continue;
            try ctx.logger.info("Package found in .lock...", @src());
            return Structs.Packages.Version{
                .version = try ctx.allocator.dupe(u8, v),
                .url = try ctx.allocator.dupe(u8, p.source),
                .zig_version = try ctx.allocator.dupe(u8, p.zig_version),
                .root_file = try ctx.allocator.dupe(u8, p.root_file),
                .sha256sum = try ctx.allocator.dupe(u8, p.hash),
            };
        }
    }

    try ctx.logger.info("Fetching package version...", @src());
    try ctx.printer.append("Finding the package...\n", .{}, .{
        .verbosity = 3,
    });
    const parsed_package = try ctx.fetcher.fetchPackage(package_name, ctx.logger);
    defer parsed_package.deinit();
    try ctx.logger.infof("Package fetched!", .{}, @src());

    try ctx.printer.append(
        " > PACKAGE FOUND\n\n",
        .{},
        .{
            .color = .green,
            .verbosity = 2,
        },
    );

    const versions = parsed_package.value.versions;
    if (versions.len == 0) {
        try ctx.logger.err("Fetching package has no version...", @src());
        ctx.printer.append("Package has no version!\n", .{}, .{ .color = .red }) catch {};
        return error.NoPackageVersion;
    }

    try ctx.logger.infof("Getting package version!", .{}, @src());
    try ctx.printer.append(
        "Fetching package version '{s}'\n",
        .{package_version orelse "/ (using latest)"},
        .{
            .verbosity = 2,
        },
    );
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
        .version = try ctx.allocator.dupe(u8, v.version),
        .url = try ctx.allocator.dupe(u8, v.url),
        .zig_version = try ctx.allocator.dupe(u8, v.zig_version),
        .root_file = try ctx.allocator.dupe(u8, v.root_file),
        .sha256sum = try ctx.allocator.dupe(u8, v.sha256sum),
    };

    try ctx.logger.infof("Package version = {s}!", .{version.version}, @src());
    try ctx.printer.append(" > VERSION FOUND!\n\n", .{}, .{
        .color = .green,
        .verbosity = 2,
    });
    return version;
}

/// Handles Packages, returns null if package is not found.
/// Rolls back to latest version if none was specified.
/// Hashes are generated on init.
ctx: *Context,

package_name: []const u8,
package: Structs.Packages.Version,

id: []u8, // <-- package_name@package_version

pub fn init(
    ctx: *Context,
    package_name: []const u8,
    package_version: ?[]const u8,
) !Package {
    const version = try resolveVersion(
        ctx,
        package_name,
        package_version,
    );

    // Create hash
    const id = try std.fmt.allocPrint(ctx.allocator, "{s}@{s}", .{
        package_name,
        version.version,
    });

    const hash = try Hash.hashDataByUrl(
        ctx.allocator,
        version.url,
        ctx.logger,
    );
    try ctx.logger.infof("Hash found! [{s}]", .{hash}, @src());

    return Package{
        .ctx = ctx,
        .id = id,
        .package_name = package_name,
        .package = version,
    };
}

pub fn deinit(self: *Package) void {
    self.ctx.allocator.free(self.id);

    self.ctx.allocator.free(self.package.root_file);
    self.ctx.allocator.free(self.package.sha256sum);
    self.ctx.allocator.free(self.package.url);
    self.ctx.allocator.free(self.package.version);
    self.ctx.allocator.free(self.package.zig_version);
}

fn getPackagePathsAmount(
    self: *Package,
    paths: Constants.Paths.Paths,
) !usize {
    var manifest = try self.ctx.manifest.readManifest(
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
    force: bool,
) !void {
    const path = try std.fmt.allocPrint(
        self.ctx.allocator,
        "{s}/{s}",
        .{ paths.pkg_root, self.id },
    );
    defer self.ctx.allocator.free(path);

    if (!Fs.existsDir(path)) return error.NotInstalled;

    const amount = try self.getPackagePathsAmount(paths);
    if (amount > 0 and !force) {
        return error.InUse;
    }

    if (Fs.existsDir(path)) {
        try Fs.deleteTreeIfExists(path);
    }
}
