const std = @import("std");

pub const Manifest = @This();

const Logger = @import("logger");
const Constants = @import("constants");
const Structs = @import("structs");

const Fs = @import("io").Fs;
const Json = @import("json.zig");
const Package = @import("package.zig");

allocator: std.mem.Allocator,
json: Json,
paths: Constants.Paths.Paths,

pub fn init(
    allocator: std.mem.Allocator,
    json: Json,
    paths: Constants.Paths.Paths,
) Manifest {
    return .{
        .allocator = allocator,
        .json = json,
        .paths = paths,
    };
}

pub fn writeManifest(
    self: *Manifest,
    comptime ManifestType: type,
    path: []const u8,
    manifest: ManifestType,
) !void {
    try Fs.deleteFileIfExists(path);

    const jsonStr = try std.json.Stringify.valueAlloc(self.allocator, manifest, .{ .whitespace = .indent_tab });
    defer self.allocator.free(jsonStr);

    const f = try Fs.openOrCreateFile(path);
    defer f.close();

    _ = try f.write(jsonStr);
}

pub fn readManifest(
    self: *Manifest,
    comptime ManifestType: type,
    path: []const u8,
) !std.json.Parsed(ManifestType) {
    if (!Fs.existsFile(path)) {
        const default_manifest: ManifestType = .{};
        try self.writeManifest(ManifestType, path, default_manifest);
    }

    const f = try Fs.openFile(path);
    defer f.close();

    const data = try f.readToEndAlloc(self.allocator, 10 * Constants.Default.mb);
    const parsed = std.json.parseFromSlice(ManifestType, self.allocator, data, .{}) catch {
        try Fs.deleteFileIfExists(path);
        return try self.readManifest(ManifestType, path);
    };

    return parsed;
}

fn stringInArray(haystack: [][]const u8, needle: []const u8) bool {
    for (haystack) |h| {
        if (std.mem.eql(u8, h, needle)) return true;
    }
    return false;
}

pub fn addPathToManifest(
    self: *Manifest,
    package_id: []const u8,
    linked_path: []const u8,
) !void {
    var package_manifest = try self.readManifest(
        Structs.Manifests.PackagesManifest,
        self.paths.pkg_manifest,
    );
    defer package_manifest.deinit();

    var list = try std.ArrayList(Structs.Manifests.PackagePaths).initCapacity(self.allocator, 10);
    defer list.deinit(self.allocator);

    var list_path = try std.ArrayList([]const u8).initCapacity(self.allocator, 10);
    defer list_path.deinit(self.allocator);

    for (package_manifest.value.packages) |p| {
        if (std.mem.eql(u8, p.name, package_id)) {
            for (p.paths) |path| try list_path.append(self.allocator, path);
            continue;
        }
        try list.append(self.allocator, p);
    }

    if (!stringInArray(list_path.items, linked_path)) {
        try list_path.append(self.allocator, linked_path);
    }

    try list.append(self.allocator, Structs.Manifests.PackagePaths{
        .name = package_id,
        .paths = list_path.items,
    });

    package_manifest.value.packages = list.items;

    try self.json.writePretty(self.paths.pkg_manifest, package_manifest.value);
}

pub fn removePathFromManifest(
    self: *Manifest,
    package_id: []const u8,
    linked_path: []const u8,
) !void {
    std.debug.print("{s}", .{self.paths.pkg_manifest});
    var package_manifest = try self.readManifest(
        Structs.Manifests.PackagesManifest,
        self.paths.pkg_manifest,
    );
    defer package_manifest.deinit();

    var list = try std.ArrayList(Structs.Manifests.PackagePaths).initCapacity(self.allocator, 10);
    defer list.deinit(self.allocator);

    var list_path = try std.ArrayList([]const u8).initCapacity(self.allocator, 10);
    defer list_path.deinit(self.allocator);

    for (package_manifest.value.packages) |package_paths| {
        if (std.mem.eql(u8, package_paths.name, package_id)) {
            for (package_paths.paths) |path| {
                if (std.mem.eql(u8, path, linked_path)) {
                    continue;
                }
                try list_path.append(self.allocator, path);
            }
            continue;
        }
        try list.append(self.allocator, package_paths);
    }

    if (list_path.items.len > 0) {
        try list.append(self.allocator, Structs.Manifests.PackagePaths{ .name = package_id, .paths = list_path.items });
    } else {
        var buf: [128]u8 = undefined;
        const package_path = try std.fmt.bufPrint(&buf, "{s}/{s}/", .{ self.paths.pkg_root, package_id });
        if (Fs.existsDir(package_path)) {
            Fs.deleteTreeIfExists(package_path) catch {};
        }
    }

    package_manifest.value.packages = list.items;
    try self.json.writePretty(self.paths.pkg_manifest, package_manifest.value);
}

pub fn manifestAdd(
    self: *Manifest,
    pkg: *Structs.ZepFiles.PackageJsonStruct,
    package_name: []const u8,
    package_id: []const u8,
) !void {
    pkg.packages = try filterOut(
        self.allocator,
        pkg.packages,
        package_name,
        []const u8,
        struct {
            fn match(a: []const u8, b: []const u8) bool {
                return std.mem.startsWith(u8, a, b); // first remove the previous package Name
            }
        }.match,
    );

    pkg.packages = try appendUnique(
        []const u8,
        pkg.packages,
        package_id,
        self.allocator,
        struct {
            fn match(a: []const u8, b: []const u8) bool {
                return std.mem.startsWith(u8, a, b);
            }
        }.match,
    );

    try self.json.writePretty(Constants.Extras.package_files.manifest, pkg);
}

pub fn lockAdd(
    self: *Manifest,
    lock: *Structs.ZepFiles.PackageLockStruct,
    package: Package,
) !void {
    const new_entry = Structs.ZepFiles.LockPackageStruct{
        .name = package.id,
        .hash = package.package_hash,
        .source = package.package.url,
        .zig_version = package.package.zig_version,
        .root_file = package.package.root_file,
    };

    lock.packages = try filterOut(
        self.allocator,
        lock.packages,
        package.package_name,
        Structs.ZepFiles.LockPackageStruct,
        struct {
            fn match(item: Structs.ZepFiles.LockPackageStruct, needle: []const u8) bool {
                return std.mem.startsWith(u8, item.name, needle);
            }
        }.match,
    );

    lock.packages = try appendUnique(
        Structs.ZepFiles.LockPackageStruct,
        lock.packages,
        new_entry,
        self.allocator,
        struct {
            fn match(item: Structs.ZepFiles.LockPackageStruct, needle: Structs.ZepFiles.LockPackageStruct) bool {
                return std.mem.startsWith(u8, item.name, needle.name);
            }
        }.match,
    );

    var package_json = try self.readManifest(
        Structs.ZepFiles.PackageJsonStruct,
        Constants.Extras.package_files.manifest,
    );
    defer package_json.deinit();
    lock.root = package_json.value;

    try self.json.writePretty(Constants.Extras.package_files.lock, lock);
}

pub fn lockRemove(
    self: *Manifest,
    lock: *Structs.ZepFiles.PackageLockStruct,
    package_name: []const u8,
) !void {
    lock.packages = try filterOut(
        self.allocator,
        lock.packages,
        package_name,
        Structs.ZepFiles.LockPackageStruct,
        struct {
            fn match(item: Structs.ZepFiles.LockPackageStruct, needle: []const u8) bool {
                return std.mem.startsWith(u8, item.name, needle);
            }
        }.match,
    );

    var package_json = try self.readManifest(
        Structs.ZepFiles.PackageJsonStruct,
        Constants.Extras.package_files.manifest,
    );
    defer package_json.deinit();
    lock.root = package_json.value;

    try self.json.writePretty(Constants.Extras.package_files.lock, lock);
}

pub fn manifestRemove(
    self: *Manifest,
    pkg: *Structs.ZepFiles.PackageJsonStruct,
    package_id: []const u8,
) !void {
    pkg.packages = try filterOut(
        self.allocator,
        pkg.packages,
        package_id,
        []const u8,
        struct {
            fn match(item: []const u8, needle: []const u8) bool {
                return std.mem.eql(u8, item, needle);
            }
        }.match,
    );

    try self.json.writePretty(Constants.Extras.package_files.manifest, pkg);
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
