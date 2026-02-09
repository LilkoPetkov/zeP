const std = @import("std");

const Injector = @import("core").Injector;

const Context = @import("context");

fn inject(ctx: *Context) !void {
    var injector = Injector.init(
        ctx.allocator,
        ctx.manifest,
        &ctx.printer,
    );
    try injector.initInjector(true);
    return;
}

pub fn _injectController(ctx: *Context) !void {
    try inject(ctx);
}
