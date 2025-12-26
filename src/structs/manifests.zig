const std = @import("std");
const Constants = @import("constants");

pub const ArtifactManifest = struct {
    name: []const u8 = "",
    path: []const u8 = "",
};

pub const PackagePaths = struct {
    name: []const u8 = "",
    paths: [][]const u8 = &[_][]const u8{},
};

pub const PackagesManifest = struct {
    packages: []PackagePaths = &[_]PackagePaths{},
};

pub const AuthManifest = struct {
    token: []const u8 = "",

    pub fn bearer(self: *AuthManifest) ![]const u8 {
        const allocator = std.heap.page_allocator;
        const b = try std.fmt.allocPrint(allocator, "Bearer {s}", .{self.token});
        return b;
    }
};

pub const InjectorManifest = struct {
    schema: u8 = 1,
    included_modules: [][]const u8 = &[_][]const u8{},
    excluded_modules: [][]const u8 = &[_][]const u8{},
};
