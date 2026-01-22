const std = @import("std");

pub const Uninstaller = @This();

const Constants = @import("constants");
const Structs = @import("structs");

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
        Constants.Extras.package_files.lock,
    );
    var package_version: []const u8 = "";
    for (lock.value.packages) |package| {
        if (std.mem.startsWith(u8, package.name, package_name)) {
            var split = std.mem.splitScalar(u8, package.name, '@');
            _ = split.first();
            const version = split.next();
            if (version) |v| {
                package_version = v;
            } else {
                return error.NotInstalled;
            }

            break;
        }
        continue;
    }

    if (package_version.len == 0) {
        return error.NotInstalled;
    }

    const package_id = try std.fmt.allocPrint(
        self.ctx.allocator,
        "{s}@{s}",
        .{ package_name, package_version },
    );
    defer self.ctx.allocator.free(package_id);

    try self.ctx.printer.append("Deleting Package...\n[{s}]\n\n", .{package_name}, .{});
    try self.ctx.manifest.lockRemove(package_id);
    var injector = Injector.init(
        self.ctx.allocator,
        &self.ctx.printer,
        &self.ctx.manifest,
        false,
    );
    try injector.initInjector();

    // Remove symbolic link
    const symbolic_link_path = try std.fs.path.join(
        self.ctx.allocator,
        &.{
            Constants.Extras.package_files.zep_folder,
            package_name,
        },
    );
    defer self.ctx.allocator.free(symbolic_link_path);

    if (Fs.existsDir(symbolic_link_path)) {
        Fs.deleteSymlinkIfExists(symbolic_link_path);

        const cwd = try std.fs.cwd().realpathAlloc(self.ctx.allocator, ".");
        defer self.ctx.allocator.free(cwd);

        const absolute_path = try std.fs.path.join(self.ctx.allocator, &.{ cwd, symbolic_link_path });
        defer self.ctx.allocator.free(absolute_path);

        // ! Handles the deletion of the package
        // ! as the package can ONLY be deleted,
        // ! if no other project uses it
        // !
        try self.ctx.manifest.removePathFromManifest(
            package_id,
            absolute_path,
        );
    }
    try self.ctx.manifest.lockRemove(package_id);
    try self.ctx.printer.append("Successfully deleted - {s}\n\n", .{package_name}, .{ .color = .green });
}
