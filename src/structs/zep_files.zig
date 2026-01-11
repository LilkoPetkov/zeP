const Constants = @import("constants");
const builtin = @import("builtin");

pub const BuildPackageJsonStruct = struct {
    entry: []const u8 = "src/main.zig",
    target: []const u8 = if (builtin.os.tag == .windows) Constants.Default.default_targets.windows else Constants.Default.default_targets.linux,
};

pub const CommandPackageJsonStrcut = struct {
    name: []const u8,
    cmd: []const u8,
};

pub const PackageJsonStruct = struct {
    author: []const u8 = "",
    tags: [][]const u8 = &[_][]const u8{},
    zig_version: []const u8 = "0.15.2",
    repo: []const u8 = "",
    name: []const u8 = "",
    cmd: []CommandPackageJsonStrcut = &[_]CommandPackageJsonStrcut{},
    description: []const u8 = "",
    version: []const u8 = "0.0.1",
    license: []const u8 = "",
    packages: [][]const u8 = &[_][]const u8{},
    dev_packages: [][]const u8 = &[_][]const u8{},
    build: BuildPackageJsonStruct = .{},
};

pub const PackageLockStruct = struct {
    schema: u8 = 2,
    root: PackageJsonStruct = .{},
    packages: []LockPackageStruct = &[_]LockPackageStruct{},
};

pub const LockPackageStruct = struct {
    name: []const u8,
    hash: []const u8,
    source: []const u8,
    zig_version: []const u8,
    root_file: []const u8,
};
