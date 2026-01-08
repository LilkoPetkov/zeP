const std = @import("std");
const Context = @import("context");

const Commands = enum {
    zep,
    zig,
    auth,
    cache,
    cmd,
    doctor,
    inject,
    install,
    package,
    paths,
    prebuilt,
    project,
    purge,
    release,
    setup,
    uninstall,
    version,
    whoami,
    runner,
    builder,
    bootstrap,
    init,
    new,
    manifest,
};

const PackageController = @import("commands/_package.zig");
const ArtifactController = @import("commands/_artifact.zig");
const AuthController = @import("commands/_auth.zig");
const CacheController = @import("commands/_cache.zig");
const CmdController = @import("commands/_cmd.zig");
const DoctorController = @import("commands/_doctor.zig");
const InjectController = @import("commands/_inject.zig");
const InstallController = @import("commands/_install.zig");
const PathsController = @import("commands/_paths.zig");
const PrebuiltController = @import("commands/_prebuilt.zig");
const ProjectController = @import("commands/_project.zig");
const PurgeController = @import("commands/_purge.zig");
const ReleaseController = @import("commands/_release.zig");
const SetupController = @import("commands/_setup.zig");
const UninstallController = @import("commands/_uninstall.zig");
const VersionController = @import("commands/_version.zig");
const WhoamiController = @import("commands/_whoami.zig");
const RunnerController = @import("commands/_runner.zig");
const BuilderController = @import("commands/_builder.zig");
const InitController = @import("commands/_init.zig");
const NewController = @import("commands/_new.zig");
const ManifestController = @import("commands/_manifest.zig");
const BootstrapController = @import("commands/_bootstrap.zig");

fn conv(c: []const u8) ?Commands {
    return std.meta.stringToEnum(Commands, c);
}

pub fn dispatcher(ctx: *Context, c: []const u8) !void {
    const command = conv(c) orelse return error.InvalidCommand;
    const f = switch (command) {
        .zep => ArtifactController._artifactController(ctx, .zep),
        .zig => ArtifactController._artifactController(ctx, .zig),
        .install => InstallController._installController(ctx),
        .uninstall => UninstallController._uninstallController(ctx),
        .auth => AuthController._authController(ctx),
        .prebuilt => PrebuiltController._prebuiltController(ctx),
        .release => ReleaseController._releaseController(ctx),
        .project => ProjectController._projectController(ctx),
        .purge => PurgeController._purgeController(ctx),
        .cache => CacheController._cacheController(ctx),
        .doctor => DoctorController._doctorController(ctx),
        .paths => PathsController._pathsController(ctx),
        .setup => SetupController._setupController(ctx),
        .version => VersionController._versionController(ctx),
        .whoami => WhoamiController._whoamiController(ctx),
        .package => PackageController._packageController(ctx),
        .cmd => CmdController._cmdController(ctx),
        .inject => InjectController._injectController(ctx),
        .manifest => ManifestController._manifestController(ctx),
        .builder => BuilderController._builderController(ctx),
        .runner => RunnerController._runnerController(ctx),
        .new => NewController._newController(ctx),
        .init => InitController._initController(ctx),
        .bootstrap => BootstrapController._bootstrapController(ctx),
    };
    f catch |err| {
        try ctx.logger.errorf("Error. {any}", .{err}, @src());
        switch (err) {
            error.ZigMissingSubcommand => {
                std.debug.print(
                    "--- ZIG COMMANDS ---\n  zep zig [uninstall|switch] [version]\n",
                    .{},
                );
                std.debug.print(
                    "  zep zig install [version] (target)\n  zep zig list\n  zep zig prune\n\n",
                    .{},
                );
            },
            error.ZepMissingSubcommand => {
                std.debug.print(
                    "--- ZEP COMMANDS ---\n  zep zep [uninstall|switch] [version]\n",
                    .{},
                );
                std.debug.print(
                    "  zep zep install [version] (target)\n  zep zep list\n  zep zep prune\n\n",
                    .{},
                );
            },
            error.UninstallMissingArguments => {
                std.debug.print(
                    "--- PACKAGE COMMANDS ---\n  zep uninstall [target]\n\n",
                    .{},
                );
            },
            error.AuthMissingSubcommand => {
                std.debug.print(
                    "--- AUTH COMMANDS ---\n  zep auth login\n  zep auth register\n  zep auth logout\n  zep whoami\n\n",
                    .{},
                );
            },
            error.PreBuiltMissingSubcommand => {
                std.debug.print(
                    "--- PREBUILT COMMANDS ---\n  zep prebuilt [build|use] [name] (target)\n\n",
                    .{},
                );
                std.debug.print(
                    "  zep prebuilt delete [name]\n  zep prebuilt list\n\n",
                    .{},
                );
            },
            error.ReleaseMissingSubcommand => {
                std.debug.print(
                    "--- RELEASE COMMANDS ---\n  zep release list\n  zep release create\n  zep release delete\n\n",
                    .{},
                );
            },
            error.ProjectMissingSubcommand => {
                std.debug.print(
                    "--- PROJECT COMMANDS ---\n  zep project list\n  zep project create\n  zep project delete\n\n",
                    .{},
                );
            },
            error.CacheMissingSubcommand => {
                std.debug.print(
                    "--- CACHE COMMANDS ---\n  zep cache [list|clean|size] (package_id)\n\n",
                    .{},
                );
            },
            error.PackageMissingSubcommand => {
                std.debug.print(
                    "--- CUSTOM PACKAGE COMMANDS ---\n  zep package list [target]\n  zep package info [target]\n  zep package remove [custom package name]\n  zep package add\n\n",
                    .{},
                );
            },
            error.PackageMissingArguments => {
                std.debug.print(
                    "--- CUSTOM PACKAGE COMMANDS ---\n  zep package list [target]\n  zep package info [target]\n  zep package remove [custom package name]\n  zep package add\n\n",
                    .{},
                );
            },
            error.CmdMissingSubcommand => {
                std.debug.print(
                    "--- CMD COMMANDS ---\n  zep cmd run [cmd]\n  zep cmd add\n  zep cmd remove <cmd>\n  zep cmd list\n\n",
                    .{},
                );
            },
            error.NewMissingArguments => {
                std.debug.print(
                    "--- NEW COMMAND ---\n  zep new <name>\n\n",
                    .{},
                );
            },
            else => return err,
        }
    };

    try ctx.logger.info("Done.", @src());
}
