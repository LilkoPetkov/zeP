const std = @import("std");

const Package = @import("package");
const Context = @import("context");
const Structs = @import("structs");
const Args = @import("args");

fn info(ctx: *Context) !void {
    if (ctx.cmds.len < 3) return error.InfoMissingArguments;

    const package_id = ctx.cmds[2];
    var split = std.mem.splitScalar(u8, package_id, '@');
    const package_name = split.first();
    const package_version = split.next();

    const install_args = Args.parseInstall(ctx.options);
    var install_type: Structs.Extras.InstallType = .zep;
    if (install_args.zep) install_type = Structs.Extras.InstallType.zep;
    if (install_args.github) install_type = Structs.Extras.InstallType.github;
    if (install_args.gitlab) install_type = Structs.Extras.InstallType.gitlab;
    if (install_args.codeberg) install_type = Structs.Extras.InstallType.codeberg;
    if (install_args.local) install_type = Structs.Extras.InstallType.local;

    var package = try Package.init(
        ctx,
        package_name,
        package_version,
        install_type,
    );
    defer package.deinit();

    try ctx.printer.append("Package Name: {s}\n", .{package.package.name}, .{});
    try ctx.printer.append("Version: {s}\n", .{package.package.version}, .{});
    try ctx.printer.append("Hash: {s}\n", .{package.package.hash}, .{});
    try ctx.printer.append("Source: {s}\n", .{package.package.source}, .{});
    try ctx.printer.append("Zig Version: {s}\n\n", .{package.package.zig_version}, .{});
}

pub fn _infoController(ctx: *Context) !void {
    try info(ctx);
}
