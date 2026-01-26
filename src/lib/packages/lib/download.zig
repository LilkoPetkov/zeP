const std = @import("std");
const builtin = @import("builtin");

pub const Downloader = @This();

const Constants = @import("constants");
const Locales = @import("locales");

const Fs = @import("io").Fs;

const TEMP_DIR = ".zep/tmp";

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

fn extractArchive(
    self: *Downloader,
    archive_type: ArchiveType,
    archive_path: []const u8,
    out_path: []const u8,
) !void {
    try self.ctx.logger.infof("Extracting Archive {s} => {s}", .{ archive_path, out_path }, @src());
    try self.ctx.printer.append("Extracting...\n", .{}, .{
        .verbosity = 3,
    });

    switch (archive_type) {
        .zip => try self.ctx.compressor.decompressZ(archive_path, out_path),
        .tar_zstd => try self.ctx.compressor.decompress(archive_path, out_path),
    }
    Fs.deleteTreeIfExists(archive_path) catch {};
}

fn downloadArchive(
    self: *Downloader,
    package_id: []const u8,
    url: []const u8,
) ![]const u8 {
    try self.ctx.logger.infof("Fetching Package {s}", .{url}, @src());

    try self.ctx.printer.append("Fetching package... [{s}]\n", .{url}, .{
        .verbosity = 2,
    });
    var split = std.mem.splitAny(u8, package_id, "@");
    const package_name = split.first();
    const package_version = split.next() orelse "";

    const target_url = if (!Locales.INSTALL_UNVERIFIED_PACKAGES) url else self.findCloudReleaseUrl(package_name, package_version) orelse url;

    var client = std.http.Client{ .allocator = self.ctx.allocator };
    defer client.deinit();

    const is_zip = std.mem.endsWith(u8, target_url, ".zip");
    const install_path = if (is_zip) TEMP_DIR ++ "/tmp.zip" else "/tmp.tar.zstd";
    errdefer {
        Fs.deleteTreeIfExists(install_path) catch {};
    }

    var file = try Fs.openOrCreateFile(install_path);
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

    return install_path;
}

fn findCloudReleaseUrl(
    self: *Downloader,
    name: []const u8,
    version: []const u8,
) ?[]const u8 {
    var releases = self.ctx.fetcher.fetchReleases(name) catch return null;
    defer releases.deinit(self.ctx.allocator);

    for (releases.items) |r| {
        if (std.mem.eql(u8, r.Release, version)) {
            return r.Url;
        }
    }
    return null;
}

fn hasInstalledPackage(
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

pub fn installPackage(
    self: *Downloader,
    package_id: []const u8,
    url: []const u8,
) !void {
    try self.ctx.logger.infof("Downloading Package {s}", .{package_id}, @src());

    const out_path = try std.fs.path.join(
        self.ctx.allocator,
        &.{ self.ctx.paths.pkg_root, package_id },
    );
    defer self.ctx.allocator.free(out_path);
    if (Fs.existsDir(out_path)) {
        self.cacher.store(package_id) catch {
            try self.ctx.printer.append(
                " ! CACHING FAILED\n\n",
                .{},
                .{ .color = .red },
            );
        };
        return;
    }

    const exists = try self.hasInstalledPackage(package_id);
    const is_cached = try self.cacher.isCached(package_id);

    if (exists) {
        try self.ctx.printer.append(" > PACKAGE ALREADY EXISTS!\n", .{}, .{
            .verbosity = 2,
        });
        if (is_cached) return;

        self.cacher.store(package_id) catch {
            try self.ctx.printer.append(
                " ! CACHING FAILED\n\n",
                .{},
                .{
                    .color = .red,
                    .verbosity = 2,
                },
            );
        };
        return;
    }

    try self.ctx.printer.append("Checking Cache...\n", .{}, .{
        .verbosity = 2,
    });
    if (is_cached) {
        try self.ctx.printer.append(
            " > CACHE HIT!\n\n",
            .{},
            .{
                .color = .green,
                .verbosity = 2,
            },
        );
        self.cacher.restore(package_id) catch {
            try self.ctx.printer.append(
                " ! CACHE FAILED\n\n",
                .{},
                .{
                    .color = .red,
                    .verbosity = 2,
                },
            );
        };
    } else {
        try self.ctx.printer.append(
            " > CACHE MISS!\n\n",
            .{},
            .{
                .color = .bright_red,
                .verbosity = 2,
            },
        );

        const install_path = try self.downloadArchive(
            package_id,
            url,
        );
        const is_zip = std.mem.endsWith(u8, install_path, ".zip");
        try self.extractArchive(
            if (is_zip) ArchiveType.zip else ArchiveType.tar_zstd,
            install_path,
            out_path,
        );
        Fs.deleteTreeIfExists(TEMP_DIR) catch {};

        self.cacher.store(package_id) catch {
            try self.ctx.printer.append(
                " ! CACHING FAILED\n\n",
                .{},
                .{
                    .color = .red,
                    .verbosity = 2,
                },
            );
        };
    }
}
