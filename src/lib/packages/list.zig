const std = @import("std");

const Context = @import("context");
const Args = @import("args");
const Structs = @import("structs");
const Resolver = @import("resolver");

pub fn list(
    ctx: *Context,
    package_name: []const u8,
) !void {
    try ctx.logger.info("Listing Package", @src());

    const install_args = Args.parseInstall(ctx.options);
    var install_type: Structs.Extras.InstallType = .zep;
    if (install_args.zep) install_type = Structs.Extras.InstallType.zep;
    if (install_args.github) install_type = Structs.Extras.InstallType.github;
    if (install_args.gitlab) install_type = Structs.Extras.InstallType.gitlab;
    if (install_args.codeberg) install_type = Structs.Extras.InstallType.codeberg;
    if (install_args.local) install_type = Structs.Extras.InstallType.local;

    var resolver = Resolver.init(ctx);
    var package = try resolver.fetchPackage(
        package_name,
        install_type,
    );
    defer package.deinit(ctx.allocator);
    try ctx.printer.append("Available versions for {s}:\n", .{package_name}, .{});

    const versions = package.versions;
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
