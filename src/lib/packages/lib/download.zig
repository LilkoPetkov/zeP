const std = @import("std");
const builtin = @import("builtin");

pub const Downloader = @This();

const Constants = @import("constants");
const Fs = @import("io").Fs;

const TEMPORARY_DIRECTORY_PATH = ".zep/.ZEPtmp";

const Cacher = @import("cache.zig");
const Context = @import("context");

ctx: *Context,
cacher: Cacher,

pub fn init(ctx: *Context) Downloader {
    const cacher = Cacher.init(ctx);

    return .{
        .ctx = ctx,
        .cacher = cacher,
    };
}

pub fn deinit(_: *Downloader) void {}

const ArchiveType = enum {
    zip,
    tar_zstd,
};

fn downloadAndExtract(
    self: *Downloader,
    url: []const u8,
    archive_type: ArchiveType,
    out_path: []const u8,
) !void {
    var client = std.http.Client{ .allocator = self.ctx.allocator };
    defer client.deinit();

    const extract_path = switch (archive_type) {
        .zip => ".zep/.ZEPtmp/tmp.zip",
        .tar_zstd => ".zep/.ZEPtmp/tmp.tar.zstd",
    };

    var file = try Fs.openOrCreateFile(extract_path);
    defer file.close();

    var writer_buf: [Constants.Default.kb]u8 = undefined;
    var writer = file.writer(&writer_buf);
    const fetched = try client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .response_writer = &writer.interface,
    });
    _ = try writer.interface.flush();

    if (fetched.status == .not_found)
        return error.NotFound;

    try self.ctx.printer.append("Extracting...\n", .{}, .{});
    if (archive_type == .zip) {
        try self.extractZip(extract_path, out_path);
    } else {
        try self.ctx.compressor.decompress(extract_path, out_path);
    }
}

fn resolveCloudUrl(
    ctx: *Context,
    name: []const u8,
    version: []const u8,
) ?[]const u8 {
    var releases = ctx.fetcher.fetchReleases(name) catch return null;
    defer releases.deinit(ctx.allocator);

    for (releases.items) |r| {
        if (std.mem.eql(u8, r.Release, version)) {
            return r.Url;
        }
    }
    return null;
}

fn extractZip(self: *Downloader, extract_path: []const u8, path: []const u8) !void {
    try self.ctx.logger.info("Extracting Zip", @src());

    // create/open extract directory
    var extract_directory = try Fs.openOrCreateDir(TEMPORARY_DIRECTORY_PATH);
    defer extract_directory.close();
    defer {
        Fs.deleteTreeIfExists(TEMPORARY_DIRECTORY_PATH) catch {
            self.ctx.printer.append("\nFailed to delete temp directory!\n", .{}, .{ .color = .red }) catch {};
        };
    }

    var extract_file = try Fs.openFile(extract_path);
    defer extract_file.close();
    var reader_buf: [Constants.Default.kb * 16]u8 = undefined;
    var reader = extract_file.reader(&reader_buf);

    var diagnostics = std.zip.Diagnostics{
        .allocator = self.ctx.allocator,
    };

    defer diagnostics.deinit();
    try std.zip.extract(extract_directory, &reader, .{ .diagnostics = &diagnostics });

    const extract_target = try std.fmt.allocPrint(
        self.ctx.allocator,
        "{s}/{s}",
        .{
            TEMPORARY_DIRECTORY_PATH,
            diagnostics.root_dir,
        },
    );
    defer self.ctx.allocator.free(extract_target);

    try std.fs.cwd().rename(extract_target, path);
}

fn fetchPackage(
    self: *Downloader,
    package_id: []const u8,
    url: []const u8,
    install_unverified_packages: bool,
) !void {
    try self.ctx.logger.infof("Fetching Package {s}", .{url}, @src());

    // allocate paths and free them after use
    const path = try std.fs.path.join(
        self.ctx.allocator,
        &.{ self.ctx.paths.pkg_root, package_id },
    );
    defer self.ctx.allocator.free(path);
    if (Fs.existsDir(path)) return;

    try self.ctx.printer.append("Fetching package... [{s}]\n", .{url}, .{});
    var split = std.mem.splitAny(u8, package_id, "@");
    const package_name = split.first();
    const package_version = split.next() orelse "";

    if (install_unverified_packages) {
        const u = resolveCloudUrl(self.ctx, package_name, package_version);
        if (u) |cloud_url| {
            try self.downloadAndExtract(
                cloud_url,
                .tar_zstd,
                path,
            );
            try Fs.deleteTreeIfExists(".zep/ZEPtmp");
            return;
        }
    }

    // fallback
    try self.downloadAndExtract(
        url,
        .zip,
        path,
    );
}

fn doesPackageExist(
    self: *Downloader,
    package_id: []const u8,
) !bool {
    const path = try std.fs.path.join(
        self.ctx.allocator,
        &.{ self.ctx.paths.pkg_root, package_id },
    );
    defer self.ctx.allocator.free(path);

    return Fs.existsDir(path);
}

pub fn downloadPackage(
    self: *Downloader,
    package_id: []const u8,
    url: []const u8,
    install_unverified_packages: bool,
) !void {
    try self.ctx.logger.infof("Downloading Package {s}", .{package_id}, @src());

    const exists = try self.doesPackageExist(package_id);
    if (exists) {
        try self.ctx.printer.append(" > PACKAGE ALREADY EXISTS!\n", .{}, .{});
        return;
    }

    try self.ctx.printer.append("Checking Cache...\n", .{}, .{
        .verbosity = 2,
    });
    const is_cached = try self.cacher.isPackageCached(package_id);
    if (is_cached) {
        try self.ctx.printer.append(
            " > CACHE HIT!\n\n",
            .{},
            .{
                .color = .green,
            },
        );
        self.cacher.getPackageFromCache(package_id) catch {
            try self.ctx.printer.append(" ! CACHE FAILED\n\n", .{}, .{ .color = .red });
        };
    } else {
        try self.ctx.printer.append(
            " > CACHE MISS!\n\n",
            .{},
            .{
                .color = .bright_red,
            },
        );
        try self.fetchPackage(
            package_id,
            url,
            install_unverified_packages,
        );
        self.cacher.setPackageToCache(package_id) catch {
            try self.ctx.printer.append(" ! CACHING FAILED\n\n", .{}, .{ .color = .red });
        };
    }
}
