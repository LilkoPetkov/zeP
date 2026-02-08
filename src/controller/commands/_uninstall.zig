const std = @import("std");

const Uninstaller = @import("../../lib/packages/uninstall.zig");
const Package = @import("package");

const Structs = @import("structs");
const Context = @import("context");
const Args = @import("args");

fn uninstall(ctx: *Context) !void {
    if (ctx.cmds.len < 3) return error.UninstallMissingArguments;

    const package_query = ctx.cmds[2]; // package name;
    var split = std.mem.splitScalar(u8, package_query, '@');
    const package_name = split.first();
    const package_version = split.next();

    const uninstall_args = Args.parseUninstall(ctx.options);
    if (uninstall_args.global) {
        if (package_version == null) {
            try ctx.printer.append(
                "WARNING: For global uninstalls, a version is required.\n\n",
                .{},
                .{ .color = .red },
            );
            return;
        }

        // install args are being parsed
        // to detect which namespace is
        // target in the global
        // uninstall
        // GH/GL/CB/Z/L
        const install_args = Args.parseInstall(ctx.options);
        var _uninstall_type: ?Structs.Extras.InstallType = null;
        if (install_args.zep) _uninstall_type = Structs.Extras.InstallType.zep;
        if (install_args.github) _uninstall_type = Structs.Extras.InstallType.github;
        if (install_args.gitlab) _uninstall_type = Structs.Extras.InstallType.gitlab;
        if (install_args.codeberg) _uninstall_type = Structs.Extras.InstallType.codeberg;
        if (install_args.local) _uninstall_type = Structs.Extras.InstallType.local;

        if (_uninstall_type == null) {
            try ctx.printer.append(
                "WARNING: For global uninstalls, a namespace is required.\n\n",
                .{},
                .{ .color = .red },
            );
            return;
        }

        const uninstall_type = _uninstall_type orelse .zep;

        var package = Package.init(
            ctx,
            package_name,
            package_version,
            uninstall_type,
        ) catch |err| {
            switch (err) {
                error.PackageNotFound => {
                    try ctx.printer.append(
                        "{s}@{s} is not on {s}!\nMaybe you forgot to include the author (author/repo)?\n\n",
                        .{ package_name, package_version orelse "latest", @tagName(uninstall_type) },
                        .{ .color = .red },
                    );
                },
                else => {
                    try ctx.printer.append("Something went wrong...\n\n", .{}, .{ .color = .red });
                },
            }
            return;
        };
        defer package.deinit();

        package.uninstallFromDisk(uninstall_args.force) catch |err| {
            switch (err) {
                error.InUse => {
                    try ctx.printer.append("WARNING: Atleast 1 project is using {s}. Uninstalling it globally now might have serious consequences.\n\n", .{package_query}, .{ .color = .red });
                    try ctx.printer.append("If you do not care, run\n $ zep uninstall [target]@[version] -G -F\n\n", .{}, .{ .color = .yellow });
                },
                error.NotInstalled => {
                    try ctx.printer.append("{s} is not installed\n\n", .{package_query}, .{ .color = .red });
                    return;
                },
                else => {
                    try ctx.printer.append("Uninstalling failed.\n\n", .{}, .{ .color = .red });
                    return;
                },
            }
        };
        if (uninstall_args.force) {
            try ctx.printer.append(
                "{s} package deleted, consequences ignored.\n\n",
                .{package_query},
                .{ .color = .green },
            );
        }
        return;
    }

    var uninstaller = Uninstaller.init(ctx);
    defer uninstaller.deinit();

    uninstaller.uninstall(package_name) catch |err| {
        switch (err) {
            error.NotInstalled => {
                try ctx.printer.append(
                    "{s} is not installed in this project.\n",
                    .{package_name},
                    .{ .color = .red },
                );
                try ctx.printer.append(
                    "To uninstall globally, run\n  $ zep uninstall {s}@<version> -G\n\n",
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
