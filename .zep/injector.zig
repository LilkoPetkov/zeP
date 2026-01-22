const std = @import("std");
pub fn imp(b: *std.Build, exe: *std.Build.Module) void {
 // mvzr MODULE
 const mvzrMod = b.createModule(.{
     .root_source_file = b.path(".zep/mvzr/src/mvzr.zig"),
 });
 exe.addImport("mvzr", mvzrMod);
 // ----------
 // logly MODULE
 const loglyMod = b.createModule(.{
     .root_source_file = b.path(".zep/logly/src/logly.zig"),
 });
 exe.addImport("logly", loglyMod);
 // ----------
}
