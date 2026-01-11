const std = @import("std");
const expect = std.testing.expect;

const core = @import("core");

test "sha256sum hash comparison via text" {
    const test_allocator = std.testing.allocator;
    const test_text = "I am getting hashed";
    const test_result = "e606f14b284da250ff592ffc432ee00259533ca64709bd2f4bc896be61b087f1";

    const test_hash = try core.Hash.hashData(test_allocator, test_text);
    defer test_allocator.free(test_hash);

    try expect(std.mem.eql(u8, test_result, test_hash));
}

test "sha256sum hash comparison via url" {
    const test_allocator = std.testing.allocator;

    const test_result = "df50b016205d4faa8e088f0cb4f4645095e24f529cfcbd282d8d6904126d0e21";
    const test_url = "https://github.com/XerWoho/zeP/releases/download/0.1/windows_0.1.zip";
    const test_hash = try core.Hash.hashDataByUrl(test_allocator, test_url);
    defer test_allocator.free(test_hash);

    try std.testing.expect(std.mem.eql(u8, test_result, test_hash));
}
