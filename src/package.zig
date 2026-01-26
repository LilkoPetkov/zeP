const std = @import("std");

pub const Package = @This();

const Constants = @import("constants");
const Structs = @import("structs");

const Logger = @import("logger").logly.Logger;
const Fs = @import("io").Fs;
const Printer = @import("cli").Printer;
const Hash = @import("core").Hash;
const Json = @import("core").Json;

const Context = @import("context").Context;

fn resolveFromLock(
    ctx: *Context,
    package_name: []const u8,
    package_version: []const u8,
) !?Structs.ZepFiles.Package {
    const lock = try ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Default.package_files.lock,
    );
    defer lock.deinit();
    const id = try std.fmt.allocPrint(
        ctx.allocator,
        "{s}@{s}",
        .{ package_name, package_version },
    );
    defer ctx.allocator.free(id);

    for (lock.value.packages) |p| {
        if (!std.mem.eql(u8, p.name, id)) continue;
        try ctx.logger.info("Package found in .lock...", @src());

        return Structs.ZepFiles.Package{
            .name = try ctx.allocator.dupe(u8, id),
            .source = try ctx.allocator.dupe(u8, p.source),
            .zig_version = try ctx.allocator.dupe(u8, p.zig_version),
            .root_file = try ctx.allocator.dupe(u8, p.root_file),
            .hash = try ctx.allocator.dupe(u8, p.hash),
            .packages = &.{},
        };
    }

    return null;
}

fn resolveFromFetch(
    ctx: *Context,
    package_name: []const u8,
    package_version: ?[]const u8,
) !Structs.ZepFiles.Package {
    try ctx.logger.info("Fetching package version...", @src());
    try ctx.printer.append("Finding the package...\n", .{}, .{
        .verbosity = 3,
    });
    const parsed_package = try ctx.fetcher.fetchPackage(
        package_name,
        ctx.logger,
    );
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
    const id = try std.fmt.allocPrint(
        ctx.allocator,
        "{s}@{s}",
        .{ package_name, v.version },
    );
    defer ctx.allocator.free(id);

    const version = Structs.ZepFiles.Package{
        .name = try ctx.allocator.dupe(u8, id),
        .source = try ctx.allocator.dupe(u8, v.url),
        .zig_version = try ctx.allocator.dupe(u8, v.zig_version),
        .root_file = try ctx.allocator.dupe(u8, v.root_file),
        .hash = try ctx.allocator.dupe(u8, v.sha256sum),
        .packages = &.{},
    };

    return version;
}

fn resolveVersion(
    ctx: *Context,
    package_name: []const u8,
    package_version: ?[]const u8,
) !Structs.ZepFiles.Package {
    if (package_version) |v| {
        const attempt = try resolveFromLock(
            ctx,
            package_name,
            v,
        );
        if (attempt) |a| return a;
    }

    const version = try resolveFromFetch(
        ctx,
        package_name,
        package_version,
    );

    var p_split = std.mem.splitScalar(
        u8,
        version.name,
        '@',
    );
    _ = p_split.next();
    const v = p_split.next() orelse "latest";

    try ctx.logger.infof("Package version = {s}!", .{v}, @src());
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

package: Structs.ZepFiles.Package,
package_name: []const u8, // borrowed
package_version: []const u8, // borrowed

pub fn init(
    ctx: *Context,
    package_name: []const u8,
    package_version: ?[]const u8,
) !Package {
    const package = try resolveVersion(
        ctx,
        package_name,
        package_version,
    );

    var p_split = std.mem.splitScalar(u8, package.name, '@');
    _ = p_split.next();
    const version = p_split.next() orelse "latest";

    return Package{
        .ctx = ctx,
        .package_name = package_name,
        .package_version = version,
        .package = package,
    };
}

pub fn deinit(self: *Package) void {
    self.ctx.allocator.free(self.package.root_file);
    self.ctx.allocator.free(self.package.hash);
    self.ctx.allocator.free(self.package.source);
    self.ctx.allocator.free(self.package.name);
    self.ctx.allocator.free(self.package.zig_version);
}

fn registeredPathCount(self: *Package) !usize {
    var manifest = try self.ctx.manifest.readManifest(
        Structs.Manifests.Packages,
        self.ctx.paths.pkg_manifest,
    );
    defer manifest.deinit();

    var package_paths_amount: usize = 0;
    for (manifest.value.packages) |package| {
        if (std.mem.eql(u8, package.name, self.package.name)) {
            package_paths_amount = package.paths.len;
            break;
        }
    }

    return package_paths_amount;
}

pub fn uninstallFromDisk(
    self: *Package,
    force: bool,
) !void {
    const path = try std.fmt.allocPrint(
        self.ctx.allocator,
        "{s}/{s}",
        .{ self.ctx.paths.pkg_root, self.package.name },
    );
    defer self.ctx.allocator.free(path);

    if (!Fs.existsDir(path)) return error.NotInstalled;

    const amount = try self.registeredPathCount();
    if (amount > 0 and !force) {
        return error.InUse;
    }

    if (Fs.existsDir(path)) {
        try Fs.deleteTreeIfExists(path);
    }
}

pub fn addPathToManifest(
    self: *Package,
    linked_path: []const u8,
) !void {
    var package_manifest = try self.ctx.manifest.readManifest(
        Structs.Manifests.Packages,
        self.ctx.paths.pkg_manifest,
    );
    defer package_manifest.deinit();

    var list = try std.ArrayList(Structs.Manifests.PackagePaths).initCapacity(self.ctx.allocator, 10);
    defer list.deinit(self.ctx.allocator);

    var list_path = try std.ArrayList([]const u8).initCapacity(
        self.ctx.allocator,
        10,
    );
    defer list_path.deinit(self.ctx.allocator);

    for (package_manifest.value.packages) |p| {
        if (std.mem.eql(u8, p.name, self.package.name)) {
            for (p.paths) |path| try list_path.append(self.ctx.allocator, path);
            continue;
        }
        try list.append(self.ctx.allocator, p);
    }

    var is_in_path = false;
    for (list_path.items) |p| {
        if (std.mem.eql(u8, p, linked_path)) {
            is_in_path = true;
            break;
        }
    }
    if (!is_in_path) {
        try list_path.append(self.ctx.allocator, linked_path);
    }

    try list.append(self.ctx.allocator, Structs.Manifests.PackagePaths{
        .name = self.package.name,
        .paths = list_path.items,
    });

    package_manifest.value.packages = list.items;

    try Json.writePretty(
        self.ctx.allocator,
        self.ctx.paths.pkg_manifest,
        package_manifest.value,
    );
}

pub fn removePathFromManifest(
    self: *Package,
    linked_path: []const u8,
) !void {
    var package_manifest = try self.ctx.manifest.readManifest(
        Structs.Manifests.Packages,
        self.ctx.paths.pkg_manifest,
    );
    defer package_manifest.deinit();

    var list = try std.ArrayList(Structs.Manifests.PackagePaths).initCapacity(self.ctx.allocator, 10);
    defer list.deinit(self.ctx.allocator);

    var list_path = try std.ArrayList([]const u8).initCapacity(self.ctx.allocator, 10);
    defer list_path.deinit(self.ctx.allocator);

    for (package_manifest.value.packages) |package_paths| {
        if (std.mem.eql(u8, package_paths.name, self.package.name)) {
            for (package_paths.paths) |path| {
                if (std.mem.eql(u8, path, linked_path)) {
                    continue;
                }
                try list_path.append(self.ctx.allocator, path);
            }
            continue;
        }
        try list.append(self.ctx.allocator, package_paths);
    }

    if (list_path.items.len > 0) {
        try list.append(self.ctx.allocator, Structs.Manifests.PackagePaths{
            .name = self.package.name,
            .paths = list_path.items,
        });
    } else {
        const package_path = try std.fmt.allocPrint(
            self.ctx.allocator,
            "{s}/{s}/",
            .{ self.ctx.paths.pkg_root, self.package.name },
        );
        defer self.ctx.allocator.free(package_path);

        if (Fs.existsDir(package_path)) {
            Fs.deleteTreeIfExists(package_path) catch {};
        }
    }

    package_manifest.value.packages = list.items;
    try Json.writePretty(self.ctx.allocator, self.ctx.paths.pkg_manifest, package_manifest.value);
}

pub fn lockRegister(self: *Package) !void {
    var lock = try self.ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Default.package_files.lock,
    );
    defer lock.deinit();

    const new_entry = Structs.ZepFiles.Package{
        .name = self.package.name,
        .hash = self.package.hash,
        .source = self.package.source,
        .zig_version = self.package.zig_version,
        .root_file = self.package.root_file,
    };

    lock.value.packages = try filterOut(
        self.ctx.allocator,
        lock.value.packages,
        self.package.name,
        Structs.ZepFiles.Package,
        struct {
            fn match(item: Structs.ZepFiles.Package, needle: []const u8) bool {
                return std.mem.startsWith(u8, item.name, needle);
            }
        }.match,
    );

    lock.value.packages = try appendUnique(
        Structs.ZepFiles.Package,
        lock.value.packages,
        new_entry,
        self.ctx.allocator,
        struct {
            fn match(item: Structs.ZepFiles.Package, needle: Structs.ZepFiles.Package) bool {
                return std.mem.startsWith(u8, item.name, needle.name);
            }
        }.match,
    );

    lock.value.root.packages = try filterOut(
        self.ctx.allocator,
        lock.value.root.packages,
        self.package.name,
        []const u8,
        struct {
            fn match(a: []const u8, b: []const u8) bool {
                return std.mem.startsWith(u8, a, b); // first remove the previous package Name
            }
        }.match,
    );

    lock.value.root.packages = try appendUnique(
        []const u8,
        lock.value.root.packages,
        new_entry.name,
        self.ctx.allocator,
        struct {
            fn match(a: []const u8, b: []const u8) bool {
                return std.mem.startsWith(u8, a, b);
            }
        }.match,
    );

    try Json.writePretty(
        self.ctx.allocator,
        Constants.Default.package_files.lock,
        lock.value,
    );
}

pub fn lockUnregister(self: *Package) !void {
    var lock = try self.ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Default.package_files.lock,
    );
    defer lock.deinit();

    lock.value.packages = try filterOut(
        self.ctx.allocator,
        lock.value.packages,
        self.package.name,
        Structs.ZepFiles.Package,
        struct {
            fn match(item: Structs.ZepFiles.Package, needle: []const u8) bool {
                return std.mem.eql(u8, item.name, needle);
            }
        }.match,
    );

    lock.value.root.packages = try filterOut(
        self.ctx.allocator,
        lock.value.root.packages,
        self.package.name,
        []const u8,
        struct {
            fn match(item: []const u8, needle: []const u8) bool {
                return std.mem.eql(u8, item, needle);
            }
        }.match,
    );

    try Json.writePretty(
        self.ctx.allocator,
        Constants.Default.package_files.lock,
        lock.value,
    );
}

fn appendUnique(
    comptime T: type,
    list: []const T,
    new_item: T,
    allocator: std.mem.Allocator,
    matchFn: fn (a: T, b: T) bool,
) ![]T {
    var arr = try std.ArrayList(T).initCapacity(allocator, 10);
    defer arr.deinit(allocator);

    for (list) |item| {
        try arr.append(allocator, item);
        if (matchFn(item, new_item))
            return arr.toOwnedSlice(allocator);
    }

    try arr.append(allocator, new_item);
    return arr.toOwnedSlice(allocator);
}

fn filterOut(
    allocator: std.mem.Allocator,
    list: anytype,
    filter: []const u8,
    comptime T: type,
    matchFn: fn (a: T, b: []const u8) bool,
) ![]T {
    var out = try std.ArrayList(T).initCapacity(allocator, 10);
    defer out.deinit(allocator);

    for (list) |item| {
        if (!matchFn(item, filter))
            try out.append(allocator, item);
    }

    return out.toOwnedSlice(allocator);
}
