const std = @import("std");
const builtin = @import("builtin");

pub const ArtifactCache = @This();

const Structs = @import("structs");
const Constants = @import("constants");

const Fs = @import("io").Fs;
const Printer = @import("cli").Printer;
const Prompt = @import("cli").Prompt;
const Manifest = @import("core").Manifest;

const Context = @import("context");

/// Lists installed Artifact versions
ctx: *Context,
artifact_type: Structs.Extras.ArtifactType,

pub fn init(
    ctx: *Context,
    artifact_type: Structs.Extras.ArtifactType,
) ArtifactCache {
    return ArtifactCache{
        .ctx = ctx,
        .artifact_type = artifact_type,
    };
}

pub fn deinit(_: *ArtifactCache) void {
    // currently no deinit required
}

pub fn list(self: *ArtifactCache) !void {
    try self.ctx.logger.info("Listing ArtifactCache", @src());

    const cached_path = try std.fs.path.join(self.ctx.allocator, &.{
        if (self.artifact_type == .zig) self.ctx.paths.zig_root else self.ctx.paths.zep_root,
        "z",
    });
    defer self.ctx.allocator.free(cached_path);

    var opened_cached = try Fs.openOrCreateDir(cached_path);
    defer opened_cached.close();

    var opened_cached_iter = opened_cached.iterate();

    try self.ctx.printer.append("Listing cached artifacts:\n", .{}, .{});
    var is_artifacts_listed = false;
    while (try opened_cached_iter.next()) |entry| {
        if (entry.kind != .directory) continue;
        is_artifacts_listed = true;

        const single_cache_path = try std.fs.path.join(self.ctx.allocator, &.{
            cached_path,
            entry.name,
        });
        defer {
            self.ctx.allocator.free(single_cache_path);
        }

        var version_directory = try Fs.openDir(single_cache_path);
        defer version_directory.close();

        var version_iterator = version_directory.iterate();
        var has_targets: bool = false;

        while (try version_iterator.next()) |version_entry| {
            has_targets = true;
            const target_name = try self.ctx.allocator.dupe(u8, version_entry.name);
            try self.ctx.printer.append(" > {s}\n", .{target_name}, .{});
        }

        if (!has_targets) {
            try self.ctx.printer.append(" NOTHING CACHED\n", .{}, .{ .color = .red });
        }
    }
    if (!is_artifacts_listed) {
        try self.ctx.printer.append("No artifacts cached.\n", .{}, .{ .color = .red });
    }
    try self.ctx.printer.append("\n", .{}, .{});
}

fn cleanSingle(self: *ArtifactCache, version: []const u8) !void {
    try self.ctx.logger.infof("Cleaing Single Artifact {s}", .{version}, @src());
    const cached_path = try std.fs.path.join(self.ctx.allocator, &.{
        if (self.artifact_type == .zig) self.ctx.paths.zig_root else self.ctx.paths.zep_root,
        "z",
    });
    defer self.ctx.allocator.free(cached_path);

    var opened_cached = try Fs.openOrCreateDir(cached_path);
    defer opened_cached.close();

    var opened_cached_iter = opened_cached.iterate();

    try self.ctx.printer.append("Cleaning cache with target [{s}]:\n", .{version}, .{});
    var data_found: u16 = 0;
    var failed_deletion: u16 = 0;
    while (try opened_cached_iter.next()) |entry| {
        if (std.mem.eql(u8, entry.name, version)) continue;

        const path = try std.fs.path.join(self.ctx.allocator, &.{ cached_path, entry.name });
        defer self.ctx.allocator.free(path);

        Fs.deleteTreeIfExists(path) catch {
            failed_deletion += 1;
            try self.ctx.printer.append(" <FAILED>\n", .{}, .{ .color = .red });
            continue;
        };
        data_found += 1;
        try self.ctx.printer.append(" <REMOVED>\n", .{}, .{ .color = .green });
    }
    if (data_found == 0) {
        try self.ctx.printer.append("No cached artifacts found.\n", .{}, .{});
        return;
    }
    try self.ctx.printer.append("Removed: {d} cached artifacts ({d} failed)\n", .{ data_found, failed_deletion }, .{});
}

pub fn clean(self: *ArtifactCache, version: ?[]const u8) !void {
    try self.ctx.logger.info("Cleaning ArtifactCache", @src());

    if (version) |n| {
        try self.cleanSingle(n);
        return;
    }

    const cached_path = try std.fs.path.join(self.ctx.allocator, &.{
        if (self.artifact_type == .zig) self.ctx.paths.zig_root else self.ctx.paths.zep_root,
        "z",
    });
    defer self.ctx.allocator.free(cached_path);

    var opened_cached = try Fs.openOrCreateDir(cached_path);
    defer opened_cached.close();

    var opened_cached_iter = opened_cached.iterate();

    try self.ctx.printer.append("Cleaning cache:\n", .{}, .{});

    const UNITS = [5][]const u8{ "B", "KB", "MB", "GB", "TB" };
    var unit_depth: u8 = 0;
    var cache_size = try self.getSize();
    while (cache_size > 1024 * 2) {
        unit_depth += 1;
        cache_size = cache_size / 1024;
        if (unit_depth == 4) break;
    }

    if (cache_size == 0) {
        try self.ctx.printer.append("ArtifactCache is already empty.\n", .{}, .{});
        return;
    }

    const prompt = try std.fmt.allocPrint(self.ctx.allocator, "This will remove all cached {s} artifacts ({d} {s}). Continue? [y/N]", .{
        if (self.artifact_type == .zig) "Zig" else "Zep",
        cache_size,
        UNITS[unit_depth],
    });
    defer self.ctx.allocator.free(prompt);

    const input = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        prompt,
        .{},
    );
    defer self.ctx.allocator.free(input);
    if (input.len == 0) return;
    if (!std.mem.startsWith(u8, input, "y") and !std.mem.startsWith(u8, input, "Y")) return;

    var data_found: u16 = 0;
    var failed_deletion: u16 = 0;
    while (try opened_cached_iter.next()) |entry| {
        const path = try std.fs.path.join(self.ctx.allocator, &.{ cached_path, entry.name });
        defer self.ctx.allocator.free(path);
        try self.ctx.printer.append(" - {s} [{s}]", .{ entry.name, path }, .{});

        Fs.deleteTreeIfExists(path) catch {
            try self.ctx.printer.append(" <FAILED>\n", .{}, .{ .color = .red });
            failed_deletion += 1;
            continue;
        };

        data_found += 1;
        try self.ctx.printer.append(" <REMOVED>\n", .{}, .{ .color = .green });
    }
    if (data_found == 0) {
        try self.ctx.printer.append("No cached artifacts found.\n", .{}, .{});
        return;
    }
    try self.ctx.printer.append("\nRemoved: {d} cached artifacts ({d} failed)\n", .{ data_found, failed_deletion }, .{});
}

fn getFsSize(self: *ArtifactCache, cached_path: []const u8) !u64 {
    if (!Fs.existsDir(cached_path)) return 0;

    var opened_cached = try Fs.openDir(cached_path);
    defer opened_cached.close();

    var opened_cached_iter = opened_cached.iterate();

    var cache_size: u64 = 0;
    while (try opened_cached_iter.next()) |entry| {
        const path = try std.fs.path.join(self.ctx.allocator, &.{ cached_path, entry.name });
        defer self.ctx.allocator.free(path);

        if (entry.kind == .directory) {
            const u = try self.getFsSize(path);
            cache_size += u;
            continue;
        }

        var cached_file = try Fs.openFile(path);
        defer cached_file.close();

        const stat = try cached_file.stat();
        cache_size += stat.size;
    }

    return cache_size;
}

fn getSize(self: *ArtifactCache) !u64 {
    const cached_path = try std.fs.path.join(self.ctx.allocator, &.{
        if (self.artifact_type == .zig) self.ctx.paths.zig_root else self.ctx.paths.zep_root,
        "z",
    });
    defer self.ctx.allocator.free(cached_path);

    const cache_size: u64 = try self.getFsSize(cached_path);
    return cache_size;
}

pub fn size(self: *ArtifactCache) !void {
    try self.ctx.logger.info("Getting ArtifactCache Size", @src());

    try self.ctx.printer.append("Getting cache size...\n", .{}, .{});
    const cache_size = try self.getSize();
    try self.ctx.printer.append("Size:\n{d} Bytes\n{d} KB\n{d} MB\n\n", .{ cache_size, cache_size / 1024, cache_size / 1024 / 1024 }, .{});
}
