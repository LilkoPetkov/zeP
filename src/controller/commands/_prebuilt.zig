const std = @import("std");

const PreBuilt = @import("../../lib/functions/pre_built.zig");
const Lister = @import("../../lib/packages/list.zig");

const Context = @import("context");

fn prebuiltBuild(ctx: *Context, prebuilt: *PreBuilt) !void {
    if (ctx.cmds.len < 4) return error.MissingArguments;

    const name = ctx.cmds[3];
    const target = if (ctx.cmds.len < 5) "." else ctx.cmds[4];
    prebuilt.build(name, target) catch {
        try ctx.printer.append("\nBuilding prebuilt has failed...\n\n", .{}, .{ .color = .red });
    };
    return;
}

fn prebuiltUse(ctx: *Context, prebuilt: *PreBuilt) !void {
    if (ctx.cmds.len < 4) return error.MissingArguments;

    const name = ctx.cmds[3];
    const target = if (ctx.cmds.len < 5) "." else ctx.cmds[4];
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
    if (ctx.cmds.len < 4) return error.MissingArguments;

    const name = ctx.cmds[3];
    prebuilt.delete(name) catch {
        try ctx.printer.append("\nDeleting prebuilt has failed...\n\n", .{}, .{ .color = .red });
    };
    return;
}

pub fn _prebuiltController(ctx: *Context) !void {
    if (ctx.cmds.len < 3) return error.PreBuiltInvalidSubcommand;

    var prebuilt = try PreBuilt.init(ctx);

    const arg = ctx.cmds[2];
    if (std.mem.eql(u8, arg, "build")) {
        try prebuiltBuild(ctx, &prebuilt);
    } else if (std.mem.eql(u8, arg, "delete")) {
        try prebuiltDelete(ctx, &prebuilt);
    } else if (std.mem.eql(u8, arg, "use")) {
        try prebuiltUse(ctx, &prebuilt);
    } else if (std.mem.eql(u8, arg, "list") or
        std.mem.eql(u8, arg, "ls"))
    {
        try prebuiltList(ctx, &prebuilt);
    } else {
        return error.PreBuiltInvalidSubcommand;
    }
}
