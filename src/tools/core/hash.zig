const std = @import("std");
const Constants = @import("constants");
const Logger = @import("logger");

/// Get hash from any url
pub fn hashData(allocator: std.mem.Allocator, url: []const u8) ![]u8 {
    // const start = std.time.milliTimestamp();

    const uri = std.Uri.parse(url) catch {
        return error.InvalidUrl;
    };

    var hasher = std.crypto.hash.sha2.Sha256.init(.{});

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var body = std.Io.Writer.Allocating.init(allocator);

    const fetched = client.fetch(.{
        .location = .{ .uri = uri },
        .method = .GET,
        .response_writer = &body.writer,
    }) catch |err| {
        return err;
    };

    if (fetched.status == .not_found) {
        return error.NotFound;
    }

    const data = body.written();
    hasher.update(data);

    var hash: [32]u8 = undefined;
    hasher.final(&hash);

    const out = try std.fmt.allocPrint(allocator, "{x}", .{hash});

    // const elapsed = std.time.milliTimestamp() - start;
    return out;
}
