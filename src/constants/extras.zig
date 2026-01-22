pub const package_files = struct {
    pub const lock = "zep.lock";
    pub const build_zon = "build.zig.zon";
    pub const zep_folder = ".zep";
    pub const lock_schema_version = 2;
    pub const injector = ".zep/injector.zig";
};

pub const filtering = struct {
    pub const folders = [_][]const u8{
        "node_modules",
        "zig-out",
        ".git",
        ".zig-cache",
    };

    pub const files = [_][]const u8{};
};
