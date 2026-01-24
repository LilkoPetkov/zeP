const std = @import("std");
const Structs = @import("structs");
const Constants = @import("constants");
const Locales = @import("locales");

const Artifact = @import("../../lib/artifact/artifact.zig");
const Context = @import("context");

fn artifactInstall(ctx: *Context, artifact: *Artifact) !void {
    if (ctx.cmds.len < 4) return error.MissingArguments;

    const target_version = if (ctx.cmds.len < 4) "latest" else ctx.cmds[3];
    const target = if (ctx.cmds.len < 5) Constants.Default.resolveDefaultTarget() else ctx.cmds[4];

    artifact.install(target_version, target) catch |err| {
        switch (err) {
            error.UrlNotFound => {
                try ctx.logger.err("Url not found...", @src());
                try ctx.printer.append("Url was not found.\n\n", .{}, .{});
            },
            error.VersionNotFound => {
                try ctx.logger.err("Version not found...", @src());
                try ctx.printer.append("Version {s} was not found.\n\n", .{target_version}, .{});
            },
            error.VersionHasNoPath => {
                try ctx.logger.err("Version has no path...", @src());
                try ctx.printer.append("Version {s} has no path.\n\n", .{target_version}, .{});
            },
            error.TarballNotFound => {
                try ctx.logger.err("Tarball was not found...", @src());
                try ctx.printer.append("Tarball was not found.\n\n", .{}, .{});
            },
            error.AlreadyInstalled => {
                try ctx.printer.append("{s} version already installed.\n", .{artifact.artifact_name}, .{});
                try ctx.printer.append("Switching to {s} - {s}.\n\n", .{ target_version, target }, .{});

                const previous_verbosity = Locales.VERBOSITY_MODE;
                Locales.VERBOSITY_MODE = 0;
                try artifactSwitch(ctx, artifact);
                Locales.VERBOSITY_MODE = previous_verbosity;
            },
            error.InvalidOS => {
                try ctx.printer.append("Invalid Operating System. Installed, but not switched.\n", .{}, .{});
            },
            else => {
                try ctx.logger.err("Installing failed...", @src());
                try ctx.printer.append("Installing failed, err={any}...\n\n", .{err}, .{});
            },
        }
    };
    return;
}

fn artifactUninstall(ctx: *Context, artifact: *Artifact) !void {
    if (ctx.cmds.len < 4) return error.MissingArguments;
    const target_version = ctx.cmds[3];
    const target = if (ctx.cmds.len < 5) Constants.Default.resolveDefaultTarget() else ctx.cmds[4];

    artifact.uninstall(target_version, target) catch |err| {
        switch (err) {
            error.UrlNotFound => {
                try ctx.logger.err("Url not found...", @src());
                try ctx.printer.append("Url was not found.\n\n", .{}, .{});
            },
            error.TarballNotFound => {
                try ctx.logger.err("Tarball was not found...", @src());
                try ctx.printer.append("Tarball was not found.\n\n", .{}, .{});
            },
            error.VersionNotFound => {
                try ctx.logger.err("Version not found...", @src());
                try ctx.printer.append("Version {s} was not found.\n\n", .{target_version}, .{});
            },
            error.VersionNotInstalled => {
                try ctx.logger.err("Version not installed...", @src());
                try ctx.printer.append("Version {s} is not installed.\n\n", .{target_version}, .{});
            },
            else => {
                try ctx.logger.err("Uninsalling failed...", @src());
                try ctx.printer.append("Uninstalling failed\n\n", .{}, .{});
            },
        }
    };
    return;
}

fn artifactSwitch(ctx: *Context, artifact: *Artifact) !void {
    if (ctx.cmds.len < 4) return error.MissingArguments;

    const target_version = ctx.cmds[3];
    const target = if (ctx.cmds.len < 5) Constants.Default.resolveDefaultTarget() else ctx.cmds[4];

    artifact.switchVersion(target_version, target) catch |err| {
        switch (err) {
            error.UrlNotFound => {
                try ctx.logger.err("Url not found...", @src());
                try ctx.printer.append("Url was not found.\n\n", .{}, .{});
            },
            error.TarballNotFound => {
                try ctx.logger.err("Tarball was not found...", @src());
                try ctx.printer.append("Tarball was not found.\n\n", .{}, .{});
            },
            error.VersionNotFound => {
                try ctx.logger.err("Version not found...", @src());
                try ctx.printer.append("Version {s} was not found.\n\n", .{target_version}, .{});
            },
            error.VersionNotInstalled => {
                try ctx.logger.err("Version not installed...", @src());
                try ctx.printer.append("Version {s} is not installed.\n\n", .{target_version}, .{});
            },
            error.InvalidOS => {
                try ctx.printer.append("Invalid Operating System. Cannot switched.\n", .{}, .{});
            },
            else => {
                try ctx.logger.err("Switching failed...", @src());
                try ctx.printer.append("Switching failed\n\n", .{}, .{});
            },
        }
    };
    return;
}

fn artifactList(ctx: *Context, artifact: *Artifact) !void {
    _ = ctx;
    try artifact.list();
    return;
}

fn artifactUpgrade(ctx: *Context, artifact: *Artifact) !void {
    const target = if (ctx.cmds.len < 4) Constants.Default.resolveDefaultTarget() else ctx.cmds[3];

    artifact.install("latest", target) catch |err| {
        switch (err) {
            error.AlreadyInstalled => {
                try ctx.printer.append("{s} already at latest version.\n", .{artifact.artifact_name}, .{});
            },
            error.InvalidOS => {
                try ctx.printer.append("Invalid Operating System.\n", .{}, .{});
            },
            else => {
                try ctx.logger.err("Upgrading failed...", @src());
                try ctx.printer.append("Upgrading failed\n\n", .{}, .{});
            },
        }
    };
    return;
}

fn artifactCache(ctx: *Context, artifact: *Artifact) !void {
    if (ctx.cmds.len < 4) return error.MissingArguments;
    const cache_cmd = ctx.cmds[3];
    if (std.mem.eql(u8, cache_cmd, "list")) {
        try artifactCacheList(ctx, artifact);
    } else if (std.mem.eql(u8, cache_cmd, "size")) {
        try artifactCacheSize(ctx, artifact);
    } else if (std.mem.eql(u8, cache_cmd, "clean")) {
        try artifactCacheClean(ctx, artifact);
    }
}

fn artifactCacheList(_: *Context, artifact: *Artifact) !void {
    try artifact.listCache();
    return;
}

fn artifactCacheClean(ctx: *Context, artifact: *Artifact) !void {
    const target_version = if (ctx.cmds.len < 5) null else ctx.cmds[4];
    try artifact.cleanCache(target_version);
    return;
}

fn artifactCacheSize(_: *Context, artifact: *Artifact) !void {
    try artifact.sizeCache();
    return;
}

pub fn _artifactController(
    ctx: *Context,
    artifact_type: Structs.Extras.ArtifactType,
) !void {
    if (ctx.cmds.len < 3) {
        switch (artifact_type) {
            .zep => return error.ZepInvalidSubcommand,
            .zig => return error.ZigInvalidSubcommand,
        }
    }

    var artifact = try Artifact.init(
        ctx,
        artifact_type,
    );
    defer artifact.deinit();

    const arg = ctx.cmds[2];

    if (std.mem.eql(u8, arg, "install")) {
        try artifactInstall(ctx, &artifact);
    } else if (std.mem.eql(u8, arg, "uninstall")) {
        try artifactUninstall(ctx, &artifact);
    } else if (std.mem.eql(u8, arg, "upgrade")) {
        try artifactUpgrade(ctx, &artifact);
    } else if (std.mem.eql(u8, arg, "switch")) {
        try artifactSwitch(ctx, &artifact);
    } else if (std.mem.eql(u8, arg, "list") or
        std.mem.eql(u8, arg, "ls"))
    {
        try artifactList(ctx, &artifact);
    } else if (std.mem.eql(u8, arg, "cache")) {
        try artifactCache(ctx, &artifact);
    } else {
        switch (artifact_type) {
            .zep => return error.ZepInvalidSubcommand,
            .zig => return error.ZigInvalidSubcommand,
        }
    }
}
