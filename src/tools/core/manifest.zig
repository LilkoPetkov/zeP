const std = @import("std");

pub const Manifest = @This();

const Logger = @import("logger");
const Constants = @import("constants");
const Structs = @import("structs");

const Fs = @import("io").Fs;
const Json = @import("json.zig");

allocator: std.mem.Allocator,
paths: Constants.Paths.Paths,

pub fn init(
    allocator: std.mem.Allocator,
    paths: Constants.Paths.Paths,
) Manifest {
    return .{
        .allocator = allocator,
        .paths = paths,
    };
}

pub fn writeManifest(
    self: *Manifest,
    comptime ManifestType: type,
    path: []const u8,
    manifest: ManifestType,
) !void {
    try Fs.deleteFileIfExists(path);

    const jsonStr = try std.json.Stringify.valueAlloc(self.allocator, manifest, .{ .whitespace = .indent_tab });
    defer self.allocator.free(jsonStr);

    const f = try Fs.openOrCreateFile(path);
    defer f.close();

    _ = try f.write(jsonStr);
}

pub fn readManifest(
    self: *Manifest,
    comptime ManifestType: type,
    path: []const u8,
) !std.json.Parsed(ManifestType) {
    if (!Fs.existsFile(path)) {
        const default_manifest: ManifestType = .{};
        try self.writeManifest(ManifestType, path, default_manifest);
    }

    const f = try Fs.openFile(path);
    defer f.close();

    const data = try f.readToEndAlloc(self.allocator, 10 * Constants.Default.mb);
    const parsed = std.json.parseFromSlice(ManifestType, self.allocator, data, .{}) catch {
        try Fs.deleteFileIfExists(path);
        const read_manifest = try self.readManifest(ManifestType, path);
        return read_manifest;
    };

    return parsed;
}
