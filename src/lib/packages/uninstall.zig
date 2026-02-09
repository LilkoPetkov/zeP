const std = @import("std");

pub const Uninstaller = @This();

const Constants = @import("constants");
const Structs = @import("structs");
const Package = @import("package");

const Fs = @import("io").Fs;
const Injector = @import("core").Injector;
const Context = @import("context");

/// Handles the uninstallation of a package
ctx: *Context,

/// Initialize the uninstaller with allocator, package name, and printer
pub fn init(ctx: *Context) Uninstaller {
    return Uninstaller{ .ctx = ctx };
}

pub fn deinit(_: *Uninstaller) void {}

/// Main uninstallation routine
pub fn uninstall(
    self: *Uninstaller,
    package_name: []const u8,
) !void {
    try self.ctx.logger.infof("Uninstalling Package {s}", .{package_name}, @src());

    const lock = try self.ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Default.package_files.lock,
    );

    var target_package: ?Structs.ZepFiles.Package = null;
    for (lock.value.packages) |package| {
        if (!std.mem.startsWith(u8, package.name, package_name)) continue;
        target_package = package;
        continue;
    }

    const p = target_package orelse return error.NotInstalled;

    var package = try Package.init(
        self.ctx,
        package_name,
        p.version,
        p.namespace,
    );
    defer package.deinit();

    try self.ctx.printer.append("Deleting Package...\n[{s}]\n\n", .{package_name}, .{ .verbosity = 1 });

    // Remove symbolic link
    const relative_symbolic_link_path = try std.fs.path.join(
        self.ctx.allocator,
        &.{
            Constants.Default.package_files.zep_folder,
            package_name,
        },
    );
    defer self.ctx.allocator.free(relative_symbolic_link_path);

    if (Fs.existsSym(relative_symbolic_link_path)) {
        Fs.deleteSymlinkIfExists(relative_symbolic_link_path);

        const cwd = try std.fs.cwd().realpathAlloc(self.ctx.allocator, ".");
        defer self.ctx.allocator.free(cwd);

        const absolute_symbolic_link_path = try std.fs.path.join(self.ctx.allocator, &.{ cwd, relative_symbolic_link_path });
        defer self.ctx.allocator.free(absolute_symbolic_link_path);

        try package.removePathFromManifest(absolute_symbolic_link_path);
    }
    try package.lockUnregister();

    var injector = Injector.init(
        self.ctx.allocator,
        self.ctx.manifest,
        &self.ctx.printer,
    );
    try injector.initInjector(false);
    try self.ctx.printer.append("Successfully deleted - {s}\n\n", .{package_name}, .{ .color = .green });
}
