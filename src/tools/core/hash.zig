const std = @import("std");
const Constants = @import("constants");
const Logger = @import("logger");

/// Get hash from any url
pub fn hashDataByUrl(allocator: std.mem.Allocator, url: []const u8) ![]u8 {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var body = std.Io.Writer.Allocating.init(allocator);
    defer body.deinit();

    const fetched = try client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .response_writer = &body.writer,
    });

    if (fetched.status == .not_found) {
        return error.NotFound;
    }

    const data = body.written();
    const hashed = try hashData(allocator, data);
    return hashed;
}

pub fn hashData(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();
    hasher.update(data);

    var hash: [32]u8 = undefined;
    hasher.final(&hash);

    const out = try std.fmt.allocPrint(allocator, "{x}", .{hash});
    return out;
}
