const std = @import("std");

const Upgrader = @import("../../lib/packages/upgrade.zig");

const Context = @import("context");
const Args = @import("args");

fn upgrade(ctx: *Context) !void {
    var upgade = Upgrader.init(ctx);
    upgade.upgrade() catch |err| {
        try ctx.logger.errorf("Upgrading All Failed error={any}", .{err}, @src());

        switch (err) {
            error.HashMismatch => {
                try ctx.printer.append("\n  ! HASH MISMATCH!\nPLEASE REPORT!\n\n", .{}, .{ .color = .red });
            },
            else => {
                try ctx.printer.append("\nUpgrading all has failed...\n\n", .{}, .{ .color = .red });
            },
        }
    };
    return;
}

pub fn _upgradeController(ctx: *Context) !void {
    try upgrade(ctx);
}
