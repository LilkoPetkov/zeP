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
const Resolver = @import("resolver");
const Zon = @import("zon");

/// Handles Packages, returns null if package is not found.
/// Rolls back to latest version if none was specified.
/// Hashes are generated on init.
ctx: *Context,

package: Structs.ZepFiles.Package,
package_id: []const u8,

pub fn init(
    ctx: *Context,
    package_name: []const u8,
    package_version: ?[]const u8,
    install_type: ?Structs.Extras.InstallType,
) !Package {
    var resolver = Resolver.init(ctx);
    const package = try resolver.resolvePackage(
        package_name,
        package_version,
        install_type,
    );

    const package_id = try std.fmt.allocPrint(
        ctx.allocator,
        "{s}@{s}",
        .{ package.name, package.version },
    );

    return Package{
        .ctx = ctx,
        .package = package,
        .package_id = package_id,
    };
}

pub fn deinit(self: *Package) void {
    self.ctx.allocator.free(self.package.hash);
    self.ctx.allocator.free(self.package.source);
    self.ctx.allocator.free(self.package.name);
    self.ctx.allocator.free(self.package.version);
    self.ctx.allocator.free(self.package.zig_version);

    self.ctx.allocator.free(self.package_id);
}

pub fn updateMetadata(self: *Package) !void {
    const cached_filename = try std.fmt.allocPrint(
        self.ctx.allocator,
        "{s}/{s}+{s}.json",
        .{ self.ctx.paths.meta_cached, @tagName(self.package.namespace), self.package.name },
    );
    defer self.ctx.allocator.free(cached_filename);
    if (!Fs.existsFile(cached_filename)) return;

    const f = try Fs.openFile(cached_filename);
    defer f.close();
    const data = try f.readToEndAlloc(self.ctx.allocator, Constants.Default.kb * 16);
    defer self.ctx.allocator.free(data);

    var parsed_package: std.json.Parsed(Structs.Packages.Package) = try std.json.parseFromSlice(
        Structs.Packages.Package,
        self.ctx.allocator,
        data,
        .{ .allocate = .alloc_always },
    );
    defer parsed_package.deinit();

    for (parsed_package.value.versions) |*v| {
        if (!std.mem.eql(u8, v.version, self.package.version)) continue;
        v.sha256sum = self.package.hash;
        v.zig_version = self.package.zig_version;
    }

    const stringified = try std.json.Stringify.valueAlloc(
        self.ctx.allocator,
        parsed_package.value,
        .{},
    );
    defer self.ctx.allocator.free(stringified);

    const w = try Fs.fileTruncate(cached_filename);
    defer w.close();
    _ = try w.writeAll(stringified);
    return;
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
        .{ self.ctx.paths.pkg_root, self.package_id },
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
            .{ self.ctx.paths.pkg_root, self.package_id },
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

    const new_item = Structs.ZepFiles.Package{
        .name = self.package.name,
        .install = self.package.install,
        .version = self.package.version,
        .namespace = self.package.namespace,
        .hash = self.package.hash,
        .source = self.package.source,
        .zig_version = self.package.zig_version,
    };

    lock.value.packages = try self.filterOut(
        lock.value.packages,
        Structs.ZepFiles.Package,
        struct {
            fn match(item: Structs.ZepFiles.Package, needle: []const u8) bool {
                return std.mem.startsWith(u8, item.name, needle);
            }
        }.match,
    );

    lock.value.packages = try self.appendUnique(
        Structs.ZepFiles.Package,
        lock.value.packages,
        new_item,
        struct {
            fn match(item: Structs.ZepFiles.Package, needle: Structs.ZepFiles.Package) bool {
                return std.mem.startsWith(u8, item.name, needle.name);
            }
        }.match,
    );

    lock.value.root.packages = try self.filterOut(
        lock.value.root.packages,
        []const u8,
        struct {
            fn match(a: []const u8, b: []const u8) bool {
                return std.mem.startsWith(u8, a, b); // first remove the previous package Name
            }
        }.match,
    );

    lock.value.root.packages = try self.appendUnique(
        []const u8,
        lock.value.root.packages,
        new_item.name,
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

    var bzz = try Zon.parseFile(self.ctx.allocator, "build.zig.zon");
    defer bzz.deinit();

    const p = try std.fmt.allocPrint(self.ctx.allocator, ".zep/{s}", .{self.package.name});
    defer self.ctx.allocator.free(p);

    var copy_pkg = try self.ctx.allocator.dupe(u8, self.package.name);
    defer self.ctx.allocator.free(copy_pkg);

    if (std.mem.endsWith(u8, copy_pkg, ".zig")) {
        copy_pkg = copy_pkg[0 .. copy_pkg.len - 4]; // remove ".zig"
    }

    var dependencies = bzz.getObject("dependencies") orelse return;
    const s = dependencies.get(copy_pkg);
    if (s) |_| return;

    var new_pkg = Zon.Value.Object.init(self.ctx.allocator);
    try new_pkg.set("path", .{ .string = p });
    try dependencies.insert(copy_pkg, .{
        .object = new_pkg,
    });

    const bzz_stringed = try bzz.toString();
    try Zon.writeFileAtomic(self.ctx.allocator, "build.zig.zon", bzz_stringed);
    return;
}

pub fn lockUnregister(self: *Package) !void {
    var lock = try self.ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Default.package_files.lock,
    );
    defer lock.deinit();

    lock.value.packages = try self.filterOut(
        lock.value.packages,
        Structs.ZepFiles.Package,
        struct {
            fn match(item: Structs.ZepFiles.Package, needle: []const u8) bool {
                return std.mem.eql(u8, item.name, needle);
            }
        }.match,
    );

    lock.value.root.packages = try self.filterOut(
        lock.value.root.packages,
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

    var bzz = try Zon.parseFile(self.ctx.allocator, "build.zig.zon");
    defer bzz.deinit();

    var copy_pkg = try self.ctx.allocator.dupe(u8, self.package.name);
    defer self.ctx.allocator.free(copy_pkg);

    if (std.mem.endsWith(u8, copy_pkg, ".zig")) {
        copy_pkg = copy_pkg[0 .. copy_pkg.len - 4]; // remove ".zig"
    }

    var dependencies = bzz.getObject("dependencies") orelse return;
    _ = dependencies.remove(copy_pkg);

    const bzz_stringed = try bzz.toString();
    try Zon.writeFileAtomic(self.ctx.allocator, "build.zig.zon", bzz_stringed);
    return;
}

fn appendUnique(
    self: *Package,
    comptime T: type,
    list: []const T,
    new_item: T,
    matchFn: fn (a: T, b: T) bool,
) ![]T {
    var arr = try std.ArrayList(T).initCapacity(self.ctx.allocator, 10);
    defer arr.deinit(self.ctx.allocator);

    for (list) |item| {
        try arr.append(self.ctx.allocator, item);
        if (matchFn(item, new_item))
            return arr.toOwnedSlice(self.ctx.allocator);
    }

    try arr.append(self.ctx.allocator, new_item);
    return arr.toOwnedSlice(self.ctx.allocator);
}

fn filterOut(
    self: *Package,
    list: anytype,
    comptime T: type,
    matchFn: fn (a: T, b: []const u8) bool,
) ![]T {
    const filter = self.package.name;

    var out = try std.ArrayList(T).initCapacity(self.ctx.allocator, 10);
    defer out.deinit(self.ctx.allocator);

    for (list) |item| {
        if (!matchFn(item, filter))
            try out.append(self.ctx.allocator, item);
    }

    return out.toOwnedSlice(self.ctx.allocator);
}
