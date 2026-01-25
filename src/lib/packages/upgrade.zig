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
        var p_split = std.mem.splitAny(u8, package.name, "@");
        const name = p_split.first();
        try self.ctx.printer.append(
            " > Upgrading - {s}...\n",
            .{name},
            .{ .verbosity = 0 },
        );

        // if no version was specified it gets the
        // latest version
        var p = installer.resolvePackage(
            name,
            null,
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
                        .{ name, err },
                        .{ .verbosity = 0, .color = .red },
                    );
                    continue;
                },
            }
        };

        defer p.deinit();
        installer.installOne(&p) catch |err| {
            try self.ctx.printer.append(
                "  ! [ERROR] Failed to upgrade - {s} [{any}]...\n",
                .{ name, err },
                .{ .verbosity = 0, .color = .red },
            );
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
