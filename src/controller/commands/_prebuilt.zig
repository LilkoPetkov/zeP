const std = @import("std");

const PreBuilt = @import("../../lib/functions/pre_built.zig");
const Lister = @import("../../lib/packages/list.zig");

const Context = @import("context");

fn prebuiltBuild(ctx: *Context, prebuilt: *PreBuilt) !void {
    if (ctx.args.len < 4) return error.MissingArguments;

    const name = ctx.args[3];
    const default_target = ".";
    const target = if (ctx.args.len < 5) default_target else ctx.args[4];
    prebuilt.build(name, target) catch {
        try ctx.printer.append("\nBuilding prebuilt has failed...\n\n", .{}, .{ .color = .red });
    };
    return;
}

fn prebuiltUse(ctx: *Context, prebuilt: *PreBuilt) !void {
    if (ctx.args.len < 4) return error.MissingArguments;

    const name = ctx.args[3];
    const default_target = ".";
    const target = if (ctx.args.len < 5) default_target else ctx.args[4];
    prebuilt.use(name, target) catch {
        try ctx.printer.append("\nUse prebuilt has failed...\n\n", .{}, .{ .color = .red });
    };
    return;
}

fn prebuiltList(ctx: *Context, prebuilt: *PreBuilt) !void {
    prebuilt.list() catch {
        try ctx.printer.append("\nListing prebuilts failed...\n\n", .{}, .{ .color = .red });
    };
    return;
}

fn prebuiltDelete(ctx: *Context, prebuilt: *PreBuilt) !void {
    if (ctx.args.len < 4) return error.MissingArguments;

    const name = ctx.args[3];
    prebuilt.delete(name) catch {
        try ctx.printer.append("\nDeleting prebuilt has failed...\n\n", .{}, .{ .color = .red });
    };
    return;
}

pub fn _prebuiltController(ctx: *Context) !void {
    if (ctx.args.len < 3) return error.PreBuiltMissingSubcommand;

    var prebuilt = try PreBuilt.init(ctx);

    const arg = ctx.args[2];
    if (std.mem.eql(u8, arg, "build"))
        try prebuiltBuild(ctx, &prebuilt);

    if (std.mem.eql(u8, arg, "delete"))
        try prebuiltDelete(ctx, &prebuilt);

    if (std.mem.eql(u8, arg, "use"))
        try prebuiltUse(ctx, &prebuilt);

    if (std.mem.eql(u8, arg, "list") or
        std.mem.eql(u8, arg, "ls"))
        try prebuiltList(ctx, &prebuilt);
}
