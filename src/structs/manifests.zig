pub const ZigManifest = struct {
    name: []const u8 = "",
    path: []const u8 = "",
};

pub const ZepManifest = struct {
    version: []const u8 = "",
    path: []const u8 = "",
};

pub const PackagePaths = struct {
    name: []const u8 = "",
    paths: [][]const u8 = &[_][]const u8{},
};

pub const PackagesManifest = struct {
    packages: []PackagePaths = &[_]PackagePaths{},
};
