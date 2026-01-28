const std = @import("std");
pub fn imp(b: *std.Build, exe: *std.Build.Module) void {
    // mvzr MODULE
    exe.addImport("mvzr", b.createModule(.{
        .root_source_file = b.path(".zep/mvzr/src/mvzr.zig"),
        .imports = &.{},
    }));
    // ----------
    // zon MODULE
    exe.addImport("zon", b.createModule(.{
        .root_source_file = b.path(".zep/zon/src/zon.zig"),
        .imports = &.{},
    }));
    // ----------
    // logly MODULE
    exe.addImport("logly", b.createModule(.{
        .root_source_file = b.path(".zep/logly/src/logly.zig"),
        .imports = &.{},
    }));
    // ----------
}
