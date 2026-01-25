const std = @import("std");

const Uninstaller = @import("../../lib/packages/uninstall.zig");
const Package = @import("package");

const Context = @import("context");
const Args = @import("args");

fn uninstall(ctx: *Context) !void {
    if (ctx.cmds.len < 3) return error.UninstallMissingArguments;

    const package = ctx.cmds[2]; // package name;
    var split = std.mem.splitScalar(u8, package, '@');
    const package_name = split.first();
    const package_version = split.next();

    const uninstall_args = Args.parseUninstall(ctx.options);
    if (uninstall_args.global) {
        var p = try Package.init(
            ctx,
            package_name,
            package_version,
        );
        defer p.deinit();
        p.uninstallFromDisk(uninstall_args.force) catch |err| {
            switch (err) {
                error.InUse => {
                    try ctx.printer.append("WARNING: Atleast 1 project is using {s}. Uninstalling it globally now might have serious consequences.\n\n", .{package}, .{ .color = .red });
                    try ctx.printer.append("Use - if you do not care\n $ zep uninstall [target]@[version] -g -f\n\n", .{}, .{ .color = .yellow });
                },
                error.NotInstalled => {
                    try ctx.printer.append("[{s}] Not installed\n\n", .{package}, .{ .color = .red });
                    return;
                },
                else => {
                    try ctx.printer.append("Uninstalling failed.\n\n", .{}, .{ .color = .red });
                    return;
                },
            }
        };
        if (uninstall_args.force) {
            try ctx.printer.append("[{s}] Package deleted consequences ignored.\n\n", .{package}, .{ .color = .green });
        }
        return;
    }

    var uninstaller = Uninstaller.init(ctx);
    defer uninstaller.deinit();

    uninstaller.uninstall(package_name) catch |err| {
        switch (err) {
            error.NotInstalled => {
                try ctx.printer.append(
                    "{s} is not installed!\n",
                    .{package_name},
                    .{ .color = .red },
                );
                try ctx.printer.append(
                    "(locally) => If you wanna uninstall it globally, use\n $ zep global-uninstall {s}@<version>\n\n",
                    .{package_name},
                    .{ .color = .blue },
                );
            },
            else => {
                try ctx.printer.append("Uninstalling {s} has failed...\n\n", .{package_name}, .{ .color = .red });
            },
        }
    };
    return;
}

pub fn _uninstallController(ctx: *Context) !void {
    try uninstall(ctx);
}
