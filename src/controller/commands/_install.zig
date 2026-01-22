const std = @import("std");

const Installer = @import("../../lib/packages/install.zig");

const Context = @import("context");
const Args = @import("args");

fn install(ctx: *Context) !void {
    const install_args = Args.parseInstall(ctx.options);

    const target = if (ctx.cmds.len < 3) null else ctx.cmds[2]; // package name;
    var installer = Installer.init(ctx);
    installer.force_inject = install_args.inject;

    const selected =
        @as(u3, @intFromBool(install_args.unverified)) +
        @as(u3, @intFromBool(install_args.github)) +
        @as(u3, @intFromBool(install_args.gitlab));

    if (selected > 1) {
        return error.InvalidArguments;
    }

    installer.install_unverified_packages = install_args.unverified;

    defer installer.deinit();

    if (target) |package| {
        var split = std.mem.splitScalar(u8, package, '@');
        const package_name = split.first();
        const package_version = split.next();
        installer.install(package_name, package_version) catch |err| {
            try ctx.logger.errorf("Installing Failed error={any}", .{err}, @src());

            switch (err) {
                error.AlreadyInstalled => {
                    try ctx.printer.append("\nAlready installed!\n\n", .{}, .{ .color = .yellow });
                },
                error.PackageNotFound => {
                    try ctx.printer.append("\nPackage not Found!\n\n", .{}, .{ .color = .yellow });
                },
                error.HashMismatch => {
                    try ctx.printer.append(
                        "HASH MISMATCH!\nPLEASE REPORT!\n\n",
                        .{},
                        .{
                            .color = .red,
                            .weight = .bold,
                        },
                    );
                },
                else => {
                    try ctx.printer.append("\nInstalling {s} has failed... {any}\n\n", .{ package, err }, .{ .color = .red });
                },
            }
        };
    } else {
        installer.installAll() catch |err| {
            try ctx.logger.errorf("Installing All Failed error={any}", .{err}, @src());

            switch (err) {
                error.AlreadyInstalled => {
                    try ctx.printer.append("\nAlready installed!\n\n", .{}, .{ .color = .yellow });
                },
                error.HashMismatch => {
                    try ctx.printer.append("\n  ! HASH MISMATCH!\nPLEASE REPORT!\n\n", .{}, .{ .color = .red });
                },
                else => {
                    try ctx.printer.append("\nInstalling all has failed...\n\n", .{}, .{ .color = .red });
                },
            }
        };
    }
    return;
}

pub fn _installController(ctx: *Context) !void {
    try install(ctx);
}
