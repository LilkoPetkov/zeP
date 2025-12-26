const std = @import("std");

const Auth = @import("../../lib/cloud/auth.zig");
const Context = @import("context");

fn whoami(ctx: *Context) !void {
    var auth = try Auth.init(ctx);
    try auth.whoami();
    return;
}

pub fn _whoamiController(ctx: *Context) !void {
    try whoami(ctx);
}
