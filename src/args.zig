const std = @import("std");
const Constants = @import("constants");

const DefaultArgs = struct {
    verbosity: usize,
};
pub fn parseDefault(
    args: [][:0]u8,
) DefaultArgs {
    var verbosity: usize = 1;
    for (args) |arg| {
        if (!std.mem.startsWith(u8, arg, "--verbosity") and
            !std.mem.startsWith(u8, arg, "-V")) continue;
        var split = std.mem.splitAny(u8, arg, "=");
        const val = split.next() orelse continue;
        const parsed = std.fmt.parseInt(u8, val, 10) catch 1;
        verbosity = parsed;
    }

    return DefaultArgs{
        .verbosity = verbosity,
    };
}

const DoctorArgs = struct {
    fix: bool,
};
pub fn parseDoctor(
    args: [][:0]u8,
) DoctorArgs {
    var fix: bool = false;
    for (args) |arg| {
        if (!std.mem.startsWith(u8, arg, "--fix") and
            !std.mem.startsWith(u8, arg, "-F")) continue;
        fix = true;
    }
    return DoctorArgs{
        .fix = fix,
    };
}

const UninstallArgs = struct {
    global: bool,
    force: bool,
};
pub fn parseUninstall(
    args: [][:0]u8,
) UninstallArgs {
    var global: bool = false;
    var force: bool = false;
    for (args) |arg| {
        if (std.mem.startsWith(u8, arg, "--global") or
            std.mem.startsWith(u8, arg, "-G"))
        {
            global = true;
        }
        if (std.mem.startsWith(u8, arg, "--force") or
            std.mem.startsWith(u8, arg, "-F"))
        {
            force = true;
        }
    }

    return UninstallArgs{
        .global = global,
        .force = force,
    };
}

const InstallArgs = struct {
    inject: bool,
    unverified: bool,
    github: bool,
    codeberg: bool,
    gitlab: bool,
};
pub fn parseInstall(
    args: [][:0]u8,
) InstallArgs {
    var inject: bool = false;
    var unverified: bool = false;
    var github: bool = false;
    var codeberg: bool = false;
    var gitlab: bool = false;
    for (args) |arg| {
        if (std.mem.startsWith(u8, arg, "--inject") or
            std.mem.startsWith(u8, arg, "-I"))
        {
            inject = true;
        }
        if (std.mem.startsWith(u8, arg, "--unverified") or
            std.mem.startsWith(u8, arg, "-U"))
        {
            unverified = true;
        }
        if (std.mem.startsWith(u8, arg, "--github") or
            std.mem.startsWith(u8, arg, "-GH"))
        {
            github = true;
        }
        if (std.mem.startsWith(u8, arg, "--codeberg") or
            std.mem.startsWith(u8, arg, "-CB"))
        {
            codeberg = true;
        }
        if (std.mem.startsWith(u8, arg, "--gitlab") or
            std.mem.startsWith(u8, arg, "-GL"))
        {
            gitlab = true;
        }
    }

    return InstallArgs{
        .inject = inject,
        .unverified = unverified,
        .github = github,
        .codeberg = codeberg,
        .gitlab = gitlab,
    };
}

const BootstrapArgs = struct {
    zig: []const u8,
    pkgs: []const u8,
};
pub fn parseBootstrap(
    args: [][:0]u8,
) BootstrapArgs {
    var zig: []const u8 = "";
    var raw_packages: []const u8 = "";
    for (args) |arg| {
        if (!std.mem.startsWith(u8, arg, "--zig") or
            !std.mem.startsWith(u8, arg, "-Z"))
        {
            var split = std.mem.splitAny(u8, arg, "=");
            const val = split.next() orelse continue;
            zig = val;
        }
        if (!std.mem.startsWith(u8, arg, "--packages") or
            !std.mem.startsWith(u8, arg, "-P"))
        {
            var split = std.mem.splitAny(u8, arg, "=");
            const val = split.next() orelse continue;
            raw_packages = val;
        }
    }

    return BootstrapArgs{
        .zig = zig,
        .pkgs = raw_packages,
    };
}

const RunnerArgs = struct {
    target: []const u8,
    args: []const u8,
};
pub fn parseRunner(
    args: [][:0]u8,
) RunnerArgs {
    var target: []const u8 = "";
    var raw_args: []const u8 = "";
    for (args) |arg| {
        if (!std.mem.startsWith(u8, arg, "--target") or
            !std.mem.startsWith(u8, arg, "-T"))
        {
            var split = std.mem.splitAny(u8, arg, "=");
            const val = split.next() orelse continue;
            target = val;
        }
        if (!std.mem.startsWith(u8, arg, "--args") or
            !std.mem.startsWith(u8, arg, "-A"))
        {
            var split = std.mem.splitAny(u8, arg, "=");
            const val = split.next() orelse continue;
            raw_args = val;
        }
    }

    return RunnerArgs{
        .target = target,
        .args = raw_args,
    };
}
