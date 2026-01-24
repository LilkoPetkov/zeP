const std = @import("std");
const Context = @import("context");
const Constants = @import("constants");
const Commands = @import("commands.zig").Commands;

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
const UpgradeController = @import("commands/_upgrade.zig");
const PathsController = @import("commands/_paths.zig");
const PrebuiltController = @import("commands/_prebuilt.zig");
const PackageController = @import("commands/_package.zig");
const PurgeController = @import("commands/_purge.zig");
const ReleaseController = @import("commands/_release.zig");
const UninstallController = @import("commands/_uninstall.zig");
const VersionController = @import("commands/_version.zig");
const RunnerController = @import("commands/_runner.zig");
const BuilderController = @import("commands/_builder.zig");
const InitController = @import("commands/_init.zig");
const ConfigController = @import("commands/_config.zig");
const BootstrapController = @import("commands/_bootstrap.zig");

const Help = @import("help.zig");

fn conv(c: []const u8) ?Commands {
    return std.meta.stringToEnum(Commands, c);
}

pub fn dispatcher(ctx: *Context, c: []const u8) !void {
    const command = conv(c) orelse return error.InvalidCommand;
    switch (command) {
        .version => {},
        else => {
            try ctx.printer.append(
                "zeP {s}+{s}\n\n",
                .{ Constants.Default.version, Constants.Default.commit },
                .{
                    .color = .bright_black,
                    .weight = .dim,
                },
            );
        },
    }

    const f = switch (command) {
        .init => InitController._initController(ctx),

        .self => ArtifactController._artifactController(ctx, .zep),
        .zep => ArtifactController._artifactController(ctx, .zep),

        .zig => ArtifactController._artifactController(ctx, .zig),

        .upgrade => UpgradeController._upgradeController(ctx),
        .install => InstallController._installController(ctx),
        .add => InstallController._installController(ctx), // Alias for install

        .uninstall => UninstallController._uninstallController(ctx),
        .remove => UninstallController._uninstallController(ctx), // Alias for uninstall

        .auth => AuthController._authController(ctx),
        .prebuilt => PrebuiltController._prebuiltController(ctx),
        .release => ReleaseController._releaseController(ctx),
        .package => PackageController._packageController(ctx),
        .purge => PurgeController._purgeController(ctx),
        .cache => CacheController._cacheController(ctx),
        .doctor => DoctorController._doctorController(ctx),
        .paths => PathsController._pathsController(ctx),
        .version => VersionController._versionController(ctx),

        .info => InfoController._infoController(ctx),
        .list => ListController._listController(ctx),

        .cmd => CmdController._cmdController(ctx),
        .inject => InjectController._injectController(ctx),
        .custom => CustomController._customController(ctx),

        .config => ConfigController._configController(ctx),

        .builder => BuilderController._builderController(ctx),
        .build => BuilderController._builderController(ctx), // Alias for builder

        .runner => RunnerController._runnerController(ctx),
        .run => RunnerController._runnerController(ctx), // Alias for runner

        .bootstrap => BootstrapController._bootstrapController(ctx),
    };
    f catch |err| {
        try ctx.logger.errorf("Error. {any}", .{err}, @src());
        switch (err) {
            error.ZigInvalidSubcommand => {
                Help.zig();
            },
            error.ZepInvalidSubcommand => {
                Help.self();
            },
            error.UninstallMissingArguments => {
                Help.package();
            },
            error.AuthInvalidSubcommand => {
                Help.auth();
            },
            error.PreBuiltInvalidSubcommand => {
                Help.prebuilt();
            },
            error.ReleaseInvalidSubcommand => {
                Help.release();
            },
            error.PackageInvalidSubcommand => {
                Help.package();
            },
            error.CacheInvalidSubcommand => {
                Help.cache();
            },
            error.CustomInvalidSubcommand => {
                Help.custom();
            },
            error.CustomMissingArguments => {
                Help.custom();
            },
            error.InfoMissingArguments => {
                Help.help(ctx);
            },
            error.ListMissingArguments => {
                Help.help(ctx);
            },
            error.CmdInvalidSubcommand => {
                Help.cmd();
            },
            else => {
                Help.help(ctx);
                return err;
            },
        }
    };

    try ctx.logger.info("Done.", @src());
}
