const std = @import("std");

const Constants = @import("constants");
const Structs = @import("structs");

const UtilsFs =
    @import("fs.zig");
const UtilsPackage =
    @import("package.zig");

const MAX_JSON_SIZE = 10 * 1024 * 1024; // 10 MB

pub const Json = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Json {
        return Json{ .allocator = allocator };
    }

    pub fn parsePackage(self: *Json, packageName: []const u8) !?std.json.Parsed(Structs.PackageStruct) {
        const path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.json", .{ Constants.PACKAGE_FOLDER, packageName });
        defer self.allocator.free(path);

        const check = try UtilsFs.checkFileExists(path);
        if (!check) return null;

        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const data = try file.readToEndAlloc(self.allocator, MAX_JSON_SIZE);
        const parsedData = try std.json.parseFromSlice(Structs.PackageStruct, self.allocator, data, .{});
        return parsedData;
    }

    pub fn parsePkgJson(self: *Json) !?std.json.Parsed(Structs.PackageJsonStruct) {
        if (!try UtilsFs.checkFileExists(Constants.ZEP_PACKAGE_FILE))
            return null;

        var file = try UtilsFs.openFile(Constants.ZEP_PACKAGE_FILE);
        defer file.close();

        const data = try file.readToEndAlloc(self.allocator, MAX_JSON_SIZE);
        return try std.json.parseFromSlice(Structs.PackageJsonStruct, self.allocator, data, .{});
    }

    pub fn parseLockJson(self: *Json) !?std.json.Parsed(Structs.PackageLockStruct) {
        if (!try UtilsFs.checkFileExists(Constants.ZEP_LOCK_PACKAGE_FILE))
            return null;

        var file = try UtilsFs.openFile(Constants.ZEP_LOCK_PACKAGE_FILE);
        defer file.close();

        const data = try file.readToEndAlloc(self.allocator, MAX_JSON_SIZE);
        return try std.json.parseFromSlice(Structs.PackageLockStruct, self.allocator, data, .{});
    }

    pub fn stringifyPkgJson(self: *Json, package: *Structs.PackageJsonStruct) ![]u8 {
        return try std.json.stringifyAlloc(self.allocator, package, .{ .whitespace = .indent_2 });
    }

    pub fn stringifyLockJson(self: *Json, lock: *Structs.PackageLockStruct) ![]u8 {
        return try std.json.stringifyAlloc(self.allocator, lock, .{ .whitespace = .indent_2 });
    }
};
