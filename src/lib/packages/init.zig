const std = @import("std");

const Constants = @import("constants");
const Structs = @import("structs");

const Fs = @import("io").Fs;
const Json = @import("core").Json.Json;

pub const Init = struct {
    allocator: std.mem.Allocator,
    json: Json,

    pub fn init(allocator: std.mem.Allocator) !Init {
        const json = try Json.init(allocator);
        return Init{ .allocator = allocator, .json = json };
    }

    pub fn commitInit(self: *Init) !void {
        try self.createFolders();
        try self.createFiles();
    }

    fn createFolders(_: *Init) !void {
        const cwd = std.fs.cwd();
        _ = cwd.makeDir(Constants.Extras.package_files.zep_folder) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }

    fn createFiles(self: *Init) !void {
        const pkg = Structs.ZepFiles.PackageJsonStruct{
            .build = Structs.ZepFiles.BuildPackageJsonStruct{},
        };
        const lock = Structs.ZepFiles.PackageLockStruct{
            .root = Structs.ZepFiles.PackageJsonStruct{
                .build = Structs.ZepFiles.BuildPackageJsonStruct{},
            },
        };

        if (!Fs.existsFile(Constants.Extras.package_files.manifest)) {
            try self.json.writePretty(Constants.Extras.package_files.manifest, pkg);
        }

        if (!Fs.existsFile(Constants.Extras.package_files.lock)) {
            try self.json.writePretty(Constants.Extras.package_files.lock, lock);
        }
    }
};
