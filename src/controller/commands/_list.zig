const std = @import("std");

const Lister = @import("../../lib/packages/list.zig");
const Context = @import("context");

fn list(ctx: *Context) !void {
    if (ctx.cmds.len < 3) return error.ListMissingArguments;

    const package = ctx.cmds[2];
    var split = std.mem.splitScalar(u8, package, '@');
    const package_name = split.first();
    Lister.list(ctx, package_name) catch |err| {
        switch (err) {
            error.PackageNotFound => {
                try ctx.printer.append("Package not found...\n\n", .{}, .{ .color = .red });
                return;
            },
            else => {
                try ctx.printer.append("\nListing {s} has failed...\n\n", .{package_name}, .{ .color = .red });
            },
        }
    };
}

pub fn _listController(ctx: *Context) !void {
    try list(ctx);
}
