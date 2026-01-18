const std = @import("std");

const Custom = @import("../../lib/packages/custom.zig");

const Context = @import("context");

fn customAdd(ctx: *Context) !void {
    var custom = Custom.init(ctx);
    try custom.requestPackage();
    return;
}

fn customRemove(ctx: *Context) !void {
    if (ctx.args.len < 4) return error.PackageMissingArguments;
    const package = ctx.args[3];
    var custom = Custom.init(ctx);
    try custom.removePackage(package);
    return;
}

pub fn _customController(ctx: *Context) !void {
    if (ctx.args.len < 3) return error.CustomInvalidSubcommand;

    const arg = ctx.args[2];
    if (std.mem.eql(u8, arg, "add")) {
        try customAdd(ctx);
    } else if (std.mem.eql(u8, arg, "remove")) {
        try customRemove(ctx);
    } else {
        return error.CustomInvalidSubcommand;
    }
}
