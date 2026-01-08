const std = @import("std");

const Runner = @import("../../lib/functions/runner.zig");
const Context = @import("context");
const Args = @import("args");

fn runner(ctx: *Context) !void {
    const runner_args = try Args.parseRunner();

    var r = Runner.init(ctx);
    try r.run(runner_args.target, runner_args.args);
    return;
}

pub fn _runnerController(ctx: *Context) !void {
    try runner(ctx);
}
