const std = @import("std");

const Constants = @import("constants");
const Context = @import("context");
const Locales = @import("locales");

fn version(ctx: *Context) !void {
    if (Locales.VERBOSITY_MODE <= 1) {
        try ctx.printer.append(
            "{s}",
            .{Constants.Default.version},
            .{},
        );
    } else {
        try ctx.printer.append(
            "{s}+{s}",
            .{ Constants.Default.version, Constants.Default.commit },
            .{},
        );
    }

    return;
}

pub fn _versionController(ctx: *Context) !void {
    try version(ctx);
}
