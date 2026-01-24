const std = @import("std");
const mvzr = @import("mvzr");

pub const Release = @This();

const Constants = @import("constants");
const Structs = @import("structs");

const Prompt = @import("cli").Prompt;
const Fs = @import("io").Fs;
const Compressor = @import("core").Compressor;

const Packages = @import("package.zig");

const FetchOptions = struct {
    payload: ?[]const u8 = null,
    headers: []const std.http.Header = &.{},
    method: std.http.Method = .POST,
};

const boundary =
    "----eb542ed298bc07fa2f58d09191f02dbbffbaa477";

const Context = @import("context");

/// Handles Packages
ctx: *Context,

pub fn init(ctx: *Context) Release {
    return .{
        .ctx = ctx,
    };
}

pub fn delete(self: *Release) !void {
    try self.ctx.logger.info("Deleting Release", @src());

    var manifest = try self.ctx.manifest.readManifest(Structs.Manifests.Auth, self.ctx.paths.auth_manifest);
    defer manifest.deinit();
    if (manifest.value.token.len == 0) return error.NotAuthed;

    var packages = try self.ctx.fetcher.fetchPackages();
    defer packages.deinit(self.ctx.allocator);

    try self.ctx.printer.append("Available packages:\n", .{}, .{});
    if (packages.items.len == 0) {
        try self.ctx.printer.append("-- No packages --\n\n", .{}, .{ .color = .bright_red });
        return;
    }

    for (packages.items, 0..) |r, i| {
        try self.ctx.printer.append(" [{d}] - {s}\n", .{ i, r.Name }, .{});
    }
    try self.ctx.printer.append("\n", .{}, .{});

    const package_index_str = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        "TARGET >> ",
        .{ .required = true },
    );

    const package_index = std.fmt.parseInt(
        usize,
        package_index_str,
        10,
    ) catch return error.InvalidSelection;

    if (package_index >= packages.items.len)
        return error.InvalidSelection;

    const package_target = packages.items[package_index];
    try self.ctx.printer.append("Selected: {s}\n\n", .{package_target.Name}, .{ .color = .bright_black });

    var client = std.http.Client{ .allocator = self.ctx.allocator };
    defer client.deinit();

    var releases = try self.ctx.fetcher.fetchReleases(package_target.Name);
    defer releases.deinit(self.ctx.allocator);

    try self.ctx.printer.append("Available releases:\n", .{}, .{});
    if (releases.items.len == 0) {
        try self.ctx.printer.append("-- No releases --\n\n", .{}, .{ .color = .bright_red });
        return;
    }
    for (releases.items, 0..) |v, i| {
        try self.ctx.printer.append(
            "  [{d}] - {s} {s}\n",
            .{ i, package_target.Name, v.Release },
            .{ .color = .bright_blue },
        );
    }
    try self.ctx.printer.append("\n", .{}, .{});
    const release_index_str = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        "TARGET >> ",
        .{ .required = true },
    );

    const release_index = std.fmt.parseInt(
        usize,
        release_index_str,
        10,
    ) catch return error.InvalidSelection;

    if (release_index >= releases.items.len)
        return error.InvalidSelection;

    const release_target = releases.items[release_index];
    try self.ctx.printer.append("Selected: {s}\n\n", .{release_target.Release}, .{ .color = .bright_black });

    const url = try std.fmt.allocPrint(
        self.ctx.allocator,
        Constants.Default.zep_url ++ "/api/v1/release?id={s}&package_id={s}",
        .{ release_target.ID, package_target.ID },
    );
    const delete_release_response = self.ctx.fetcher.fetch(
        url,
        &client,
        .{
            .method = .DELETE,
            .headers = &.{
                std.http.Header{
                    .name = "Authorization",
                    .value = try manifest.value.bearer(),
                },
            },
        },
    ) catch return error.FetchFailed;

    defer delete_release_response.deinit();
    const delete_release_object = delete_release_response.value.object;
    const is_delete_release_successful = delete_release_object.get("success") orelse return;
    if (!is_delete_release_successful.bool) {
        try self.ctx.printer.append("Failed.\n", .{}, .{ .color = .bright_red });
        return;
    }

    try self.ctx.printer.append("Deleted.\n", .{}, .{});
}

pub fn list(self: *Release) !void {
    try self.ctx.logger.info("Listing Release", @src());

    var packages = try self.ctx.fetcher.fetchPackages();
    defer packages.deinit(self.ctx.allocator);

    try self.ctx.printer.append("Available packages:\n", .{}, .{});
    if (packages.items.len == 0) {
        try self.ctx.logger.info("No Package", @src());
        try self.ctx.printer.append("-- No packages --\n\n", .{}, .{ .color = .bright_red });
        return;
    }

    for (packages.items, 0..) |r, i| {
        try self.ctx.printer.append(" [{d}] - {s}\n", .{ i, r.Name }, .{});
    }
    try self.ctx.printer.append("\n", .{}, .{});

    const package_index_str = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        "TARGET >> ",
        .{ .required = true },
    );

    const package_index = std.fmt.parseInt(
        usize,
        package_index_str,
        10,
    ) catch return error.InvalidSelection;

    try self.ctx.logger.infof("Package Selected {d}", .{package_index}, @src());

    if (package_index >= packages.items.len) {
        try self.ctx.logger.info("Invalid Package Selected", @src());
        return error.InvalidSelection;
    }

    const package_target = packages.items[package_index];
    try self.ctx.printer.append("Selected: {s}\n\n", .{package_target.Name}, .{ .color = .bright_black });

    var releases = try self.ctx.fetcher.fetchReleases(package_target.Name);
    defer releases.deinit(self.ctx.allocator);

    try self.ctx.printer.append("Available releases:\n", .{}, .{});
    if (releases.items.len == 0) {
        try self.ctx.logger.info("No Releases for Package", @src());
        try self.ctx.printer.append("-- No releases --\n\n", .{}, .{ .color = .bright_red });
    }

    for (releases.items, 0..) |v, i| {
        try self.ctx.printer.append(
            "  [{d}] - {s} {s}\n",
            .{ i, package_target.Name, v.Release },
            .{ .color = .bright_blue },
        );
    }
    try self.ctx.printer.append("\n", .{}, .{});
}

const TEMPORARY_DIRECTORY_PATH = ".zep/.ZEPtmp";
const TEMPORARY_FILE = "pkg.tar.zstd";
fn compressPackage(self: *Release) ![]const u8 {
    const output = TEMPORARY_DIRECTORY_PATH ++ "/" ++ TEMPORARY_FILE;
    try self.ctx.compressor.compress(".", output);

    try self.ctx.printer.append(
        "Compressed!\n\n",
        .{},
        .{ .color = .green },
    );

    return output;
}

fn formField(
    self: *Release,
    name: []const u8,
    value: []const u8,
) ![]const u8 {
    return std.fmt.allocPrint(
        self.ctx.allocator,
        "--{s}\r\n" ++
            "Content-Disposition: form-data; name=\"{s}\"\r\n\r\n" ++
            "{s}\r\n",
        .{ boundary, name, value },
    );
}

fn formFileHeader(
    self: *Release,
    filename: []const u8,
    mime: []const u8,
) ![]const u8 {
    return std.fmt.allocPrint(
        self.ctx.allocator,
        "--{s}\r\n" ++
            "Content-Disposition: form-data; name=\"package\"; filename=\"{s}\"\r\n" ++
            "Content-Type: {s}\r\n\r\n",
        .{ boundary, filename, mime },
    );
}

fn releaseAvailable(package_name: []const u8, release: []const u8) bool {
    const release_patt = "^([a-zA-Z]+)?[0-9]+\\.[0-9]+(\\.[0-9]+)?$";
    const release_regex = mvzr.compile(release_patt).?;
    if (!release_regex.isMatch(release)) {
        return false;
    }

    const allocator = std.heap.page_allocator;
    const url = std.fmt.allocPrint(
        allocator,
        Constants.Default.zep_url ++ "/api/v1/release?package_name={s}&release={s}",
        .{
            package_name,
            release,
        },
    ) catch return false;
    defer allocator.free(url);
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();
    const f = client.fetch(
        .{
            .method = .GET,
            .location = .{ .url = url },
        },
    ) catch return false;
    return f.status != .ok;
}

pub fn create(self: *Release) !void {
    try self.ctx.logger.info("Creating Release", @src());

    try self.ctx.printer.append("Release:\n\n", .{}, .{
        .color = .yellow,
        .weight = .bold,
    });

    var manifest = try self.ctx.manifest.readManifest(
        Structs.Manifests.Auth,
        self.ctx.paths.auth_manifest,
    );
    defer manifest.deinit();
    if (manifest.value.token.len == 0) return error.NotAuthed;

    var packages = try self.ctx.fetcher.fetchPackages();
    defer packages.deinit(self.ctx.allocator);

    if (packages.items.len == 0) {
        try self.ctx.printer.append(
            "No package available!\nCreate package first!\n\n",
            .{},
            .{ .color = .red },
        );
        return;
    }

    try self.ctx.printer.append(
        "Select Package target:\n",
        .{},
        .{ .color = .blue, .weight = .bold },
    );

    for (0.., packages.items) |i, r| {
        try self.ctx.printer.append(
            " - [{d}] {s}\n",
            .{ i, r.Name },
            .{},
        );
    }
    try self.ctx.printer.append("\n", .{}, .{});

    const index_str = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        "TARGET >> ",
        .{ .required = true },
    );

    const index = std.fmt.parseInt(
        usize,
        index_str,
        10,
    ) catch return error.InvalidSelection;

    if (index >= packages.items.len)
        return error.InvalidSelection;

    const target = packages.items[index];
    try self.ctx.printer.append("Selected: {s}\n\n", .{target.Name}, .{ .color = .bright_black });

    const p_release = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        " > [Version] Release*: ",
        .{
            .required = true,
        },
    );

    const available = releaseAvailable(target.Name, p_release);
    if (!available) {
        try self.ctx.printer.append(
            "{s} is not available for project {s}.\n\n",
            .{ p_release, target.Name },
            .{
                .color = .red,
                .weight = .bold,
            },
        );
        return error.InvalidRelease;
    }

    const zig_version = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        " > Zig Version*: ",
        .{ .required = true },
    );

    const root_file = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        " > Root File*: ",
        .{ .required = true },
    );
    try self.ctx.printer.append("\n", .{}, .{});

    const archive = try self.compressPackage();
    defer {
        Fs.deleteTreeIfExists(TEMPORARY_DIRECTORY_PATH) catch {};
    }
    const file = try Fs.openFile(archive);
    defer file.close();

    const stat = try file.stat();
    const data = try self.ctx.allocator.alloc(u8, @intCast(stat.size));
    defer self.ctx.allocator.free(data);
    _ = try file.readAll(data);

    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(data);

    var digest: [32]u8 = undefined;
    hasher.final(&digest);

    const hash_hex =
        try std.fmt.allocPrint(self.ctx.allocator, "{x}", .{digest});

    try self.ctx.logger.info("Building Form File for Release", @src());
    const body = try std.mem.concat(
        self.ctx.allocator,
        u8,
        &.{
            try self.formFileHeader("bundled_release", "application/zstd"),
            data,
            "\r\n",
            try self.formField("package_id", target.ID),
            try self.formField("hash", hash_hex),
            try self.formField("release", p_release),
            try self.formField("zig_version", zig_version),
            try self.formField("root_file", root_file),
            try std.fmt.allocPrint(
                self.ctx.allocator,
                "--{s}--\r\n",
                .{boundary},
            ),
        },
    );

    var client = std.http.Client{ .allocator = self.ctx.allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(Constants.Default.zep_url ++ "/api/v1/release");
    var req = try client.request(.POST, uri, .{});
    defer req.deinit();

    req.headers.content_type = .{ .override = "multipart/form-data; boundary=" ++ boundary };
    req.headers.authorization = .{ .override = try manifest.value.bearer() };
    req.transfer_encoding = .{ .content_length = body.len };

    _ = req.sendBodyComplete(body) catch return error.FetchFailed;

    var head_buf: [Constants.Default.kb]u8 = undefined;
    var head = req.receiveHead(&head_buf) catch return error.FetchFailed;
    if (head.head.status != .ok) {
        try self.ctx.printer.append(
            "Releasing has failed.\n",
            .{},
            .{ .color = .bright_red },
        );
        return;
    }

    var read_buf: [Constants.Default.kb]u8 = undefined;
    var response_reader = head.reader(&read_buf);
    const response_buffer_len = response_reader.bufferedLen();
    const response_buffer = try self.ctx.allocator.alloc(u8, response_buffer_len);
    _ = try response_reader.readSliceAll(response_buffer);

    try self.ctx.printer.append(
        "{s} {s} has been successfully released!\n",
        .{
            target.Name,
            p_release,
        },
        .{ .color = .bright_green },
    );

    try self.ctx.printer.append(
        "Install package via\n $ zep install {s}@{s} --unverified\n\n",
        .{
            target.Name,
            p_release,
        },
        .{},
    );

    try Fs.deleteTreeIfExists(".zep/.pkg/");
}
