const std = @import("std");

const PackageFiles = @import("../../lib/functions/package_files.zig");

const Context = @import("context");

fn manifestSync(_: *Context, pf: *PackageFiles) !void {
    try pf.sync();
    return;
}

fn manifestModify(_: *Context, pf: *PackageFiles) !void {
    try pf.modify();
    try pf.sync();
    return;
}

pub fn _manifestController(ctx: *Context) !void {
    if (ctx.args.len < 3) return error.ManifestInvalidSubcommand;

    var package_files = try PackageFiles.init(ctx);
    const arg = ctx.args[2];

    if (std.mem.eql(u8, arg, "sync")) {
        try manifestSync(ctx, &package_files);
    } else if (std.mem.eql(u8, arg, "modify")) {
        try manifestModify(ctx, &package_files);
    } else {
        return error.ManifestInvalidSubcommand;
    }
}
