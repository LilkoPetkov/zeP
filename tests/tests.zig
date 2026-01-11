test "run tests" {
    _ = @import("test_version.zig");
    _ = @import("core/test_compress.zig");
    _ = @import("core/test_hash.zig");
    _ = @import("core/test_json.zig");
    _ = @import("io/test_fs.zig");
}
