const std = @import("std");

const Runner = @import("../../lib/functions/runner.zig");
const Context = @import("context");
const Args = @import("args");

fn runner(ctx: *Context) !void {
    const runner_args = Args.parseRunner(ctx.args);
    var args = try std.ArrayList([]const u8).initCapacity(ctx.allocator, 5);
    defer args.deinit(ctx.allocator);
    var split_args = std.mem.splitAny(u8, runner_args.args, ",");
    while (split_args.next()) |p| {
        try args.append(ctx.allocator, p);
    }

    var r = Runner.init(ctx);
    try r.run(runner_args.target, args.items);
    return;
}

pub fn _runnerController(ctx: *Context) !void {
    try runner(ctx);
}
