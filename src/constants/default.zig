const std = @import("std");
const builtin = @import("builtin");

pub const zep_url = "https://zep.run";
pub const zep_download_index = zep_url ++ "/download.json";
pub const zig_download_index = "https://ziglang.org/download/index.json";

pub const kb = 1024;
pub const mb = kb * kb;

pub const version = "1.1.0";
pub const commit = "5006d44";
pub const zig_version = "0.15.2";

pub const default_targets = struct {
    pub const windows = "x86_64-windows";
    pub const linux = "x86_64-linux";
    pub const macos = "x86_64-macos";
};

pub const package_files = struct {
    pub const lock = "zep.lock";
    pub const build_zon = "build.zig.zon";
    pub const zep_folder = ".zep";
    pub const lock_schema_version = 2;
    pub const injector = ".zep/injector.zig";
};

/// Resolve default target if no target specified
pub fn resolveDefaultTarget() []const u8 {
    return switch (builtin.target.os.tag) {
        .windows => default_targets.windows,
        .macos => default_targets.macos,
        else => default_targets.linux,
    };
}
