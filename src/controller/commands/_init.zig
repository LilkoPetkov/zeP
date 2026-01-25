const std = @import("std");

const Init = @import("../../lib/packages/init.zig");

const Context = @import("context");

fn init(ctx: *Context) !void {
    var i = try Init.init(ctx, false);
    try i._init();
    return;
}

pub fn _initController(ctx: *Context) !void {
    try init(ctx);
}
