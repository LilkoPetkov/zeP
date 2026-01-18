const std = @import("std");

const Package = @import("../../lib/cloud/package.zig");

const Context = @import("context");
fn packageCreate(ctx: *Context, package: *Package) !void {
    package.create() catch |err| {
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
                try ctx.logger.@"error"("Fetching Create Package Failed", @src());
                try ctx.printer.append(
                    "Fetching package create failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            else => {
                try ctx.logger.@"error"("Creating Package Failed", @src());
                try ctx.printer.append(
                    "Creating package failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
        }
    };
    return;
}

fn packageList(ctx: *Context, package: *Package) !void {
    package.list() catch |err| {
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
                try ctx.logger.@"error"("Fetching Packages Failed", @src());
                try ctx.printer.append(
                    "Fetching packages failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },

            else => {
                try ctx.logger.@"error"("Listing Packages Failed", @src());
                try ctx.printer.append(
                    "Listing package failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
        }
    };
    return;
}

fn packageDelete(ctx: *Context, package: *Package) !void {
    package.delete() catch |err| {
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
                try ctx.logger.@"error"("Fetching Delete Failed", @src());
                try ctx.printer.append(
                    "Fetching package delete failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            error.NotFound => {
                try ctx.logger.@"error"("Package Not Found", @src());
                try ctx.printer.append(
                    "Package not found.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            else => {
                try ctx.logger.@"error"("Deleting Package Failed", @src());
                try ctx.printer.append(
                    "Deleting package failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
        }
    };
    return;
}

pub fn _packageController(ctx: *Context) !void {
    if (ctx.args.len < 3) return error.PackageInvalidSubcommand;

    var package = Package.init(ctx);

    const arg = ctx.args[2];
    if (std.mem.eql(u8, arg, "create")) {
        try packageCreate(ctx, &package);
    } else if (std.mem.eql(u8, arg, "list") or
        std.mem.eql(u8, arg, "ls"))
    {
        try packageList(ctx, &package);
    } else if (std.mem.eql(u8, arg, "delete")) {
        try packageDelete(ctx, &package);
    } else {
        return error.PackagerInvalidSubcommand;
    }
}
