const std = @import("std");

const Installer = @import("../../lib/packages/install.zig");

const Structs = @import("structs");
const Context = @import("context");
const Args = @import("args");

fn install(ctx: *Context) !void {
    const install_args = Args.parseInstall(ctx.options);

    const package_query = if (ctx.cmds.len < 3) null else ctx.cmds[2]; // package name;
    const selected =
        @as(u3, @intFromBool(install_args.zep)) +
        @as(u3, @intFromBool(install_args.github)) +
        @as(u3, @intFromBool(install_args.codeberg)) +
        @as(u3, @intFromBool(install_args.gitlab)) +
        @as(u3, @intFromBool(install_args.local));

    if (selected > 1) {
        return error.InvalidArguments;
    }
    var install_type: Structs.Extras.InstallType = .zep;
    if (install_args.zep) install_type = Structs.Extras.InstallType.zep;
    if (install_args.github) install_type = Structs.Extras.InstallType.github;
    if (install_args.gitlab) install_type = Structs.Extras.InstallType.gitlab;
    if (install_args.codeberg) install_type = Structs.Extras.InstallType.codeberg;
    if (install_args.local) install_type = Structs.Extras.InstallType.local;

    var installer = Installer.init(ctx, install_type);
    defer installer.deinit();

    if (package_query) |query| {
        var split = std.mem.splitScalar(u8, query, '@');
        const package_name = split.first();
        const package_version = split.next();

        installer.installOne(
            package_name,
            package_version,
            install_args.inject,
        ) catch |err| {
            try ctx.logger.errorf("Installing Failed error={any}", .{err}, @src());

            switch (err) {
                error.AlreadyInstalled => {
                    try ctx.printer.append("Already installed!\n\n", .{}, .{ .color = .yellow });
                },
                error.PackageNotFound => {
                    try ctx.printer.append("Package not Found!\n\n", .{}, .{ .color = .yellow });
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
                    try ctx.printer.append(
                        "Installing {s} has failed... {any}\n\n",
                        .{ package_name, err },
                        .{ .color = .red },
                    );
                },
            }
        };
    } else {
        installer.installAll() catch |err| {
            try ctx.logger.errorf("Installing All Failed error={any}", .{err}, @src());

            switch (err) {
                error.AlreadyInstalled => {
                    try ctx.printer.append("Already installed!\n\n", .{}, .{ .color = .yellow });
                },
                error.HashMismatch => {
                    try ctx.printer.append("  ! HASH MISMATCH!\nPLEASE REPORT!\n\n", .{}, .{ .color = .red });
                },
                else => {
                    try ctx.printer.append("Installing all has failed...\n\n", .{}, .{ .color = .red });
                },
            }
        };
    }
    return;
}

pub fn _installController(ctx: *Context) !void {
    try install(ctx);
}
