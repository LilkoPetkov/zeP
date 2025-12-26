const std = @import("std");

const Bootstrap = @import("../../lib/functions/bootstrap.zig");

const Context = @import("context");
const Args = @import("args");

fn bootstrap(ctx: *Context) !void {
    const bootstrap_args = try Args.parseBootstrap();
    try Bootstrap.bootstrap(ctx, bootstrap_args.zig, bootstrap_args.deps);
    return;
}

pub fn _bootstrapController(ctx: *Context) !void {
    try bootstrap(ctx);
}
