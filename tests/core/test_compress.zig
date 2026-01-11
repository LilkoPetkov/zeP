const std = @import("std");
const expect = std.testing.expect;

const core = @import("core");

test "zstd compress/decompress roundtrip" {
    const test_allocator = std.testing.allocator;
    const test_text = "I am getting compressed by zstd";

    const bound = core.Zstd.getBound(test_text);

    var compressed = try test_allocator.alloc(u8, bound);
    defer test_allocator.free(compressed);
    const written = try core.Zstd.compress(test_text, &compressed, bound, 3);

    var decompressed = try test_allocator.alloc(u8, test_text.len);
    defer test_allocator.free(decompressed);
    try core.Zstd.decompress(
        compressed[0..written],
        &decompressed,
        test_text.len,
    );

    try expect(std.mem.eql(u8, decompressed, test_text));
}
