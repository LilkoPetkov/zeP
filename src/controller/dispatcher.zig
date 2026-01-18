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

    custom,
    info,
    list,

    paths,
    prebuilt,
    package,
    purge,
    release,
    setup,
    uninstall,
    version,
    whoami,
    runner,
    run, // (hidden) alternative

    builder,
    build, // (hidden) alternative
    bootstrap,
    init,
    new,
    manifest,
};

const CustomController = @import("commands/_custom.zig");
const InfoController = @import("commands/_info.zig");
const ListController = @import("commands/_list.zig");
const ArtifactController = @import("commands/_artifact.zig");
const AuthController = @import("commands/_auth.zig");
const CacheController = @import("commands/_cache.zig");
const CmdController = @import("commands/_cmd.zig");
const DoctorController = @import("commands/_doctor.zig");
const InjectController = @import("commands/_inject.zig");
const InstallController = @import("commands/_install.zig");
const PathsController = @import("commands/_paths.zig");
const PrebuiltController = @import("commands/_prebuilt.zig");
const PackageController = @import("commands/_package.zig");
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
        .package => PackageController._packageController(ctx),
        .purge => PurgeController._purgeController(ctx),
        .cache => CacheController._cacheController(ctx),
        .doctor => DoctorController._doctorController(ctx),
        .paths => PathsController._pathsController(ctx),
        .setup => SetupController._setupController(ctx),
        .version => VersionController._versionController(ctx),
        .whoami => WhoamiController._whoamiController(ctx),

        .custom => CustomController._customController(ctx),
        .info => InfoController._infoController(ctx),
        .list => ListController._listController(ctx),

        .cmd => CmdController._cmdController(ctx),
        .inject => InjectController._injectController(ctx),
        .manifest => ManifestController._manifestController(ctx),
        .builder => BuilderController._builderController(ctx),
        .build => BuilderController._builderController(ctx), // (hidden) alternative

        .runner => RunnerController._runnerController(ctx),
        .run => RunnerController._runnerController(ctx), // (hidden) alternative

        .new => NewController._newController(ctx),
        .init => InitController._initController(ctx),
        .bootstrap => BootstrapController._bootstrapController(ctx),
    };
    f catch |err| {
        try ctx.logger.errorf("Error. {any}", .{err}, @src());
        const cmd = try std.mem.join(ctx.allocator, " ", ctx.args);
        defer ctx.allocator.free(cmd);
        std.debug.print(
            "Invalid Command\n  $ {s}\n\n",
            .{cmd},
        );
        switch (err) {
            error.ZigInvalidSubcommand => {
                std.debug.print(
                    "--- ZIG COMMANDS ---\n  zep zig [uninstall|switch] [version]\n  zep zig install [version] (target)\n  zep zig list\n\n",
                    .{},
                );
            },
            error.ZepInvalidSubcommand => {
                std.debug.print(
                    "--- ZEP COMMANDS ---\n  zep zep [uninstall|switch] [version]\n  zep zep install [version] (target)\n  zep zep list\n\n",
                    .{},
                );
            },
            error.UninstallMissingArguments => {
                std.debug.print(
                    "--- PACKAGE COMMANDS ---\n  zep uninstall [target]\n\n",
                    .{},
                );
            },
            error.AuthInvalidSubcommand => {
                std.debug.print(
                    "--- AUTH COMMANDS ---\n  zep auth login\n  zep auth register\n  zep auth logout\n  zep whoami\n\n",
                    .{},
                );
            },
            error.PreBuiltInvalidSubcommand => {
                std.debug.print(
                    "--- PREBUILT COMMANDS ---\n  zep prebuilt [build|use] [name] (target)\n  zep prebuilt delete [name]\n  zep prebuilt list\n\n",
                    .{},
                );
            },
            error.ReleaseInvalidSubcommand => {
                std.debug.print(
                    "--- RELEASE COMMANDS ---\n  zep release list\n  zep release create\n  zep release delete\n\n",
                    .{},
                );
            },
            error.PackageInvalidSubcommand => {
                std.debug.print(
                    "--- YOUR PACKAGE COMMANDS ---\n  zep package list\n  zep package create\n  zep package delete\n\n",
                    .{},
                );
            },
            error.CacheInvalidSubcommand => {
                std.debug.print(
                    "--- CACHE COMMANDS ---\n  zep cache [list|clean|size] (package_id)\n\n",
                    .{},
                );
            },
            error.CustomInvalidSubcommand => {
                std.debug.print(
                    "--- CUSTOM PACKAGE COMMANDS ---\n  zep custom remove [custom package name]\n  zep custom add\n\n",
                    .{},
                );
            },
            error.CustomMissingArguments => {
                std.debug.print(
                    "--- CUSTOM PACKAGE COMMANDS ---\n   zep custom remove [custom package name]\n  zep custom add\n\n",
                    .{},
                );
            },
            error.InfoMissingArguments => {
                std.debug.print(
                    "--- PACKAGE COMMANDS ---\n  zep info [target]\n\n",
                    .{},
                );
            },
            error.ListMissingArguments => {
                std.debug.print(
                    "--- PACKAGE COMMANDS ---\n  zep list [target]\n\n",
                    .{},
                );
            },
            error.CmdInvalidSubcommand => {
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
