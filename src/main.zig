const std = @import("std");

const Zep = @import("zep.zig");
const Controller = @import("controller/controller.zig");
const Locales = @import("locales");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    // start
    var context = Zep.start(arena.allocator()) catch |err| {
        std.debug.print("Starting zeP has failed.\nWith Error: {any}\n\n", .{err});
        return;
    };
    defer context.deinit();

    Controller._controller(&context) catch |err| {
        std.debug.print("Controller has failed.\nWith Error: {any}\n\n", .{err});
        return;
    };
}
