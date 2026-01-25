const std = @import("std");

const Cache = @import("../../lib/functions/cache.zig");
const Context = @import("context");

fn cacheClean(ctx: *Context, cache: *Cache) !void {
    const cache_name = if (ctx.cmds.len < 4) null else ctx.cmds[3];
    try cache.cleanAll(cache_name);
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
    if (ctx.cmds.len < 3) return error.CacheInvalidSubcommand;

    var cache = try Cache.init(ctx);
    defer cache.deinit();

    const arg = ctx.cmds[2];
    if (std.mem.eql(u8, arg, "size")) {
        try cacheSize(ctx, &cache);
    } else if (std.mem.eql(u8, arg, "clean")) {
        try cacheClean(ctx, &cache);
    } else if (std.mem.eql(u8, arg, "list") or
        std.mem.eql(u8, arg, "ls"))
    {
        try cacheList(ctx, &cache);
    } else {
        return error.CacheInvalidSubcommand;
    }
}
