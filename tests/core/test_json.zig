const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;

const core = @import("core");
const constants = @import("constants");
const structs = @import("structs");

test "validate json parsing" {
    const test_allocator = std.testing.allocator;
    const test_path = "tests/assets/valid.json";
    const test_manifest = try core.Json.parseJsonFromFile(
        test_allocator,
        structs.ZepFiles.PackageJsonStruct,
        test_path,
        constants.Default.mb,
    );
    defer test_manifest.deinit();

    try expect(std.mem.eql(u8, test_manifest.value.name, "test"));
    try expect(std.mem.eql(u8, test_manifest.value.author, "tester"));
}

test "expect error when json parsing invalid json" {
    const test_allocator = std.testing.allocator;
    const test_path_unexpected = "tests/assets/unexpected.json";

    try std.testing.expectError(
        error.UnexpectedEndOfInput,
        core.Json.parseJsonFromFile(
            test_allocator,
            structs.ZepFiles.PackageJsonStruct,
            test_path_unexpected,
            constants.Default.mb,
        ),
    );
}

test "expect no error when json parsing missing fields" {
    const test_allocator = std.testing.allocator;
    const test_path_missing = "tests/assets/missing.json";
    const parsed = try core.Json.parseJsonFromFile(
        test_allocator,
        structs.ZepFiles.PackageJsonStruct,
        test_path_missing,
        constants.Default.mb,
    );
    defer parsed.deinit();

    try std.testing.expect(std.mem.eql(u8, parsed.value.version, "0.0.1"));
}
