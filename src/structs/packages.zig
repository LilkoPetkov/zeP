const std = @import("std");

const Fetch = @import("fetch.zig");

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

    fn dupVersion(
        _: *Package,
        alloc: std.mem.Allocator,
        v: Version,
    ) !Version {
        return Version{
            .version = try alloc.dupe(u8, v.version),
            .root_file = try alloc.dupe(u8, v.root_file),
            .sha256sum = try alloc.dupe(u8, v.sha256sum),
            .url = try alloc.dupe(u8, v.url),
            .zig_version = try alloc.dupe(u8, v.zig_version),
        };
    }

    fn freeVersion(
        _: *Package,
        alloc: std.mem.Allocator,
        v: Version,
    ) void {
        alloc.free(v.root_file);
        alloc.free(v.sha256sum);
        alloc.free(v.url);
        alloc.free(v.version);
        alloc.free(v.zig_version);
    }

    pub fn dupPackage(
        self: *Package,
        alloc: std.mem.Allocator,
    ) !Package {
        var versions = try alloc.alloc(Version, self.versions.len);
        errdefer {
            for (versions) |v| self.freeVersion(alloc, v);
            alloc.free(versions);
        }

        for (self.versions, 0..) |v, i| {
            versions[i] = try self.dupVersion(alloc, v);
        }

        return Package{
            .author = try alloc.dupe(u8, self.author),
            .name = try alloc.dupe(u8, self.name),
            .docs = try alloc.dupe(u8, self.docs),
            .versions = versions,
        };
    }

    pub fn deinit(
        self: *Package,
        alloc: std.mem.Allocator,
    ) void {
        alloc.free(self.author);
        alloc.free(self.name);
        alloc.free(self.docs);
        for (self.versions) |v| {
            self.freeVersion(alloc, v);
        }
    }
};
