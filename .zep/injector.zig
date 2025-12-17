const std = @import("std");
pub fn imp(b: *std.Build, exe: *std.Build.Module) void {
 // clap MODULE
 const clapMod = b.createModule(.{
     .root_source_file = b.path(".zep/clap/clap.zig"),
 });
 exe.addImport("clap", clapMod);
 // ----------
}
