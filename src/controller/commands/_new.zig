const std = @import("std");

const New = @import("../../lib/functions/new.zig");

const Context = @import("context");

fn new(ctx: *Context) !void {
    if (ctx.cmds.len < 3) return error.NewMissingArguments;
    const name = ctx.cmds[2];
    try New.new(ctx, name);
    return;
}

pub fn _newController(ctx: *Context) !void {
    try new(ctx);
}
