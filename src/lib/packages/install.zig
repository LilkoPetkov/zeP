const std = @import("std");

pub const Installer = @This();

const Locales = @import("locales");
const Constants = @import("constants");
const Structs = @import("structs");
const Package = @import("package");

const Fs = @import("io").Fs;
const Prompt = @import("cli").Prompt;
const Injector = @import("core").Injector;
const Hash = @import("core").Hash;

const Downloader = @import("lib/download.zig");
const Uninstaller = @import("uninstall.zig");

const Context = @import("context");
const Zon = @import("zon");

ctx: *Context,
downloader: Downloader,
install_type: Structs.Extras.InstallType,

pub fn init(
    ctx: *Context,
    install_type: ?Structs.Extras.InstallType,
) Installer {
    const downloader = Downloader.init(ctx);

    return Installer{
        .downloader = downloader,
        .ctx = ctx,
        .install_type = install_type orelse .zep,
    };
}

pub fn deinit(self: *Installer) void {
    self.downloader.deinit();
}

fn isFetched(
    self: *Installer,
    package_id: []const u8,
) !bool {
    const target_path = try std.fs.path.join(
        self.ctx.allocator,
        &.{
            self.ctx.paths.pkg_root,
            package_id,
        },
    );
    defer self.ctx.allocator.free(target_path);
    return Fs.existsDir(target_path);
}

fn isLocked(
    self: *Installer,
    package_name: []const u8,
) !bool {
    const lock = try self.ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Default.package_files.lock,
    );
    defer lock.deinit();

    var match = false;
    for (lock.value.packages) |pkg| {
        if (!std.mem.startsWith(u8, pkg.name, package_name)) continue;
        match = true;
    }
    return match;
}

fn isLinked(
    self: *Installer,
    package_name: []const u8,
) !bool {
    const target_path = try std.fs.path.join(
        self.ctx.allocator,
        &.{
            Constants.Default.package_files.zep_folder,
            package_name,
        },
    );
    defer self.ctx.allocator.free(target_path);

    _ = std.fs.cwd().access(target_path, .{}) catch {
        return false;
    };
    return true;
}

fn isInstalled(
    self: *Installer,
    package_id: []const u8,
) !bool {
    try self.ctx.logger.info("Checking if package is installed", @src());

    var split = std.mem.splitScalar(u8, package_id, '@');
    const package_name = split.first();
    const z = try self.isLinked(package_name);
    const l = try self.isLocked(package_id);
    const f = try self.isFetched(package_id);

    return z and l and f;
}

fn isCorrupt(
    self: *Installer,
    package_id: []const u8,
) !bool {
    var split = std.mem.splitScalar(u8, package_id, '@');
    const package_name = split.first();
    const z = try self.isLinked(package_name);
    if (!z) return false;

    const package_path = try std.fmt.allocPrint(
        self.ctx.allocator,
        "{s}/{s}",
        .{
            Constants.Default.package_files.zep_folder,
            package_name,
        },
    );
    defer self.ctx.allocator.free(package_path);

    var symlinked_buffer: [256]u8 = undefined;
    const symlinked = std.fs.cwd().readLink(package_path, &symlinked_buffer) catch
        return true;
    if (!Fs.existsDir(symlinked)) return true;

    return false;
}

fn fixCorrupt(
    self: *Installer,
    package_id: []const u8,
) !void {
    var split = std.mem.splitScalar(u8, package_id, '@');
    const package_name = split.first();

    const package_path = try std.fmt.allocPrint(
        self.ctx.allocator,
        "{s}/{s}",
        .{
            Constants.Default.package_files.zep_folder,
            package_name,
        },
    );
    defer self.ctx.allocator.free(package_path);
    Fs.deleteSymlinkIfExists(package_path);
}

fn linkPackage(
    self: *Installer,
    package: *Package,
    force_inject: bool,
) !void {
    try self.ctx.logger.info("Linking Package...", @src());
    try package.lockRegister();

    var injector = Injector.init(
        self.ctx.allocator,
        &self.ctx.printer,
        &self.ctx.manifest,
        force_inject,
    );
    try injector.initInjector();

    // symbolic link
    const target_path = try std.fmt.allocPrint(
        self.ctx.allocator,
        "{s}/{s}",
        .{
            self.ctx.paths.pkg_root,
            package.package_id,
        },
    );
    defer self.ctx.allocator.free(target_path);

    const relative_symbolic_link_path = try std.fs.path.join(
        self.ctx.allocator,
        &.{
            Constants.Default.package_files.zep_folder,
            package.package.name,
        },
    );
    Fs.deleteTreeIfExists(relative_symbolic_link_path) catch {};
    Fs.deleteFileIfExists(relative_symbolic_link_path) catch {};
    defer self.ctx.allocator.free(relative_symbolic_link_path);

    const cwd = try std.fs.cwd().realpathAlloc(self.ctx.allocator, ".");
    defer self.ctx.allocator.free(cwd);

    const absolute_symbolic_link_path = try std.fs.path.join(
        self.ctx.allocator,
        &.{
            cwd,
            relative_symbolic_link_path,
        },
    );
    defer self.ctx.allocator.free(absolute_symbolic_link_path);
    try std.fs.cwd().symLink(target_path, relative_symbolic_link_path, .{ .is_directory = true });
    package.addPathToManifest(absolute_symbolic_link_path) catch {
        return error.AddingToManifestFailed;
    };
}

pub fn resolvePackage(
    self: *Installer,
    package_name: []const u8,
    package_version: ?[]const u8,
) !Package {
    const v = package_version orelse "";
    blk: {
        if (v.len == 0) break :blk;
        const package_id = try std.fmt.allocPrint(self.ctx.allocator, "{s}@{s}", .{ package_name, v });
        defer self.ctx.allocator.free(package_id);
        if (try self.isInstalled(package_id)) return error.AlreadyInstalled;
        if (try self.isCorrupt(package_id)) {
            try self.fixCorrupt(package_id);
        }
        break :blk;
    }

    try self.ctx.logger.infof("Getting Package...", .{}, @src());
    const package = try Package.init(
        self.ctx,
        package_name,
        package_version,
        self.install_type,
    );

    try self.ctx.logger.infof("Package received!", .{}, @src());

    if (v.len == 0) {
        if (try self.isInstalled(package.package.name)) return error.AlreadyInstalled;
        if (try self.isCorrupt(package.package.name)) {
            try self.fixCorrupt(package.package.name);
        }
    }

    return package;
}

fn checkZon(
    self: *Installer,
    package: *Package,
) !void {
    const path_build_zig_zon = try std.fmt.allocPrint(
        self.ctx.allocator,
        "{s}/{s}/build.zig.zon",
        .{ self.ctx.paths.pkg_root, package.package_id },
    );
    if (!Fs.existsFile(path_build_zig_zon)) return;

    var build_zig_zon = try Fs.openFile(path_build_zig_zon);
    defer build_zig_zon.close();
    const data = try build_zig_zon.readToEndAlloc(
        self.ctx.allocator,
        Constants.Default.mb,
    );
    defer self.ctx.allocator.free(data);
    if (data.len == 0) return;

    var doc = try Zon.parse(self.ctx.allocator, data);
    defer doc.deinit();

    try self.ctx.logger.info("Checking dependencies", @src());
    const is_package_dependencies = doc.getObject("dependencies");
    if (is_package_dependencies) |package_dependencies| {
        var iter = package_dependencies.entries.iterator();
        const dependencies = try self.ctx.allocator.alloc(
            []const u8,
            package_dependencies.entries.size,
        );
        var i: usize = 0;
        while (iter.next()) |v| {
            var version: ?[]const u8 = null;
            const is_hash = v.value_ptr.object.get("hash");
            if (is_hash) |hash| {
                var hash_iter = std.mem.splitAny(u8, hash.string, "-");
                _ = hash_iter.next();
                version = hash_iter.next();
            }

            const is_url = v.value_ptr.object.get("url") orelse return error.InvalidZon;
            var parsed = try parseOwnerRepo(is_url.string);
            const p = try std.fmt.allocPrint(
                self.ctx.allocator,
                "{s}/{s}",
                .{
                    parsed.owner, parsed.repo,
                },
            );

            const prev_verbosity = Locales.VERBOSITY_MODE;
            Locales.VERBOSITY_MODE = 0;
            try self.ctx.printer.append(
                " Adding dependency {s}\n",
                .{p},
                .{ .verbosity = 0 },
            );

            self.installOne(p, version, false) catch |err| {
                try self.ctx.printer.append(
                    " ! Failed to add dependency {s}, with err={any}\n",
                    .{ p, err },
                    .{
                        .verbosity = 0,
                    },
                );
            };
            Locales.VERBOSITY_MODE = prev_verbosity;

            if (std.mem.endsWith(u8, parsed.repo, ".zig")) {
                parsed.repo = parsed.repo[0 .. parsed.repo.len - 4]; // remove ".zig"
            }
            dependencies[i] = parsed.repo;
            i += 1;
        }

        package.package.packages = dependencies;
    }

    var package_modified = false;
    blk: {
        if (!std.mem.eql(u8, "/", package.package.zig_version) and
            !std.mem.eql(u8, "/", package.package.root_file) and
            !std.mem.eql(u8, "latest", package.package.version)) break :blk;

        if (std.mem.eql(u8, "/", package.package.zig_version)) {
            const zig_version = doc.getString("minimum_zig_version") orelse "/";
            package.package.zig_version = zig_version;
            package_modified = true;
        }

        if (std.mem.eql(u8, "latest", package.package.version)) {
            const version = doc.getString("version") orelse "latest";
            package.package.version = version;
            package_modified = true;
        }

        if (!std.mem.eql(u8, package.package.root_file, "/")) break :blk;

        const assumed_root_file = try std.fmt.allocPrint(
            self.ctx.allocator,
            "/src/{s}.zig",
            .{
                package.package.name,
            },
        );

        if (Locales.VERBOSITY_MODE == 0) {
            package.package.root_file = assumed_root_file;
            break :blk;
        }

        try self.ctx.printer.append(
            "Root file was not found!\n",
            .{},
            .{
                .color = .red,
                .verbosity = 0,
                .weight = .bold,
            },
        );

        const root_file = try Prompt.input(
            self.ctx.allocator,
            &self.ctx.printer,
            "(Guessed) Root file: ",
            .{ .initial_value = assumed_root_file },
        );
        package.package.root_file = root_file;
        try self.ctx.printer.append("\n", .{}, .{ .verbosity = 0 });
        package_modified = true;
    }
    if (package_modified) try package.updateMetadata();
}

pub fn installOne(
    self: *Installer,
    package_name: []const u8,
    package_version: ?[]const u8,
    force_inject: bool,
) anyerror!void {
    var package = try self.resolvePackage(
        package_name,
        package_version,
    );
    defer package.deinit();

    try self.ctx.logger.info("Installing Package...", @src());
    try self.ctx.printer.append(
        "Installing Package {s}\n",
        .{package.package.name},
        .{
            .verbosity = 3,
        },
    );

    blk: {
        if (try self.isLocked(package.package.name)) break :blk;
        var uninstaller = Uninstaller.init(self.ctx);
        defer uninstaller.deinit();
        uninstaller.uninstall(package.package.name) catch |err| {
            switch (err) {
                error.NotInstalled => break :blk,
                else => return err,
            }
        };
        break :blk;
    }

    const lock = try self.ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Default.package_files.lock,
    );
    defer lock.deinit();

    try self.ctx.logger.info("Installing Package via Downloader", @src());
    try self.downloader.installPackage(
        package.package_id,
        package.package.source,
    );
    try self.ctx.logger.info("Installed.", @src());

    try self.ctx.logger.info("Getting build.zig.zon", @src());
    try self.checkZon(&package);

    blk: {
        if (!std.mem.eql(u8, package.package.root_file, "/")) break :blk;

        const assumed_root_file = try std.fmt.allocPrint(
            self.ctx.allocator,
            "/src/{s}.zig",
            .{
                package.package.name,
            },
        );

        if (Locales.VERBOSITY_MODE == 0) {
            package.package.root_file = assumed_root_file;
            break :blk;
        }

        try self.ctx.printer.append(
            "Root file was not found!\n",
            .{},
            .{
                .color = .red,
                .verbosity = 0,
                .weight = .bold,
            },
        );

        const root_file = try Prompt.input(
            self.ctx.allocator,
            &self.ctx.printer,
            "(Guessed) Root file: ",
            .{ .initial_value = assumed_root_file },
        );
        package.package.root_file = root_file;
        try self.ctx.printer.append("\n", .{}, .{ .verbosity = 0 });
        try package.updateMetadata();
    }

    if (!std.mem.containsAtLeast(u8, package.package.zig_version, 1, lock.value.root.zig_version)) {
        try self.ctx.printer.append("WARNING: ", .{}, .{
            .color = .red,
            .weight = .bold,
            .verbosity = 2,
        });
        try self.ctx.printer.append(
            "ZIG VERSIONS ARE NOT MATCHING!\n",
            .{},
            .{
                .color = .blue,
                .weight = .bold,
                .verbosity = 2,
            },
        );
        try self.ctx.printer.append(
            "{s} Zig Version: {s}\n",
            .{ package.package.name, package.package.zig_version },
            .{ .verbosity = 2 },
        );
        try self.ctx.printer.append(
            "Your Zig Version: {s}\n\n",
            .{lock.value.root.zig_version},
            .{ .verbosity = 2 },
        );
    }

    try self.linkPackage(&package, force_inject);
    try self.ctx.printer.append(
        "Successfully installed - {s}\n\n",
        .{package.package_id},
        .{ .color = .green },
    );
}

pub fn installAll(self: *Installer) anyerror!void {
    try self.ctx.logger.info("Installing All", @src());

    const prev_verbosity = Locales.VERBOSITY_MODE;
    Locales.VERBOSITY_MODE = 0;

    var lock = try self.ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Default.package_files.lock,
    );
    defer lock.deinit();

    for (lock.value.root.packages) |package_id| {
        try self.ctx.printer.append(
            " > Installing - {s} ",
            .{package_id},
            .{ .verbosity = 0 },
        );

        var package_split = std.mem.splitScalar(u8, package_id, '@');
        const package_name = package_split.first();
        const package_version = package_split.next();

        self.installOne(
            package_name,
            package_version,
            false,
        ) catch |err| {
            switch (err) {
                error.AlreadyInstalled => {
                    try self.ctx.printer.append(
                        " >> already installed!\n",
                        .{},
                        .{ .verbosity = 0, .color = .green },
                    );
                    continue;
                },
                else => {
                    try self.ctx.printer.append(
                        "  ! [ERROR] Failed to install - {s} [{any}]...\n",
                        .{ package_id, err },
                        .{ .verbosity = 0, .color = .red },
                    );
                },
            }
            continue;
        };

        try self.ctx.printer.append(
            " >> done!\n",
            .{},
            .{ .verbosity = 0, .color = .green },
        );
    }
    try self.ctx.printer.append(
        "\nInstalled all!\n",
        .{},
        .{ .verbosity = 0, .color = .green },
    );
    Locales.VERBOSITY_MODE = prev_verbosity;
}

fn parseOwnerRepo(url: []const u8) !struct { owner: []const u8, repo: []const u8 } {
    var s = url;

    // Step 1: remove known prefixes
    if (std.mem.startsWith(u8, s, "git+")) {
        s = s[4..];
    } else if (std.mem.startsWith(u8, s, "github:")) {
        s = s[7..];
    }

    // Step 2: remove protocol for git+ssh or https
    const proto_sep = std.mem.indexOf(u8, s, ":");
    if (proto_sep) |i| {
        if (i != 1) { // ignore 'C:' style Windows paths
            s = s[(i + 1)..];
            if (std.mem.startsWith(u8, s, "//")) {
                s = s[2..];
            }
        }
    }

    // Step 3: trim everything after hash '#' (commit/tag)
    const hash_idx = std.mem.indexOf(u8, s, "#");
    if (hash_idx) |i| {
        s = s[0..i];
    }

    // Step 4: remove trailing ".git" if present
    if (std.mem.endsWith(u8, s, ".git")) {
        s = s[0 .. s.len - 4];
    }

    // Step 5: split by '/' and get owner/repo
    var it = std.mem.splitAny(u8, s, "/");
    _ = it.next();

    var owner: []const u8 = "";
    var repo: []const u8 = "";
    if (it.next()) |o| owner = o else return error.InvalidURL;
    if (it.next()) |r| repo = r else return error.InvalidURL;

    return .{ .owner = owner, .repo = repo };
}
