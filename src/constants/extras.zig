pub const package_files = struct {
    pub const manifest = "zep.json";
    pub const lock = "zep.lock";
    pub const zep_folder = ".zep";
    pub const lock_schema_version = 2;
    pub const injector = ".zep/injector.zig";
    pub const injector_manifest = ".zep/.conf/injector.json";
};

pub const filtering = struct {
    pub const folders = [_][]const u8{
        ".git",
        ".vscode",
        ".zig-cache",
    };

    pub const files = [_][]const u8{};
};
