const std = @import("std");

pub const Builder = @This();

const Constants = @import("constants");
const Structs = @import("structs");
const Fs = @import("io").Fs;
const Context = @import("context");

/// Initializes a Child Processor, and builds zig project
pub fn build(ctx: *Context) !std.ArrayList([]u8) {
    try ctx.logger.info("Building", @src());

    const read_manifest = try ctx.manifest.readManifest(
        Structs.ZepFiles.PackageJsonStruct,
        Constants.Extras.package_files.manifest,
    );
    defer read_manifest.deinit();

    var target = read_manifest.value.build.target;
    if (target.len == 0) {
        target = Constants.Default.resolveDefaultTarget();
    }

    var buf: [64]u8 = undefined;
    const execs = try std.fmt.bufPrint(
        &buf,
        "-Dtarget={s}",
        .{target},
    );
    const args = [_][]const u8{ "zig", "build", "-Doptimize=ReleaseSmall", execs, "-p", "zep-out/" };
    try ctx.printer.append("\nExecuting: \n$ {s}!\n\n", .{try std.mem.join(ctx.allocator, " ", &args)}, .{ .color = .green });

    var process = std.process.Child.init(&args, ctx.allocator);
    _ = try process.spawnAndWait();
    try ctx.printer.append("\nFinished executing!\n", .{}, .{ .color = .green });

    const target_directory = try std.fs.path.join(ctx.allocator, &.{ "zep-out", "bin" });
    defer ctx.allocator.free(target_directory);

    const dir = try Fs.openOrCreateDir(target_directory);
    var iter = dir.iterate();

    var entries = try std.ArrayList([]const u8).initCapacity(ctx.allocator, 5);
    defer entries.deinit(ctx.allocator);
    while (try iter.next()) |entry| {
        try entries.append(ctx.allocator, entry.name);
    }

    if (entries.items.len == 0) {
        return error.NoFile;
    }

    var target_files = try std.ArrayList([]u8).initCapacity(ctx.allocator, 5);
    for (entries.items) |entry| {
        const target_file = try std.fs.path.join(ctx.allocator, &.{ target_directory, entry });
        try target_files.append(ctx.allocator, target_file);
    }
    return target_files;
}
