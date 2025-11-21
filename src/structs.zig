const std = @import("std");
pub const ZigManifest = struct { name: []const u8 = "", path: []const u8 = "" };

pub const PkgManifest = struct { name: []const u8 = "", paths: [][]const u8 = &[_][]const u8{} };

pub const PackagesManifest = struct { packages: []PkgManifest = &[_]PkgManifest{} };

pub const ZepManifest = struct { version: []const u8 = "", path: []const u8 = "" };

pub const PrinterData = struct { data: []const u8, verbosity: u8 = 1, color: u8 = 0 };

pub const BuildPackageJsonStruct = struct {
    entry: []const u8 = "src/main.zig",
    target: []const u8 = "",
};

pub const PackageJsonStruct = struct {
    author: []const u8 = "",
    tags: [][]const u8 = &[_][]const u8{},
    zigVersion: []const u8 = "0.14.0",
    repo: []const u8 = "",
    name: []const u8 = "",
    description: []const u8 = "",
    version: []const u8 = "0.0.1",
    license: []const u8 = "",
    packages: [][]const u8 = &[_][]const u8{},
    devPackages: [][]const u8 = &[_][]const u8{},
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
    zigVersion: []const u8,
    rootFile: []const u8,
};

pub const PackageVersions = struct {
    version: []const u8,
    url: []const u8,
    zigVersion: []const u8,
    rootFile: []const u8,
    sha256sum: []const u8,
};

pub const PackageStruct = struct {
    name: []const u8,
    author: []const u8,
    docs: []const u8,
    versions: []PackageVersions,
};
