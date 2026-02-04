const std = @import("std");
const Context = @import("context").Context;
const Structs = @import("structs");
const Constants = @import("constants");
const Hash = @import("core").Hash;
const Json = @import("core").Json;
const Fs = @import("io").Fs;

pub const Resolver = @This();

ctx: *Context,

pub fn init(
    ctx: *Context,
) Resolver {
    return Resolver{
        .ctx = ctx,
    };
}

fn resolveFromLock(
    self: *Resolver,
    package_name: []const u8,
    package_version: []const u8,
) !?Structs.ZepFiles.Package {
    const lock = try self.ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Default.package_files.lock,
    );
    defer lock.deinit();

    for (lock.value.packages) |p| {
        if (!std.mem.eql(u8, p.name, package_name)) continue;
        if (!std.mem.eql(u8, p.version, package_version)) continue;
        try self.ctx.logger.info("Package found in .lock...", @src());

        return Structs.ZepFiles.Package{
            .name = try self.ctx.allocator.dupe(u8, package_name),
            .install = .{
                .name = try self.ctx.allocator.dupe(u8, p.install.name),
                .author = try self.ctx.allocator.dupe(u8, p.install.author),
            },
            .version = try self.ctx.allocator.dupe(u8, package_version),
            .source = try self.ctx.allocator.dupe(u8, p.source),
            .zig_version = try self.ctx.allocator.dupe(u8, p.zig_version),
            .hash = try self.ctx.allocator.dupe(u8, p.hash),
            .namespace = .zep,
        };
    }

    return null;
}

fn resolveFromFetch(
    self: *Resolver,
    package_name: []const u8,
    package_version: ?[]const u8,
    install_type: Structs.Extras.InstallType,
) !Structs.ZepFiles.Package {
    try self.ctx.logger.info("Fetching package version...", @src());
    try self.ctx.printer.append("Finding the package...\n", .{}, .{
        .verbosity = 3,
    });
    var package = try self.fetchPackage(
        package_name,
        install_type,
    );
    defer package.deinit(self.ctx.allocator);
    try self.ctx.logger.infof("Package fetched!", .{}, @src());

    try self.ctx.printer.append(
        " > PACKAGE FOUND\n\n",
        .{},
        .{
            .color = .green,
            .verbosity = 2,
        },
    );

    const versions = package.versions;
    if (versions.len == 0) {
        try self.ctx.logger.err("Fetching package has no version...", @src());
        self.ctx.printer.append("Package has no version!\n", .{}, .{ .color = .red }) catch {};
        return error.NoPackageVersion;
    }

    try self.ctx.logger.infof("Getting package version!", .{}, @src());
    try self.ctx.printer.append(
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

    var v = check_selected orelse return error.NotFound;
    if (v.sha256sum.len == 0) {
        const hash = try Hash.hashDataByUrl(
            self.ctx.allocator,
            v.url,
            self.ctx.logger,
        );
        v.sha256sum = hash;
    }

    return Structs.ZepFiles.Package{
        .name = try self.ctx.allocator.dupe(u8, package.name),
        .install = .{
            .name = try self.ctx.allocator.dupe(u8, package.name),
            .author = try self.ctx.allocator.dupe(u8, package.author),
        },
        .version = try self.ctx.allocator.dupe(u8, v.version),
        .namespace = install_type,
        .source = try self.ctx.allocator.dupe(u8, v.url),
        .zig_version = try self.ctx.allocator.dupe(u8, v.zig_version),
        .hash = try self.ctx.allocator.dupe(u8, v.sha256sum),
    };
}

pub fn resolvePackage(
    self: *Resolver,
    package_name: []const u8,
    package_version: ?[]const u8,
    install_type: ?Structs.Extras.InstallType,
) !Structs.ZepFiles.Package {
    if (package_version) |v| {
        const attempt = try self.resolveFromLock(
            package_name,
            v,
        );
        if (attempt) |a| return a;
    }

    const i_type = install_type orelse return error.MissingType;
    const package = try self.resolveFromFetch(
        package_name,
        package_version,
        i_type,
    );

    try self.ctx.logger.infof("Package version = {s}!", .{package.version}, @src());
    try self.ctx.printer.append(" > VERSION FOUND!\n\n", .{}, .{
        .color = .green,
        .verbosity = 2,
    });
    return package;
}

fn fetchFromZep(
    self: *Resolver,
    package_name: []const u8,
) !Structs.Packages.Package {
    const cached_filename = try std.fmt.allocPrint(
        self.ctx.allocator,
        "{s}/zep+{s}.json",
        .{ self.ctx.paths.meta_cached, package_name },
    );
    defer self.ctx.allocator.free(cached_filename);
    if (Fs.existsFile(cached_filename)) {
        const f = try Fs.openFile(cached_filename);
        defer f.close();
        const data = try f.readToEndAlloc(self.ctx.allocator, Constants.Default.kb * 16);
        defer self.ctx.allocator.free(data);
        var package: std.json.Parsed(Structs.Packages.Package) = try std.json.parseFromSlice(
            Structs.Packages.Package,
            self.ctx.allocator,
            data,
            .{ .allocate = .alloc_always },
        );
        defer package.deinit();

        const duped = try package.value.dupPackage(self.ctx.allocator);
        return duped;
    }

    var releases = try self.ctx.fetcher.fetchReleases(package_name);
    defer releases.deinit(self.ctx.allocator);

    var versions = try self.ctx.allocator.alloc(
        Structs.Packages.Version,
        releases.items.len,
    );
    for (releases.items, 0..) |r, i| {
        versions[i] = Structs.Packages.Version{
            .root_file = try self.ctx.allocator.dupe(u8, r.RootFile),
            .sha256sum = try self.ctx.allocator.dupe(u8, r.Hash),
            .url = try self.ctx.allocator.dupe(u8, r.Url),
            .version = try self.ctx.allocator.dupe(u8, r.Release),
            .zig_version = try self.ctx.allocator.dupe(u8, r.ZigVersion),
        };
    }

    const fetched = try self.ctx.fetcher.fetchPackage(package_name);
    const package = Structs.Packages.Package{
        .author = try self.ctx.allocator.dupe(u8, fetched.UserID),
        .name = try self.ctx.allocator.dupe(u8, fetched.Name),
        .docs = try self.ctx.allocator.dupe(u8, fetched.Docs),
        .versions = versions,
    };

    const f = try Fs.openFile(cached_filename);
    defer f.close();

    const data = try std.json.Stringify.valueAlloc(self.ctx.allocator, package, .{});
    defer self.ctx.allocator.free(data);
    _ = try f.writeAll(data);

    return package;
}

fn fetchFromUrl(
    self: *Resolver,
    package_name: []const u8,
) !Structs.Packages.Package {
    const cached_filename = try std.fmt.allocPrint(
        self.ctx.allocator,
        "{s}/zepu+{s}.json",
        .{ self.ctx.paths.meta_cached, package_name },
    );
    defer self.ctx.allocator.free(cached_filename);
    if (Fs.existsFile(cached_filename)) {
        const f = try Fs.openFile(cached_filename);
        defer f.close();
        const data = try f.readToEndAlloc(self.ctx.allocator, Constants.Default.kb * 16);
        defer self.ctx.allocator.free(data);
        var package: std.json.Parsed(Structs.Packages.Package) = try std.json.parseFromSlice(
            Structs.Packages.Package,
            self.ctx.allocator,
            data,
            .{ .allocate = .alloc_always },
        );
        defer package.deinit();

        const duped = try package.value.dupPackage(self.ctx.allocator);
        return duped;
    }

    const url = try std.fmt.allocPrint(
        self.ctx.allocator,
        Constants.Default.zep_url ++ "/packages/{s}.json",
        .{package_name},
    );
    defer self.ctx.allocator.free(url);

    var body = std.Io.Writer.Allocating.init(self.ctx.allocator);
    const res = self.ctx.fetcher.client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .response_writer = &body.writer,
    }) catch |err| {
        return err;
    };
    if (res.status == .not_found) return error.PackageNotFound;

    const data = body.written();
    var package: std.json.Parsed(Structs.Packages.Package) = try std.json.parseFromSlice(
        Structs.Packages.Package,
        self.ctx.allocator,
        data,
        .{ .allocate = .alloc_always },
    );
    defer package.deinit();

    const f = try Fs.openFile(cached_filename);
    defer f.close();
    _ = try f.writeAll(data);

    const duped = try package.value.dupPackage(self.ctx.allocator);
    return duped;
}

fn fetchFromGithub(
    self: *Resolver,
    package_name: []const u8,
) !Structs.Packages.Package {
    var p_split = std.mem.splitAny(u8, package_name, "/");
    const owner = p_split.next() orelse return error.InvalidGithubPackage;
    const repo = p_split.next() orelse return error.InvalidGithubPackage;

    const cached_filename = try std.fmt.allocPrint(
        self.ctx.allocator,
        "{s}/github+{s}.json",
        .{ self.ctx.paths.meta_cached, repo },
    );
    defer self.ctx.allocator.free(cached_filename);
    if (Fs.existsFile(cached_filename)) {
        const f = try Fs.openFile(cached_filename);
        defer f.close();
        const data = try f.readToEndAlloc(
            self.ctx.allocator,
            Constants.Default.mb * 5,
        );
        defer self.ctx.allocator.free(data);
        var package: std.json.Parsed(Structs.Packages.Package) = try std.json.parseFromSlice(
            Structs.Packages.Package,
            self.ctx.allocator,
            data,
            .{ .allocate = .alloc_always },
        );
        defer package.deinit();

        const duped = try package.value.dupPackage(self.ctx.allocator);
        return duped;
    }

    const url = try std.fmt.allocPrint(self.ctx.allocator, "{s}/repos/{s}/{s}/releases", .{
        Constants.Default.github_api,
        owner,
        repo,
    });
    defer self.ctx.allocator.free(url);

    var body = std.Io.Writer.Allocating.init(self.ctx.allocator);
    const res = self.ctx.fetcher.client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .response_writer = &body.writer,
    }) catch |err| {
        return err;
    };
    if (res.status == .not_found) return error.PackageNotFound;

    const data = body.written();

    const GithubPackage = struct {
        zipball_url: []const u8,
        author: struct { login: []const u8 },
        tag_name: []const u8,
    };
    var github_package_releases: std.json.Parsed([]GithubPackage) = try std.json.parseFromSlice(
        []GithubPackage,
        self.ctx.allocator,
        data,
        .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = true,
        },
    );
    defer github_package_releases.deinit();

    const len = if (github_package_releases.value.len > 0) github_package_releases.value.len else 1;
    var versions = try self.ctx.allocator.alloc(
        Structs.Packages.Version,
        len,
    );

    for (github_package_releases.value, 0..) |gpr, i| {
        const source = try std.fmt.allocPrint(
            self.ctx.allocator,
            "{s}#.zip",
            .{gpr.zipball_url},
        );
        const v = Structs.Packages.Version{
            .url = source,
            .version = try self.ctx.allocator.dupe(u8, gpr.tag_name),
            .zig_version = try self.ctx.allocator.dupe(u8, "/"),
            .root_file = try self.ctx.allocator.dupe(u8, "/"),
            .sha256sum = try self.ctx.allocator.dupe(u8, ""),
        };
        versions[i] = v;
    }

    if (github_package_releases.value.len == 0) {
        const fmt = "https://github.com/{s}/{s}/archive/refs/heads/master.zip";
        const modurl = try std.fmt.allocPrint(self.ctx.allocator, fmt, .{ owner, repo });
        const v = Structs.Packages.Version{
            .url = modurl,
            .version = try self.ctx.allocator.dupe(u8, "latest"),
            .zig_version = try self.ctx.allocator.dupe(u8, "/"),
            .root_file = try self.ctx.allocator.dupe(u8, "/"),
            .sha256sum = try self.ctx.allocator.dupe(u8, ""),
        };
        versions[0] = v;
    }

    const package = Structs.Packages.Package{
        .author = try self.ctx.allocator.dupe(u8, owner),
        .name = try self.ctx.allocator.dupe(u8, repo),
        .docs = "",
        .versions = versions,
    };

    const f = try Fs.openFile(cached_filename);
    defer f.close();

    const d = try std.json.Stringify.valueAlloc(self.ctx.allocator, package, .{});
    defer self.ctx.allocator.free(d);
    _ = try f.writeAll(d);

    return package;
}

fn loadFromLocal(
    self: *Resolver,
    package_name: []const u8,
) !Structs.Packages.Package {
    const path = try std.fmt.allocPrint(
        self.ctx.allocator,
        "{s}/{s}.json",
        .{ self.ctx.paths.custom, package_name },
    );
    defer self.ctx.allocator.free(path);

    if (!Fs.existsFile(path)) return error.PackageNotFound;

    var package: std.json.Parsed(Structs.Packages.Package) = try Json.parseJsonFromFile(
        self.ctx.allocator,
        Structs.Packages.Package,
        path,
        Constants.Default.mb * 10,
    );
    defer package.deinit();

    const duped = try package.value.dupPackage(self.ctx.allocator);
    return duped;
}

pub fn fetchPackage(
    self: *Resolver,
    package_name: []const u8,
    install_type: Structs.Extras.InstallType,
) !Structs.Packages.Package {
    switch (install_type) {
        .zep => {
            const pkg = self.fetchFromZep(package_name) catch {
                const fallback = try self.fetchFromUrl(package_name);
                return fallback;
            };
            return pkg;
        },
        .local => {
            const pkg = try self.loadFromLocal(package_name);
            return pkg;
        },
        .github => {
            const pkg = try self.fetchFromGithub(package_name);
            return pkg;
        },
        .gitlab => {},
        .codeberg => {},
    }
    return error.PackageNotFound;
}
