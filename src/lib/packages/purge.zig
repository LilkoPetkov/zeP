const std = @import("std");

const Constants = @import("constants");
const Structs = @import("structs");
const Locales = @import("locales");

const Fs = @import("io").Fs;
const Prompt = @import("cli").Prompt;

const Uninstaller = @import("uninstall.zig");
const Init = @import("init.zig");

const Context = @import("context");
pub fn purge(ctx: *Context) !void {
    try ctx.logger.info("Purging Packages", @src());
    const lock = try ctx.manifest.readManifest(Structs.ZepFiles.Lock, Constants.Default.package_files.lock);
    defer lock.deinit();

    try ctx.printer.append("This project contains {d} packages.\n", .{lock.value.packages.len}, .{});
    const answer = try Prompt.input(
        ctx.allocator,
        &ctx.printer,
        "Purge them all? (y/N) ",
        .{},
    );
    if (answer.len == 0 or
        std.mem.startsWith(u8, answer, "n") or
        std.mem.startsWith(u8, answer, "N"))
    {
        try ctx.printer.append("\nOk.\n", .{}, .{});
        return;
    }

    try ctx.printer.append("\nPurging packages...\n", .{}, .{});

    const previous_verbosity = Locales.VERBOSITY_MODE;
    Locales.VERBOSITY_MODE = 0;

    if (!Fs.existsFile(Constants.Default.package_files.lock)) {
        var initer = try Init.init(
            ctx,
            true,
        );
        try initer.commitInit();
        try ctx.printer.append("Nothing to uninstall.\n", .{}, .{});
        return;
    }

    var uninstaller = Uninstaller.init(
        ctx,
    );
    for (lock.value.root.packages) |package_id| {
        var split = std.mem.splitScalar(u8, package_id, '@');
        const package_name = split.first();
        try ctx.printer.append(" > Uninstalling - {s} ", .{package_id}, .{ .verbosity = 0 });
        uninstaller.uninstall(package_name) catch {
            try ctx.printer.append(" >> failed!\n", .{}, .{ .verbosity = 0, .color = .red });
            std.Thread.sleep(std.time.ms_per_s * 100);
            continue;
        };

        try ctx.printer.append(" >> done!\n", .{}, .{ .verbosity = 0, .color = .green });

        // small delay to avoid race conditions
        std.Thread.sleep(std.time.ms_per_s * 100);
    }

    try ctx.printer.append("\nPurged packages!\n", .{}, .{ .verbosity = 0, .color = .green });
    Locales.VERBOSITY_MODE = previous_verbosity;
}
