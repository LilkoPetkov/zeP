const std = @import("std");

const Cache = @import("../../lib/functions/cache.zig");
const Context = @import("context");

fn cacheClean(ctx: *Context, cache: *Cache) !void {
    const cache_name = if (ctx.args.len < 4) null else ctx.args[3];
    try cache.clean(cache_name);
    return;
}

fn cacheSize(_: *Context, cache: *Cache) !void {
    try cache.size();
    return;
}

fn cacheList(_: *Context, cache: *Cache) !void {
    try cache.list();
    return;
}

pub fn _cacheController(ctx: *Context) !void {
    if (ctx.args.len < 3) return error.MissingSubcommand;

    var cache = try Cache.init(ctx);
    defer cache.deinit();

    const arg = ctx.args[2];
    if (std.mem.eql(u8, arg, "size"))
        try cacheSize(ctx, &cache);
    if (std.mem.eql(u8, arg, "clean"))
        try cacheClean(ctx, &cache);
    if (std.mem.eql(u8, arg, "list") or
        std.mem.eql(u8, arg, "ls"))
        try cacheList(ctx, &cache);
}
