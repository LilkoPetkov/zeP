const std = @import("std");

const Auth = @import("../../lib/cloud/auth.zig");
const Context = @import("context");

fn authLogin(_: *Context, auth: *Auth) !void {
    try auth.login();
    return;
}

fn authRegister(_: *Context, auth: *Auth) !void {
    try auth.register();
    return;
}

fn authLogout(_: *Context, auth: *Auth) !void {
    try auth.logout();
}

pub fn _authController(ctx: *Context) !void {
    if (ctx.args.len < 3) return error.MissingSubcommand;

    var auth = try Auth.init(ctx);
    const arg = ctx.args[2];
    if (std.mem.eql(u8, arg, "login"))
        try authLogin(ctx, &auth);

    if (std.mem.eql(u8, arg, "register"))
        try authRegister(ctx, &auth);

    if (std.mem.eql(u8, arg, "logout"))
        try authLogout(ctx, &auth);
}
