const std = @import("std");
const Constants = @import("constants");

pub const logly = @import("logly");

pub var logger_instance: ?*logly.Logger = null;

pub fn init(
    alloc: std.mem.Allocator,
    log_location: []u8,
) !void {
    if (logger_instance != null) return;

    var config = logly.Config.default();
    config.auto_sink = false;
    config.check_for_updates = false;
    config.console = false;
    config.debug_mode = false;
    config.global_console_display = false;

    const logger = try logly.Logger.initWithConfig(alloc, config);
    logger.configure(config);

    _ = try logger.add(.{
        .path = log_location,
        .size_limit = 10 * Constants.Default.mb,
        .retention = 5,
    });

    try logger.bind("app", .{ .string = "zep" });
    try logger.bind("version", .{ .string = Constants.Default.version });

    logger_instance = logger;
}

pub fn deinit() void {
    if (logger_instance) |*l| {
        l.deinit();
        logger_instance = null;
    }
}

pub fn get() *logly.Logger {
    return logger_instance orelse
        @panic("Logger used before init");
}
