const std = @import("std");
const Constants = @import("constants");

pub const Artifact = struct {
    name: []const u8 = "",
    path: []const u8 = "",
};

pub const PackagePaths = struct {
    name: []const u8 = "",
    paths: [][]const u8 = &[_][]const u8{},
};

pub const Packages = struct {
    packages: []PackagePaths = &[_]PackagePaths{},
};

pub const Auth = struct {
    token: []const u8 = "",

    pub fn bearer(self: *Auth) ![]const u8 {
        const allocator = std.heap.page_allocator;
        const b = try std.fmt.allocPrint(allocator, "Bearer {s}", .{self.token});
        return b;
    }
};
