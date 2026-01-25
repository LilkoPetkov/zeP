const std = @import("std");

pub const Installer = @This();

const Locales = @import("locales");
const Constants = @import("constants");
const Structs = @import("structs");

const Fs = @import("io").Fs;
const Package = @import("package");
const Injector = @import("core").Injector;
const Hash = @import("core").Hash;

const Downloader = @import("lib/download.zig");
const Uninstaller = @import("uninstall.zig");

const Context = @import("context");

ctx: *Context,
downloader: Downloader,
force_inject: bool = false,

pub fn init(ctx: *Context) Installer {
    const downloader = Downloader.init(ctx);

    return Installer{
        .downloader = downloader,
        .ctx = ctx,
    };
}

pub fn deinit(self: *Installer) void {
    self.downloader.deinit();
}

fn isPackageFetched(
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

fn isPackageInLock(
    self: *Installer,
    package_id: []const u8,
) !bool {
    const lock = try self.ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Default.package_files.lock,
    );
    defer lock.deinit();

    var match = false;
    for (lock.value.root.packages) |pkg| {
        if (std.mem.eql(u8, pkg, package_id)) match = true;
    }
    return match;
}

fn isPackageInZep(
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

fn isPackageInstalled(
    self: *Installer,
    package_id: []const u8,
) !bool {
    try self.ctx.logger.info("Checking if package is installed", @src());

    var split = std.mem.splitScalar(u8, package_id, '@');
    const package_name = split.first();
    const z = try self.isPackageInZep(package_name);
    const l = try self.isPackageInLock(package_id);
    const f = try self.isPackageFetched(package_id);
    const c = try self.isPackageCorrupt(package_id);
    if (c) {
        try self.ctx.logger.info("Package corrupt, fixing...", @src());
        return false;
    }

    return z and l and f;
}

fn isPackageCorrupt(
    self: *Installer,
    package_id: []const u8,
) !bool {
    var split = std.mem.splitScalar(u8, package_id, '@');
    const package_name = split.first();
    const z = try self.isPackageInZep(package_name);
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
    const symlinked = std.fs.cwd().readLink(package_path, &symlinked_buffer) catch {
        Fs.deleteSymlinkIfExists(package_path);
        return true;
    };
    if (!Fs.existsDir(symlinked)) {
        Fs.deleteSymlinkIfExists(package_path);
        return true;
    }

    return false;
}

fn uninstallPrevious(
    self: *Installer,
    package: Package,
) !void {
    try self.ctx.logger.info("Uninstalling Previous Package...", @src());

    const lock = try self.ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Default.package_files.lock,
    );
    defer lock.deinit();

    var uninstaller = Uninstaller.init(self.ctx);
    defer uninstaller.deinit();

    for (lock.value.packages) |lock_package| {
        if (std.mem.eql(u8, lock_package.name, package.id)) return;

        if (std.mem.startsWith(u8, lock_package.name, package.package_name)) {
            try self.ctx.printer.append(
                "UNINSTALLING PREVIOUS [{s}]\n",
                .{try self.ctx.allocator.dupe(u8, lock_package.name)},
                .{ .color = .red, .verbosity = 2 },
            );
            const previous_verbosity = Locales.VERBOSITY_MODE;
            Locales.VERBOSITY_MODE = 0;
            try uninstaller.uninstall(package.package_name);
            Locales.VERBOSITY_MODE = previous_verbosity;
        }
    }
}

pub fn install(
    self: *Installer,
    package_name: []const u8,
    package_version: ?[]const u8,
) !void {
    try self.ctx.logger.info("Installing Package", @src());
    try self.ctx.printer.append(
        "Installing Package {s}\n",
        .{package_name},
        .{
            .verbosity = 3,
        },
    );
    const v = package_version orelse "";
    blk: {
        if (v.len == 0) break :blk;
        const package_id = try std.fmt.allocPrint(self.ctx.allocator, "{s}@{s}", .{ package_name, v });
        defer self.ctx.allocator.free(package_id);
        if (try self.isPackageInstalled(package_id)) return error.AlreadyInstalled;
        break :blk;
    }

    try self.ctx.logger.infof("Getting Package...", .{}, @src());
    try self.ctx.printer.append(
        "Getting Package version {s}\n",
        .{package_version orelse "/ (latest)"},
        .{
            .verbosity = 3,
        },
    );

    var package = try Package.init(
        self.ctx,
        package_name,
        package_version,
    );
    try self.ctx.logger.infof("Package received!", .{}, @src());
    defer package.deinit();

    try self.ctx.printer.append(
        "Found package {s}\n\n",
        .{package.package.version},
        .{
            .verbosity = 3,
        },
    );

    if (v.len == 0) {
        if (try self.isPackageInstalled(package.id)) return error.AlreadyInstalled;
    }
    const parsed = package.package;
    try self.uninstallPrevious(package);

    try self.setPackage(&package);
    const lock = try self.ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Default.package_files.lock,
    );

    defer lock.deinit();
    if (!std.mem.containsAtLeast(u8, parsed.zig_version, 1, lock.value.root.zig_version)) {
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
            .{ package.id, parsed.zig_version },
            .{ .verbosity = 2 },
        );
        try self.ctx.printer.append(
            "Your Zig Version: {s}\n\n",
            .{lock.value.root.zig_version},
            .{ .verbosity = 2 },
        );
    }
    try self.ctx.logger.infof("Checking Hash...", .{}, @src());
    try self.ctx.printer.append("Checking Hash...\n", .{}, .{ .verbosity = 2 });
    if (std.mem.eql(u8, package.package.sha256sum, parsed.sha256sum)) {
        try self.ctx.printer.append(" > HASH IDENTICAL\n\n", .{}, .{
            .color = .green,
            .verbosity = 2,
        });
    } else {
        return error.HashMismatch;
    }

    try self.downloader.downloadPackage(
        package.id,
        parsed.url,
    );

    try self.ctx.printer.append("Successfully installed - {s}\n\n", .{package.package_name}, .{ .color = .green });
}

fn setPackage(
    self: *Installer,
    package: *Package,
) !void {
    try self.ctx.logger.info("Setting Package...", @src());
    try package.lockAdd();

    var injector = Injector.init(
        self.ctx.allocator,
        &self.ctx.printer,
        &self.ctx.manifest,
        self.force_inject,
    );
    try injector.initInjector();

    // symbolic link
    const target_path = try std.fmt.allocPrint(
        self.ctx.allocator,
        "{s}/{s}",
        .{
            self.ctx.paths.pkg_root,
            package.id,
        },
    );
    defer self.ctx.allocator.free(target_path);

    const relative_symbolic_link_path = try std.fs.path.join(
        self.ctx.allocator,
        &.{
            Constants.Default.package_files.zep_folder,
            package.package_name,
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
        self.install(package_name, package_version) catch |err| {
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
