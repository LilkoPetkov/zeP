pub const package_files = struct {
    pub const manifest = "zep.json";
    pub const lock = "zep.lock";
    pub const zep_folder = ".zep";
    pub const lock_schema_version = 2;
    pub const injector = ".zep/injector.zig";
};

pub const filtering = struct {
    pub const folders = [_][]const u8{
        ".git",
        ".github",
        ".vscode",
        ".zig-cache",
        "example",
        "examples",
        "test",
        "tests",
        "testdata",
    };

    pub const files = [_][]const u8{
        ".editorconfig",
        ".gitignore",
        ".gitattributes",
        "LICENSE",
        "readme.md",
        "todo.md",
    };
};
