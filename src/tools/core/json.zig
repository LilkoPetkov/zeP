const std = @import("std");

pub const Json = @This();

const Logger = @import("logger");
const Constants = @import("constants");
const Structs = @import("structs");

const Fs = @import("io").Fs;
const Manifest = @import("manifest.zig");

/// Simple Json parsing and
/// writing into files.
allocator: std.mem.Allocator,
paths: Constants.Paths.Paths,

pub fn init(
    allocator: std.mem.Allocator,
    paths: Constants.Paths.Paths,
) Json {
    return Json{
        .allocator = allocator,
        .paths = paths,
    };
}

pub fn parseJsonFromFile(
    self: *Json,
    comptime T: type,
    path: []const u8,
    max: usize,
) !std.json.Parsed(T) {
    if (!Fs.existsFile(path)) {
        return error.FileNotFound;
    }

    var file = try Fs.openFile(path);
    defer file.close();

    const data = try file.readToEndAlloc(self.allocator, max);
    const parsed = try std.json.parseFromSlice(T, self.allocator, data, .{});
    return parsed;
}

pub fn writePretty(
    self: *Json,
    path: []const u8,
    data: anytype,
) !void {
    const str = try std.json.Stringify.valueAlloc(
        self.allocator,
        data,
        .{ .whitespace = .indent_2 },
    );

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    _ = try file.write(str);
}
