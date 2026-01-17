const std = @import("std");

pub const Fetch = @This();

const Logger = @import("logger");
const Constants = @import("constants");
const Structs = @import("structs");

const Fs = @import("io").Fs;
const Json = @import("json.zig");
const Manifest = @import("manifest.zig");

/// writing into files.
allocator: std.mem.Allocator,
paths: Constants.Paths.Paths,
manifest: Manifest,
install_unverified_packages: bool = false,

pub fn init(
    allocator: std.mem.Allocator,
    paths: Constants.Paths.Paths,
    manifest: Manifest,
) Fetch {
    return Fetch{
        .allocator = allocator,
        .paths = paths,
        .manifest = manifest,
    };
}

pub fn fetch(
    self: *Fetch,
    url: []const u8,
    client: *std.http.Client,
    options: Structs.Fetch.FetchOptions,
) !std.json.Parsed(std.json.Value) {
    var body = std.Io.Writer.Allocating.init(self.allocator);
    defer body.deinit();
    const res = try client.fetch(.{
        .location = .{ .url = url },
        .method = options.method,
        .payload = options.payload,
        .extra_headers = options.headers,
        .response_writer = &body.writer,
    });

    if (res.status == .not_found) {
        return error.NotFound;
    }
    const written = body.written();
    return std.json.parseFromSlice(
        std.json.Value,
        self.allocator,
        written,
        .{
            .allocate = .alloc_always,
        },
    );
}

fn _fetchPackage(self: *Fetch, name: []const u8) !Structs.Fetch.PackageStruct {
    const url = try std.fmt.allocPrint(
        self.allocator,
        Constants.Default.zep_url ++ "/api/v1/package?name={s}",
        .{name},
    );
    defer self.allocator.free(url);

    var client = std.http.Client{ .allocator = self.allocator };
    defer client.deinit();
    const get = try self.fetch(
        url,
        &client,
        .{
            .method = .GET,
        },
    );
    defer get.deinit();
    const get_object = get.value.object;
    const success = get_object.get("success") orelse return error.FetchFailed;
    if (!success.bool) {
        return error.FetchFailed;
    }
    const object_package = get_object.get("package") orelse return error.FetchFailed;
    var object = object_package.object;
    defer object.deinit();

    const package_id = object.get("id") orelse return error.FetchFailed;
    const package_user_id = object.get("userId") orelse return error.FetchFailed;
    const package_name = object.get("name") orelse return error.FetchFailed;
    const package_description = object.get("description") orelse return error.FetchFailed;
    const package_docs = object.get("docs") orelse return error.FetchFailed;
    const package_tags = object.get("tags") orelse return error.FetchFailed;
    const package_created_at = object.get("created_at") orelse return error.FetchFailed;
    const package = Structs.Fetch.PackageStruct{
        .ID = package_id.string,
        .UserID = package_user_id.string,
        .Name = package_name.string,
        .Description = package_description.string,
        .Docs = package_docs.string,
        .Tags = package_tags.string,
        .CreatedAt = package_created_at.string,
    };

    return package;
}

pub fn fetchPackages(self: *Fetch) !std.ArrayList(Structs.Fetch.PackageStruct) {
    var auth = try self.manifest.readManifest(
        Structs.Manifests.AuthManifest,
        self.paths.auth_manifest,
    );
    defer auth.deinit();
    if (auth.value.token.len == 0) {
        return error.NotAuthed;
    }

    const url = Constants.Default.zep_url ++ "/api/v1/packages";
    var client = std.http.Client{ .allocator = self.allocator };
    defer client.deinit();
    const get = try self.fetch(
        url,
        &client,
        .{
            .method = .GET,
            .headers = &.{
                std.http.Header{
                    .name = "Authorization",
                    .value = try auth.value.bearer(),
                },
            },
        },
    );
    defer get.deinit();
    const object = get.value.object;
    const success = object.get("success") orelse return error.FetchFailed;
    if (!success.bool) {
        return error.FetchFailed;
    }
    const object_packages = object.get("packages") orelse return error.FetchFailed;
    const array = object_packages.array;
    defer array.deinit();

    var packages = try std.ArrayList(Structs.Fetch.PackageStruct).initCapacity(
        self.allocator,
        array.items.len,
    );
    for (array.items) |package_value| {
        const package = package_value.object;
        const package_id = package.get("id") orelse return error.FetchFailed;
        const package_user_id = package.get("userId") orelse return error.FetchFailed;
        const package_name = package.get("name") orelse return error.FetchFailed;
        const package_description = package.get("description") orelse return error.FetchFailed;
        const package_docs = package.get("docs") orelse return error.FetchFailed;
        const package_tags = package.get("tags") orelse return error.FetchFailed;
        const package_created_at = package.get("created_at") orelse return error.FetchFailed;
        const package_struct = Structs.Fetch.PackageStruct{
            .ID = package_id.string,
            .UserID = package_user_id.string,
            .Name = package_name.string,
            .Description = package_description.string,
            .Docs = package_docs.string,
            .Tags = package_tags.string,
            .CreatedAt = package_created_at.string,
        };

        try packages.append(self.allocator, package_struct);
    }

    return packages;
}

pub fn fetchReleases(self: *Fetch, name: []const u8) !std.ArrayList(Structs.Fetch.ReleaseStruct) {
    var auth = try self.manifest.readManifest(
        Structs.Manifests.AuthManifest,
        self.paths.auth_manifest,
    );
    defer auth.deinit();
    if (auth.value.token.len == 0) {
        return error.NotAuthed;
    }

    const url = try std.fmt.allocPrint(
        self.allocator,
        Constants.Default.zep_url ++ "/api/v1/releases?package_name={s}",
        .{name},
    );
    defer self.allocator.free(url);

    var client = std.http.Client{ .allocator = self.allocator };
    defer client.deinit();
    const get = try self.fetch(
        url,
        &client,
        .{
            .method = .GET,
            .headers = &.{
                std.http.Header{
                    .name = "Authorization",
                    .value = try auth.value.bearer(),
                },
            },
        },
    );
    defer get.deinit();
    const object = get.value.object;
    const success = object.get("success") orelse return error.FetchFailed;
    if (!success.bool) {
        return error.FetchFailed;
    }
    const object_releases = object.get("releases") orelse return error.FetchFailed;
    const array = object_releases.array;
    defer array.deinit();

    var releases = try std.ArrayList(Structs.Fetch.ReleaseStruct).initCapacity(
        self.allocator,
        array.items.len,
    );
    for (array.items) |release_value| {
        const release = release_value.object;
        const release_id = release.get("id") orelse return error.FetchFailed;
        const release_user_id = release.get("userId") orelse return error.FetchFailed;
        const release_package_id = release.get("packageId") orelse return error.FetchFailed;
        const release_url = release.get("url") orelse return error.FetchFailed;
        const release_release = release.get("release") orelse return error.FetchFailed;
        const release_zig_version = release.get("zig_version") orelse return error.FetchFailed;
        const release_hash = release.get("hash") orelse return error.FetchFailed;
        const release_root_file = release.get("root_file") orelse return error.FetchFailed;
        const release_created_at = release.get("created_at") orelse return error.FetchFailed;
        const release_updated_at = release.get("updated_at") orelse return error.FetchFailed;
        const release_struct = Structs.Fetch.ReleaseStruct{
            .ID = release_id.string,
            .UserID = release_user_id.string,
            .PackageID = release_package_id.string,
            .Url = release_url.string,
            .Release = release_release.string,
            .ZigVersion = release_zig_version.string,
            .Hash = release_hash.string,
            .RootFile = release_root_file.string,
            .CreatedAt = release_created_at.string,
            .UpdatedAt = release_updated_at.string,
        };

        try releases.append(self.allocator, release_struct);
    }

    return releases;
}

fn fetchFromPackage(
    self: *Fetch,
    package_name: []const u8,
) !std.json.Parsed(Structs.Packages.PackageStruct) {
    var releases = try self.fetchReleases(package_name);
    defer releases.deinit(self.allocator);
    const package = try self._fetchPackage(package_name);

    const stringified = try std.json.Stringify.valueAlloc(self.allocator, .{
        .author = package.UserID,
        .name = package.Name,
        .docs = package.Docs,
        .versions = releases.items,
    }, .{});
    return std.json.parseFromSlice(
        Structs.Packages.PackageStruct,
        self.allocator,
        stringified,
        .{ .allocate = .alloc_always },
    );
}

fn fetchFromUrl(
    self: *Fetch,
    package_name: []const u8,
) !std.json.Parsed(Structs.Packages.PackageStruct) {
    var buf: [128]u8 = undefined;
    const url = try std.fmt.bufPrint(
        &buf,
        Constants.Default.zep_url ++ "/packages/{s}.json",
        .{package_name},
    );

    var client = std.http.Client{ .allocator = self.allocator };
    defer client.deinit();

    var body = std.Io.Writer.Allocating.init(self.allocator);
    const res = try client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .response_writer = &body.writer,
    });

    if (res.status == .not_found) return error.PackageNotFound;

    return std.json.parseFromSlice(
        Structs.Packages.PackageStruct,
        self.allocator,
        body.written(),
        .{ .allocate = .alloc_always },
    );
}

fn loadFromLocal(
    self: *Fetch,
    package_name: []const u8,
) !std.json.Parsed(Structs.Packages.PackageStruct) {
    var buf: [128]u8 = undefined;
    const path = try std.fmt.bufPrint(
        &buf,
        "{s}/{s}.json",
        .{ self.paths.custom, package_name },
    );

    if (!Fs.existsFile(path)) return error.PackageNotFound;

    return Json.parseJsonFromFile(
        self.allocator,
        Structs.Packages.PackageStruct,
        path,
        Constants.Default.mb * 10,
    );
}

pub fn fetchPackage(
    self: *Fetch,
    package_name: []const u8,
) !std.json.Parsed(Structs.Packages.PackageStruct) {
    if (self.install_unverified_packages) {
        if (self.fetchFromPackage(package_name)) |pkg| {
            return pkg;
        } else |_| {}
    }

    if (self.fetchFromUrl(package_name)) |pkg| {
        return pkg;
    } else |_| {}

    if (self.loadFromLocal(package_name)) |pkg| {
        return pkg;
    } else |_| {}

    return error.PackageNotFound;
}
