const std = @import("std");

const Utils = @import("utils");
const UtilsFs = Utils.UtilsFs;

const Constants = @import("constants");

const MAX_SIZE = 1028 * 1028 * 10;

const Manifest = struct { name: []const u8, path: []const u8 };
pub fn modifyManifest(name: []const u8, version: []const u8, target: []const u8) !void {
    const allocator = std.heap.page_allocator;
    try UtilsFs.delFile(Constants.ROOT_ZEP_ZIG_MANIFEST);

    const path = try std.fmt.allocPrint(allocator, "{s}/d/{s}/{s}", .{ Constants.ROOT_ZEP_ZIG_FOLDER, version, target });
    const newManifest = Manifest{ .name = name, .path = path };
    const str = try std.json.stringifyAlloc(allocator, newManifest, .{ .whitespace = .indent_tab });
    const f = try UtilsFs.openCFile(Constants.ROOT_ZEP_ZIG_MANIFEST);
    _ = try f.write(str);
}

pub fn getManifest() !std.json.Parsed(Manifest) {
    const allocator = std.heap.page_allocator;
    if (!try UtilsFs.checkFileExists(Constants.ROOT_ZEP_ZIG_MANIFEST)) {
        return error.NoManifestFile;
    }
    const f = try UtilsFs.openFile(Constants.ROOT_ZEP_ZIG_MANIFEST);
    const d = try f.readToEndAlloc(allocator, 1024 * 1024);

    const parsed = try std.json.parseFromSlice(Manifest, allocator, d, .{});
    return parsed;
}
