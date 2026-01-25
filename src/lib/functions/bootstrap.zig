const std = @import("std");

const Constants = @import("constants");
const Structs = @import("structs");

const Fs = @import("io").Fs;

const Artifact = @import("../artifact/artifact.zig");
const Installer = @import("../packages/install.zig");
const Init = @import("../packages/init.zig");

const Context = @import("context");

/// Handles bootstrapping
pub fn bootstrap(
    ctx: *Context,
    zig_version: []const u8,
    pkgs: [][]const u8,
) !void {
    try ctx.logger.info("Bootstrapping", @src());

    try ctx.printer.append(
        "-- GETTING ZIG --\n\n",
        .{},
        .{
            .color = .blue,
            .weight = .bold,
        },
    );

    var zig = try Artifact.init(ctx, .zig);
    defer zig.deinit();

    const default_target = Constants.Default.resolveDefaultTarget();
    try ctx.logger.infof("Installing zig version={s}...", .{zig_version}, @src());
    try zig.install(zig_version, default_target);

    try ctx.printer.append("\n", .{}, .{});

    try ctx.logger.info("Initting...", @src());
    var initer = try Init.init(
        ctx,
        false,
    );

    try ctx.logger.info("Committing Init...", @src());
    try initer.commitInit();
    try ctx.printer.append("\n", .{}, .{});

    try ctx.printer.append(
        "-- GETTING PACKAGES --\n\n",
        .{},
        .{
            .color = .blue,
            .weight = .bold,
        },
    );

    try ctx.logger.info("Installing packages...", @src());

    var installer = Installer.init(ctx);
    defer installer.deinit();
    ctx.fetcher.install_unverified_packages = true;
    for (pkgs) |pkg| {
        var p = std.mem.splitScalar(u8, pkg, '@');
        const package_name = p.first();
        const package_version = p.next();

        installer.install(
            package_name,
            package_version,
        ) catch |err| {
            switch (err) {
                error.AlreadyInstalled => {
                    try ctx.printer.append("{s} already installed.\n", .{package_name}, .{});
                },
                else => {
                    try ctx.printer.append("{s} failed to install.\n", .{package_name}, .{});
                },
            }
        };
    }
}
