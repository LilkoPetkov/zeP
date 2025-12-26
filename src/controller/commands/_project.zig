const std = @import("std");

const Project = @import("../../lib/cloud/project.zig");

const Context = @import("context");
fn projectCreate(ctx: *Context, project: *Project) !void {
    project.create() catch |err| {
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
                    "Fetching project create failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            else => {
                try ctx.printer.append(
                    "Creating project failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
        }
    };
    return;
}

fn projectList(ctx: *Context, project: *Project) !void {
    project.list() catch |err| {
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
                    "Fetching projects failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },

            else => {
                try ctx.printer.append(
                    "Listing project failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
        }
    };
    return;
}

fn projectDelete(ctx: *Context, project: *Project) !void {
    project.delete() catch |err| {
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
                    "Fetching project delete failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            error.NotFound => {
                try ctx.printer.append(
                    "Project not found.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
            else => {
                try ctx.printer.append(
                    "Deleting project failed.\n",
                    .{},
                    .{ .color = .bright_red },
                );
            },
        }
    };
    return;
}

pub fn _projectController(ctx: *Context) !void {
    if (ctx.args.len < 3) return error.MissingSubcommand;

    var project = Project.init(ctx);

    const arg = ctx.args[2];
    if (std.mem.eql(u8, arg, "create"))
        try projectCreate(ctx, &project);

    if (std.mem.eql(u8, arg, "list") or
        std.mem.eql(u8, arg, "ls"))
        try projectList(ctx, &project);

    if (std.mem.eql(u8, arg, "delete"))
        try projectDelete(ctx, &project);
}
