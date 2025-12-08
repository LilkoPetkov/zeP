const std = @import("std");
const Structs = @import("structs");
const Locales = @import("locales");

const AppendOptions = struct {
    verbosity: u8 = 1,
    color: u8 = 0,
};

/// Handles Cleaner printing and interactivity.
pub const Printer = struct {
    data: std.ArrayList(Structs.Extras.PrinterData),
    allocator: std.mem.Allocator,

    pub fn init(data: std.ArrayList(Structs.Extras.PrinterData), allocator: std.mem.Allocator) Printer {
        return Printer{ .data = data, .allocator = allocator };
    }

    pub fn deinit(self: *Printer) void {
        for (self.data.items) |d| {
            self.allocator.free(d.data);
        }
        self.data.deinit();
    }

    pub fn append(self: *Printer, comptime fmt: []const u8, args: anytype, options: AppendOptions) !void {
        if (options.verbosity > Locales.VERBOSITY_MODE) return;
        const data = try std.fmt.allocPrint(self.allocator, fmt, args);
        try self.data.append(Structs.Extras.PrinterData{ .data = data, .verbosity = options.verbosity, .color = options.color });
        try self.print();
        return;
    }

    pub fn pop(self: *Printer, pop_amount: u8) void {
        const amount = pop_amount;
        for (0..amount) |_| {
            const n = self.data.pop();
            if (n == null) break;
        }
        return;
    }

    pub fn clearScreen(self: *Printer) !void {
        if (self.data.items.len < 2) return;
        const stdout = std.io.getStdOut().writer();

        var count: u16 = 0;
        for (0..self.data.items.len - 1) |i| {
            const data = self.data.items[i];
            const d = data.data;
            var small_count: usize = 0;
            for (d) |c| {
                if (c == '\n') small_count += 1;
            }
            count += @intCast(small_count);
        }

        // Moves the cursor up by the amount
        // of \n within the .data
        try stdout.print("\x1b[{d}A", .{count});
        for (0..count) |_| {
            try stdout.print("\x1b[2K\r", .{}); // Clear line
            try stdout.print("\x1b[1E", .{}); // Move cursor down 1 line
        }
        // Move cursor back up, to keep printing where we
        // left off
        try stdout.print("\x1b[{d}A", .{count});
    }

    pub fn print(self: *Printer) !void {
        try self.clearScreen();
        for (self.data.items) |d| {
            std.debug.print("\x1b[{d}m{s}\x1b[0m", .{ d.color, d.data });
        }
        return;
    }
};
