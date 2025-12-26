const std = @import("std");

const Release = @import("../../lib/cloud/release.zig");

const Context = @import("context");
fn releaseCreate(ctx: *Context, release: *Release) !void {
    release.create() catch |err| {
        switch (err) {
            error.NotAuthed => {
                try ctx.printer.append(
                    "Not authenticated.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            error.FetchFailed => {
                try ctx.printer.append(
                    "Fetching release create failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            else => {
                try ctx.printer.append(
                    "Creating release failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
        }
    };
    return;
}

fn releaseList(ctx: *Context, release: *Release) !void {
    release.list() catch |err| {
        switch (err) {
            error.NotAuthed => {
                try ctx.printer.append(
                    "Not authenticated.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            error.FetchFailed => {
                try ctx.printer.append(
                    "Fetching releases failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            else => {
                try ctx.printer.append(
                    "Listing release failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
        }
    };
    return;
}

fn releaseDelete(ctx: *Context, release: *Release) !void {
    release.delete() catch |err| {
        switch (err) {
            error.NotAuthed => {
                try ctx.printer.append(
                    "Not authenticated.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            error.FetchFailed => {
                try ctx.printer.append(
                    "Fetching release delete failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            error.NotFound => {
                try ctx.printer.append(
                    "Release not found.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            else => {
                try ctx.printer.append(
                    "Deleting release failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
        }
    };
    return;
}

pub fn _releaseController(ctx: *Context) !void {
    if (ctx.args.len < 3) return error.MissingSubcommand;

    var release = Release.init(ctx);
    const arg = ctx.args[2];
    if (std.mem.eql(u8, arg, "create"))
        try releaseCreate(ctx, &release);

    if (std.mem.eql(u8, arg, "list") or
        std.mem.eql(u8, arg, "ls"))
        try releaseList(ctx, &release);

    if (std.mem.eql(u8, arg, "delete"))
        try releaseDelete(ctx, &release);
}
