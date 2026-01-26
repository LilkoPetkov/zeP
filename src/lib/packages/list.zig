const std = @import("std");

const Context = @import("context");

pub fn list(
    ctx: *Context,
    package_name: []const u8,
) !void {
    try ctx.logger.info("Listing Package", @src());

    var package = try ctx.fetcher.fetchPackage(
        package_name,
        ctx.logger,
    );
    defer package.deinit(ctx.allocator);

    const versions = package.versions;
    try ctx.printer.append("Available versions for {s}:\n", .{package_name}, .{});
    if (versions.len == 0) {
        try ctx.printer.append("  NO VERSIONS FOUND!\n\n", .{}, .{ .color = .red });
        return;
    } else {
        for (versions) |v| {
            try ctx.printer.append(" > version: {s} (zig: {s})\n", .{ v.version, v.zig_version }, .{});
        }
    }
    try ctx.printer.append("\n", .{}, .{});
    return;
}
