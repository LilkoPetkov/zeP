const std = @import("std");

const Auth = @import("../../lib/cloud/auth.zig");
const Context = @import("context");

fn authLogin(ctx: *Context, auth: *Auth) !void {
    auth.login() catch |err| {
        switch (err) {
            error.InvalidPassword => {
                try ctx.logger.@"error"("Invalid Password", @src());
                try ctx.printer.append("Invalid password.\n", .{}, .{});
            },
            error.AlreadyAuthed => {
                try ctx.logger.@"error"("Already Authenticated", @src());
                try ctx.printer.append(
                    "Already authenticated.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            error.FetchFailed => {
                try ctx.logger.@"error"("Fetching Login Failed", @src());
                try ctx.printer.append(
                    "Fetching login failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            else => {
                try ctx.logger.@"error"("Login Failed", @src());
                try ctx.printer.append(
                    "Login failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
        }
    };
    return;
}

fn authRegister(ctx: *Context, auth: *Auth) !void {
    auth.register() catch |err| {
        switch (err) {
            error.AlreadyAuthed => {
                try ctx.logger.@"error"("Already Authenticated", @src());
                try ctx.printer.append(
                    "Already authenticated.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            error.FetchFailed => {
                try ctx.logger.@"error"("Fetching Register Failed", @src());
                try ctx.printer.append(
                    "Fetching Register failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            else => {
                try ctx.logger.@"error"("Registering Failed", @src());
                try ctx.printer.append(
                    "Registering failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
        }
    };
    return;
}

fn authLogout(ctx: *Context, auth: *Auth) !void {
    auth.logout() catch |err| {
        switch (err) {
            error.NotAuthed => {
                try ctx.logger.@"error"("Not Authenticated", @src());
                try ctx.printer.append(
                    "Not authenticated.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            error.FetchFailed => {
                try ctx.logger.@"error"("Fetch Failed", @src());
                try ctx.printer.append(
                    "Fetching logout failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            else => {
                try ctx.printer.append(
                    "Logout failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
        }
    };
}

pub fn _authController(ctx: *Context) !void {
    if (ctx.args.len < 3) return error.AuthInvalidSubcommand;

    var auth = try Auth.init(ctx);
    const arg = ctx.args[2];
    if (std.mem.eql(u8, arg, "login")) {
        try authLogin(ctx, &auth);
    } else if (std.mem.eql(u8, arg, "register")) {
        try authRegister(ctx, &auth);
    } else if (std.mem.eql(u8, arg, "logout")) {
        try authLogout(ctx, &auth);
    } else {
        return error.AuthInvalidCommand;
    }
}
