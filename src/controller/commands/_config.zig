const std = @import("std");

const PackageFiles = @import("../../lib/functions/package_files.zig");

const Context = @import("context");

fn config(_: *Context, pf: *PackageFiles) !void {
    try pf.modify();
    return;
}

pub fn _configController(ctx: *Context) !void {
    if (ctx.args.len < 3) return error.ManifestInvalidSubcommand;
    var package_files = try PackageFiles.init(ctx);
    try config(ctx, &package_files);
}
