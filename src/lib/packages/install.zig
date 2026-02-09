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

pub fn init(
    ctx: *Context,
) Installer {
    const downloader = Downloader.init(ctx);

    return Installer{
        .downloader = downloader,
        .ctx = ctx,
    };
}

pub fn deinit(self: *Installer) void {
    self.downloader.deinit();
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
        self.ctx.manifest,
        &self.ctx.printer,
    );

    try injector.initInjector(force_inject);

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
    defer self.ctx.allocator.free(relative_symbolic_link_path);
    Fs.deleteSymlinkIfExists(relative_symbolic_link_path);

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
    try package.addPathToManifest(absolute_symbolic_link_path);
}

fn resolvePackage(
    self: *Installer,
    package_name: []const u8,
    package_version: ?[]const u8,
    install_type: Structs.Extras.InstallType,
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
        install_type,
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

pub fn installOne(
    self: *Installer,
    package_name: []const u8,
    package_version: ?[]const u8,
    install_type: Structs.Extras.InstallType,
    force_inject: bool,
) anyerror!void {
    var package = try self.resolvePackage(
        package_name,
        package_version,
        install_type,
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
    try self.downloader.downloadPackage(
        package.package_id,
        package.package.source,
    );
    try self.ctx.logger.info("Installed.", @src());

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
        .{package.package.name},
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

    var failed: u8 = 0;
    for (lock.value.packages) |package| {
        const package_install = package.install;
        var package_install_split = std.mem.splitAny(u8, package_install, "@");
        const package_name = package_install_split.first();
        const package_version = package_install_split.next();

        try self.ctx.printer.append(
            " > Installing - {s}",
            .{package_install},
            .{ .verbosity = 0 },
        );

        self.installOne(
            package_name,
            package_version,
            package.namespace,
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
                    failed += 1;
                    try self.ctx.printer.append(
                        "  ! [ERROR] Failed to install - {s} [{any}]...\n",
                        .{ package_name, err },
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
        "\nInstalled: {d} packages ({d} failed)\n",
        .{
            lock.value.packages.len - failed,
            failed,
        },
        .{ .verbosity = 0 },
    );
    Locales.VERBOSITY_MODE = prev_verbosity;
}
