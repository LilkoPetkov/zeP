const std = @import("std");

pub const Cacher = @This();

const Constants = @import("constants");

const Fs = @import("io").Fs;
const Package = @import("core").Package;

const TEMPORARY_DIRECTORY_PATH = ".zep/.ZEPtmp";

const Context = @import("context");

ctx: *Context,

pub fn init(ctx: *Context) Cacher {
    return .{
        .ctx = ctx,
    };
}

pub fn deinit(_: *Cacher) void {}

fn cacheFilePath(
    self: *Cacher,
    package_id: []const u8,
) ![]u8 {
    const zstd_id = try std.fmt.allocPrint(
        self.ctx.allocator,
        "{s}.tar.zstd",
        .{
            package_id,
        },
    );
    const cache_fp = try std.fs.path.join(
        self.ctx.allocator,
        &.{
            self.ctx.paths.cached,
            zstd_id,
        },
    );

    return cache_fp;
}

fn extractPath(
    self: *Cacher,
    package_id: []const u8,
) ![]u8 {
    const extract_p = try std.fs.path.join(
        self.ctx.allocator,
        &.{
            self.ctx.paths.pkg_root,
            package_id,
        },
    );

    return extract_p;
}

fn tmpOutputPath(
    self: *Cacher,
    package_id: []const u8,
) ![]u8 {
    const tmp_p = try std.fs.path.join(
        self.ctx.allocator,
        &.{
            TEMPORARY_DIRECTORY_PATH,
            package_id,
        },
    );

    return tmp_p;
}

pub fn isPackageCached(
    self: *Cacher,
    package_id: []const u8,
) !bool {
    try self.ctx.logger.info("Checking Cache", @src());

    try self.ctx.printer.append("\nChecking Cache...\n", .{}, .{});
    const path = try self.cacheFilePath(
        package_id,
    );
    return Fs.existsFile(path);
}

pub fn getPackageFromCache(
    self: *Cacher,
    package_id: []const u8,
) !void {
    try self.ctx.logger.info("Getting Cache", @src());

    try self.ctx.printer.append(" > CACHE HIT!\n", .{}, .{ .color = .green });

    const temporary_output_path = try self.tmpOutputPath(package_id);
    var temporary_directory = try Fs.openOrCreateDir(temporary_output_path);
    defer {
        temporary_directory.close();
        Fs.deleteTreeIfExists(TEMPORARY_DIRECTORY_PATH) catch {};
        self.ctx.allocator.free(temporary_output_path);
    }

    const cache_path = try self.cacheFilePath(package_id);
    defer self.ctx.allocator.free(cache_path);

    const extract_path = try self.extractPath(package_id);
    defer self.ctx.allocator.free(extract_path);

    try self.ctx.compressor.decompress(cache_path, extract_path);
}

pub fn setPackageToCache(self: *Cacher, package_id: []const u8) !void {
    try self.ctx.logger.info("Setting Cache", @src());

    try self.ctx.printer.append("Package not cached...\n", .{}, .{});

    const target_folder = try std.fs.path.join(
        self.ctx.allocator,
        &.{
            self.ctx.paths.pkg_root,
            package_id,
        },
    );
    defer self.ctx.allocator.free(target_folder);

    try self.ctx.printer.append("Caching now...\n", .{}, .{});
    const compress_path = try self.cacheFilePath(package_id);
    try self.ctx.compressor.compress(target_folder, compress_path);
    try self.ctx.printer.append(" > PACKAGE CACHED!\n\n", .{}, .{ .color = .green });
}

pub fn deletePackageFromCache(
    self: *Cacher,
    package_id: []const u8,
) !void {
    try self.ctx.logger.info("Deleting Cache", @src());

    const path = try std.fmt.allocPrint(
        self.ctx.allocator,
        "{s}/{s}.tar.zstd",
        .{
            self.ctx.paths.cached,
            package_id,
        },
    );
    defer self.ctx.allocator.free(path);

    if (Fs.existsFile(path)) {
        try Fs.deleteFileIfExists(path);
    }
}
