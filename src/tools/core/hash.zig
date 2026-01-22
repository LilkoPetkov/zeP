const std = @import("std");
const Constants = @import("constants");
const Logger = @import("logger");

/// Get hash from any url
pub fn hashDataByUrl(
    allocator: std.mem.Allocator,
    url: []const u8,
    logger: *Logger.logly.Logger,
) ![]u8 {
    try logger.infof("Getting hash from = {s} [{d}]", .{ url, url.len }, @src());
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var body = std.Io.Writer.Allocating.init(allocator);
    defer body.deinit();

    const clean_url = std.mem.trim(u8, url, " \n\t\r");
    const uri = try std.Uri.parse(clean_url);

    const fetched = try client.fetch(.{
        .location = .{ .uri = uri },
        .method = .GET,
        .response_writer = &body.writer,
    });
    try logger.infof("Fetched with status {any}!", .{fetched.status}, @src());
    if (fetched.status == .not_found) {
        return error.NotFound;
    }

    const data = body.written();
    const hashed = try hashData(
        allocator,
        data,
        logger,
    );
    return hashed;
}

pub fn hashData(
    allocator: std.mem.Allocator,
    data: []const u8,
    logger: *Logger.logly.Logger,
) ![]u8 {
    try logger.infof("Hashing data now!", .{}, @src());

    var hasher = std.crypto.hash.sha2.Sha256.init(.{});

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();
    hasher.update(data);

    var hash: [32]u8 = undefined;
    hasher.final(&hash);

    const out = try std.fmt.allocPrint(allocator, "{x}", .{hash});
    return out;
}
