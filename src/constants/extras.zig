pub const filtering = struct {
    pub const folders = [_][]const u8{
        "node_modules",
        "zig-out",
        ".git",
        ".zig-cache",
    };

    pub const files = [_][]const u8{};
};
