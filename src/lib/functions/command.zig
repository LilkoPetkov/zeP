const std = @import("std");
const builtin = @import("builtin");

pub const Command = @This();

const Structs = @import("structs");
const Constants = @import("constants");

const Printer = @import("cli").Printer;
const Prompt = @import("cli").Prompt;
const Fs = @import("io").Fs;
const Manifest = @import("core").Manifest;

const Context = @import("context");

ctx: *Context,

pub fn init(ctx: *Context) !Command {
    if (!Fs.existsFile(Constants.Extras.package_files.lock)) {
        try ctx.printer.append("\nNo zep.lock file!\n", .{}, .{ .color = .red });
        return error.ManifestNotFound;
    }

    return Command{
        .ctx = ctx,
    };
}

pub fn add(self: *Command) !void {
    try self.ctx.logger.info("Adding Command", @src());

    var lock = try self.ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Extras.package_files.lock,
    );
    defer lock.deinit();

    var cmds = try std.ArrayList(Structs.ZepFiles.Command).initCapacity(self.ctx.allocator, 10);
    defer cmds.deinit(
        self.ctx.allocator,
    );

    try self.ctx.printer.append("Command:\n\n", .{}, .{
        .color = .yellow,
        .weight = .bold,
    });

    const command_name = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        "> *Command Name: ",
        .{
            .required = true,
        },
    );
    defer self.ctx.allocator.free(command_name);
    for (lock.value.root.cmd) |c| {
        if (std.mem.eql(u8, c.name, command_name)) {
            try self.ctx.printer.append("\nCommand already exists! Overwrite? (y/N)", .{}, .{
                .color = .red,
                .weight = .bold,
            });

            const answer = try Prompt.input(
                self.ctx.allocator,
                &self.ctx.printer,
                "",
                .{},
            );
            if (answer.len == 0 or
                (!std.mem.startsWith(u8, answer, "y") and
                    !std.mem.startsWith(u8, answer, "Y")))
            {
                try self.ctx.printer.append("\nOk.\n", .{}, .{});
                return;
            }

            try self.ctx.logger.info("Overwriting old command...", @src());
            try self.ctx.printer.append("Overwriting...\n\n", .{}, .{
                .color = .white,
                .weight = .bold,
            });

            continue;
        }
        try cmds.append(self.ctx.allocator, c);
    }

    const command = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        "> *Command: ",
        .{
            .required = true,
        },
    );
    defer self.ctx.allocator.free(command);

    const new_command = Structs.ZepFiles.Command{ .cmd = command, .name = command_name };
    try cmds.append(self.ctx.allocator, new_command);

    lock.value.root.cmd = cmds.items;
    try self.ctx.manifest.writeManifest(
        Structs.ZepFiles.Lock,
        Constants.Extras.package_files.lock,
        lock.value,
    );

    try self.ctx.printer.append("Successfully added command!\n\n", .{}, .{ .color = .green });
    return;
}

pub fn list(self: *Command) !void {
    try self.ctx.logger.info("Listing Commands", @src());

    var lock = try self.ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Extras.package_files.lock,
    );
    defer lock.deinit();

    for (lock.value.root.cmd) |c| {
        try self.ctx.printer.append("- Command Name: {s}\n  $ {s}\n\n", .{ c.name, c.cmd }, .{});
    }
    return;
}

pub fn remove(self: *Command, key: []const u8) !void {
    try self.ctx.logger.infof("Removing Command {s}", .{key}, @src());

    var lock = try self.ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Extras.package_files.lock,
    );
    defer lock.deinit();

    var cmds = try std.ArrayList(Structs.ZepFiles.Command).initCapacity(self.ctx.allocator, 5);
    defer cmds.deinit(
        self.ctx.allocator,
    );
    for (lock.value.root.cmd) |c| {
        if (std.mem.eql(u8, c.name, key)) continue;
        try cmds.append(self.ctx.allocator, c);
    }
    lock.value.root.cmd = cmds.items;
    try self.ctx.manifest.writeManifest(
        Structs.ZepFiles.Lock,
        Constants.Extras.package_files.lock,
        lock.value,
    );

    try self.ctx.printer.append("Successfully removed command!\n\n", .{}, .{ .color = .green });
    return;
}

pub fn run(self: *Command, key: []const u8) !void {
    try self.ctx.logger.infof("Running Command {s}", .{key}, @src());

    const lock = try self.ctx.manifest.readManifest(
        Structs.ZepFiles.Lock,
        Constants.Extras.package_files.lock,
    );
    defer lock.deinit();

    for (lock.value.root.cmd) |c| {
        if (std.mem.eql(u8, c.name, key)) {
            try self.ctx.printer.append("Command was found!\n", .{}, .{ .color = .green });
            var args = try std.ArrayList([]const u8).initCapacity(self.ctx.allocator, 5);
            defer args.deinit(self.ctx.allocator);
            var split = std.mem.splitAny(u8, c.cmd, " ");
            while (split.next()) |arg| {
                try args.append(self.ctx.allocator, arg);
            }
            try self.ctx.printer.append("Executing:\n $ {s}\n\n", .{c.cmd}, .{ .color = .green });
            var exec_cmd = std.process.Child.init(args.items, self.ctx.allocator);
            _ = exec_cmd.spawnAndWait() catch {};

            try self.ctx.printer.append("\nFinished executing!\n", .{}, .{ .color = .green });
            return;
        }
        continue;
    }
    try self.ctx.printer.append("\nCommand not found!\n", .{}, .{ .color = .red });
    return;
}
