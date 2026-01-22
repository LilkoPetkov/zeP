const std = @import("std");

const Package = @import("core").Package;
const Context = @import("context");

fn info(ctx: *Context) !void {
    if (ctx.cmds.len < 3) return error.InfoMissingArguments;

    const package_id = ctx.cmds[2];
    var split = std.mem.splitScalar(u8, package_id, '@');
    const package_name = split.first();
    const package_version = split.next();
    var package = try Package.init(
        ctx.allocator,
        &ctx.printer,
        &ctx.fetcher,
        ctx.logger,
        package_name,
        package_version,
    );
    defer package.deinit();

    std.debug.print("Package Name: {s}\n", .{package_name});
    std.debug.print("Version: {s}\n", .{package.package.version});
    std.debug.print("Sha256Sum: {s}\n", .{package.package.sha256sum});
    std.debug.print("Url: {s}\n", .{package.package.url});
    std.debug.print("Root File: {s}\n", .{package.package.root_file});
    std.debug.print("Zig Version: {s}\n", .{package.package.zig_version});
    std.debug.print("\n", .{});
}

pub fn _infoController(ctx: *Context) !void {
    try info(ctx);
}
