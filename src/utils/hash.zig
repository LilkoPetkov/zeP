const std = @import("std");

pub fn hashData(allocator: std.mem.Allocator, url: []const u8) ![]u8 {
    const uri = try std.Uri.parse(url);

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var server_buf: [4096 * 4]u8 = undefined;
    var req = try client.open(.GET, uri, .{ .server_header_buffer = &server_buf });
    defer req.deinit();
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});

    try req.send();
    try req.finish();
    try req.wait();
    const reader = req.reader();

    var buf: [4096]u8 = undefined;
    while (true) {
        const n = try reader.read(&buf);
        if (n == 0) break;
        hasher.update(buf[0..n]);
    }

    var hash: [32]u8 = undefined;
    hasher.final(&hash);

    const out = try std.fmt.allocPrint(allocator, "{x}", .{std.fmt.fmtSliceHexLower(&hash)});
    return out;
}
