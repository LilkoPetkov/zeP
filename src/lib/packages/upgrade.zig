const std = @import("std");

pub const Upgrader = @This();

const Locales = @import("locales");
const Constants = @import("constants");
const Structs = @import("structs");

const Installer = @import("install.zig");
const Context = @import("context");

ctx: *Context,

pub fn init(ctx: *Context) Upgrader {
    return Upgrader{
        .ctx = ctx,
    };
}

pub fn deinit(_: *Upgrader) void {}

pub fn upgrade(self: *Upgrader) !void {
    try self.ctx.logger.info("Upgrading packages...", @src());

    const prev_verbosity = Locales.VERBOSITY_MODE;
    Locales.VERBOSITY_MODE = 0;

    const lock = try self.ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Default.package_files.lock,
    );
    defer lock.deinit();

    var installer = Installer.init(self.ctx);
    for (lock.value.packages) |package| {
        const package_name = switch (package.namespace) {
            .github => try std.fmt.allocPrint(self.ctx.allocator, "{s}/{s}", .{
                package.install.author,
                package.install.name,
            }),
            else => try self.ctx.allocator.dupe(u8, package.name),
        };
        defer self.ctx.allocator.free(package_name);

        try self.ctx.printer.append(
            " > Upgrading - {s}",
            .{package_name},
            .{ .verbosity = 0 },
        );

        // if no version was specified it gets the
        // latest version
        installer.installOne(
            package_name,
            null,
            package.namespace,
            false,
        ) catch |err| {
            switch (err) {
                error.AlreadyInstalled => {
                    try self.ctx.printer.append(
                        " >> already latest!\n",
                        .{},
                        .{ .verbosity = 0, .color = .green },
                    );
                    continue;
                },
                else => {
                    try self.ctx.printer.append(
                        "  ! [ERROR] Failed to upgrade - {s} [{any}]...\n",
                        .{ package_name, err },
                        .{ .verbosity = 0, .color = .red },
                    );
                    continue;
                },
            }
        };

        try self.ctx.printer.append(
            " >> upgraded!\n",
            .{},
            .{ .verbosity = 0, .color = .green },
        );
        continue;
    }

    Locales.VERBOSITY_MODE = prev_verbosity;
}
