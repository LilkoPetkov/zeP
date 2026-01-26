const std = @import("std");

const Package = @import("package");
const Context = @import("context");

fn info(ctx: *Context) !void {
    if (ctx.cmds.len < 3) return error.InfoMissingArguments;

    const package_id = ctx.cmds[2];
    var split = std.mem.splitScalar(u8, package_id, '@');
    const package_name = split.first();
    const package_version = split.next();
    var package = try Package.init(
        ctx,
        package_name,
        package_version,
    );
    defer package.deinit();

    try ctx.printer.append("Package Name: {s}\n", .{package_name}, .{});
    try ctx.printer.append("Version: {s}\n", .{package.package_version}, .{});
    try ctx.printer.append("Hash: {s}\n", .{package.package.hash}, .{});
    try ctx.printer.append("Source: {s}\n", .{package.package.source}, .{});
    try ctx.printer.append("Root File: {s}\n", .{package.package.root_file}, .{});
    try ctx.printer.append("Zig Version: {s}\n\n", .{package.package.zig_version}, .{});
}

pub fn _infoController(ctx: *Context) !void {
    try info(ctx);
}
