const std = @import("std");

const Injector = @import("core").Injector;

const Context = @import("context");

fn inject(ctx: *Context) !void {
    try ctx.injector.initInjector(true);
    return;
}

pub fn _injectController(ctx: *Context) !void {
    try inject(ctx);
}
