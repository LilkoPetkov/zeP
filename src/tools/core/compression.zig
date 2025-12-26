const std = @import("std");

pub const Compressor = @This();

const Logger = @import("logger");
const Constants = @import("constants");

const Fs = @import("io").Fs;
const Printer = @import("cli").Printer;

const zstd = @import("zstd.zig");

/// Handles compression using zstd, and
/// recursion.
allocator: std.mem.Allocator,
printer: *Printer,
paths: Constants.Paths.Paths,

pub fn init(
    allocator: std.mem.Allocator,
    printer: *Printer,
    paths: Constants.Paths.Paths,
) Compressor {
    return Compressor{
        .allocator = allocator,
        .printer = printer,
        .paths = paths,
    };
}

fn archive(self: *Compressor, tar_writer: anytype, fs_path: []const u8, real_path: []const u8) !void {
    const alloc = std.heap.page_allocator;

    var open_target = try Fs.openDir(fs_path);
    defer open_target.close();

    var iter = open_target.iterate();
    while (try iter.next()) |input_file_path| {
        if (std.mem.eql(u8, input_file_path.name, ".git")) continue;
        if (std.mem.eql(u8, input_file_path.name, ".github")) continue;
        if (std.mem.eql(u8, input_file_path.name, "zig-out")) continue;
        if (std.mem.eql(u8, input_file_path.name, ".zig-cache")) continue;
        if (std.mem.eql(u8, input_file_path.name, "c")) continue;
        if (std.mem.eql(u8, input_file_path.name, "zstd")) continue;
        if (std.mem.eql(u8, input_file_path.name, "zep.run")) continue;
        if (std.mem.eql(u8, input_file_path.name, ".zep")) continue;

        const tar_path = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ real_path, input_file_path.name });
        const input_fs_path = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ fs_path, input_file_path.name });

        if (input_file_path.kind == .directory) {
            try tar_writer.writeDir(tar_path, .{});
            try self.archive(tar_writer, input_fs_path, tar_path);
            continue;
        }

        const reader_buffer: []u8 = try alloc.alloc(u8, 4096);
        const input_file = try std.fs.cwd().openFile(input_fs_path, .{ .mode = .read_only });
        defer input_file.close();

        const input_file_size: u64 = (try input_file.stat()).size;
        var input_file_reader = input_file.reader(reader_buffer);
        const input_file_reader_interface: *std.Io.Reader = &input_file_reader.interface;

        tar_writer.writeFileStream(
            tar_path,
            input_file_size,
            input_file_reader_interface,
            .{ .mtime = 0, .mode = 0 },
        ) catch {};
    }
}

pub fn compress(
    self: *Compressor,
    target_folder: []const u8,
    compress_path: []const u8,
) !void {
    if (!Fs.existsDir(target_folder)) {
        return error.FileNotFound;
    }

    if (!Fs.existsDir(self.paths.cached)) {
        _ = try Fs.openOrCreateDir(self.paths.cached);
    }

    var buf: [256]u8 = undefined;
    const a = try std.fmt.bufPrint(&buf, "{d}.tar.zstd", .{std.time.nanoTimestamp()});
    const archive_path = try std.fs.path.join(
        self.allocator,
        &.{ self.paths.prebuilt, a },
    );
    defer {
        Fs.deleteFileIfExists(archive_path) catch {
            self.printer.append(
                "\nRemoving temp archive failed! [{s}]\n",
                .{archive_path},
                .{ .color = .red, .weight = .bold, .verbosity = 0 },
            ) catch {};
        };
        self.allocator.free(archive_path);
    }

    blk: {
        var archive_file = try std.fs.cwd().createFile(archive_path, .{ .truncate = true });
        defer archive_file.close();
        var b: [Constants.Default.kb * 32]u8 = undefined;
        var writer = archive_file.writer(&b);

        var tar_writer = std.tar.Writer{ .prefix = ".", .underlying_writer = &writer.interface };
        try self.archive(&tar_writer, target_folder, "");
        try tar_writer.underlying_writer.flush();
        break :blk;
    }

    var archive_file = try Fs.openFile(archive_path);
    defer archive_file.close();
    const archive_file_stat = try archive_file.stat();

    var compress_file = try Fs.openFile(compress_path);
    defer compress_file.close();

    const data = try self.allocator.alloc(u8, @intCast(archive_file_stat.size));
    defer self.allocator.free(data);
    _ = try archive_file.readAll(data);

    const compressed = try zstd.compress(self.allocator, data, 3);

    const len = data.len;
    const len_str = try std.fmt.allocPrint(self.allocator, "{d}", .{len});
    defer self.allocator.free(len_str);

    for (0..(64 - len_str.len)) |_| {
        _ = try compress_file.writeAll("0");
    }

    _ = try compress_file.writeAll(len_str);
    _ = try compress_file.writeAll(compressed);

    return;
}

pub fn decompress(self: *Compressor, zstd_path: []const u8, extract_path: []const u8) !void {
    if (!Fs.existsDir(extract_path)) {
        _ = try Fs.openOrCreateDir(extract_path);
    }

    if (!Fs.existsFile(zstd_path)) {
        return;
    }

    var file = try Fs.openFile(zstd_path);
    defer file.close();
    const file_stat = try file.stat();

    const data = try self.allocator.alloc(u8, @intCast(file_stat.size));
    defer self.allocator.free(data);
    _ = try file.readAll(data);

    if (data.len < 64) return error.InvalidZstd;

    const uncompressed_len_string_full = data[0..64];
    var start_i: usize = 0;
    for (uncompressed_len_string_full, 0..) |n, i| {
        if (n == '0') continue;
        start_i = i;
        break;
    }

    const uncompressed_len_string = uncompressed_len_string_full[start_i..];
    const uncompressed_len = try std.fmt.parseInt(u64, uncompressed_len_string, 10);

    const compressed_data = data[64..];

    const decompressed = try zstd.decompress(
        self.allocator,
        compressed_data,
        @intCast(uncompressed_len),
    );
    defer self.allocator.free(decompressed);

    var reader = std.Io.Reader.fixed(decompressed);

    var extract_dir = try Fs.openDir(extract_path);
    defer extract_dir.close();

    std.tar.pipeToFileSystem(extract_dir, &reader, .{}) catch |err| {
        switch (err) {
            error.EndOfStream => return,
            else => return err,
        }
    };
    try self.printer.append(" > DECOMPRESSED!\n\n", .{}, .{ .color = .green });
}
