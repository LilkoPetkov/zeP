const std = @import("std");
const Logger = @import("logger");

const c = @cImport({
    @cInclude("zstd.h");
});

pub fn getBound(input: []const u8) usize {
    return c.ZSTD_compressBound(input.len);
}

pub fn compress(
    input: []const u8,
    out: *[]u8,
    max: usize,
    level: i32,
) !usize {
    const size = c.ZSTD_compress(
        out.ptr,
        max,
        input.ptr,
        input.len,
        level,
    );

    if (c.ZSTD_isError(size) != 0) return error.ZstdCompressFailed;
    return size;
}

pub fn decompress(
    input: []const u8,
    out: *[]u8,
    original_size: usize,
) !void {
    const size = c.ZSTD_decompress(
        out.ptr,
        original_size,
        input.ptr,
        input.len,
    );

    if (c.ZSTD_isError(size) != 0) {
        return error.ZstdDecompressFailed;
    }
}
