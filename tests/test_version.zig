const std = @import("std");
const expect = std.testing.expect;

const constants = @import("constants");
const structs = @import("structs");
const io = @import("io");
const core = @import("core");

test "version comparison" {
    const test_allocator = std.testing.allocator;
    const latest = try io.Fs.openFile("LATEST");
    defer latest.close();

    const manifest = try core.Json.parseJsonFromFile(
        test_allocator,
        structs.ZepFiles.PackageJsonStruct,
        constants.Extras.package_files.manifest,
        constants.Default.mb,
    );
    defer manifest.deinit();

    const lock = try core.Json.parseJsonFromFile(
        test_allocator,
        structs.ZepFiles.PackageLockStruct,
        constants.Extras.package_files.lock,
        constants.Default.mb,
    );
    defer lock.deinit();

    const read = try latest.readToEndAlloc(test_allocator, 30);
    defer test_allocator.free(read);

    try expect(std.mem.eql(u8, read, constants.Default.version));
    try expect(std.mem.eql(u8, manifest.value.version, lock.value.root.version));
    try expect(std.mem.eql(u8, manifest.value.version, read));
}
