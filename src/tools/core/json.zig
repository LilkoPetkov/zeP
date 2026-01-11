const std = @import("std");

pub const Json = @This();

const Logger = @import("logger");
const Constants = @import("constants");
const Structs = @import("structs");

const Fs = @import("io").Fs;
const Manifest = @import("manifest.zig");

pub fn parseJsonFromFile(
    allocator: std.mem.Allocator,
    comptime T: type,
    path: []const u8,
    max: usize,
) !std.json.Parsed(T) {
    if (!Fs.existsFile(path)) {
        return error.FileNotFound;
    }

    var file = try Fs.openFile(path);
    defer file.close();

    const data = try file.readToEndAlloc(allocator, max);
    defer allocator.free(data);

    const parsed = try std.json.parseFromSlice(
        T,
        allocator,
        data,
        .{ .allocate = .alloc_always },
    );
    return parsed;
}

pub fn writePretty(
    allocator: std.mem.Allocator,
    path: []const u8,
    data: anytype,
) !void {
    const str = try std.json.Stringify.valueAlloc(
        allocator,
        data,
        .{ .whitespace = .indent_2 },
    );

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    _ = try file.write(str);
}
