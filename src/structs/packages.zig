const std = @import("std");

pub const Version = struct {
    version: []const u8,
    url: []const u8,
    zig_version: []const u8,
    root_file: []const u8,
    sha256sum: []const u8,
};

pub const Package = struct {
    name: []const u8,
    author: []const u8,
    docs: []const u8,
    versions: []Version,
};
