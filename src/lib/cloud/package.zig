const std = @import("std");

pub const Package = @This();

const Constants = @import("constants");
const Structs = @import("structs");

const Prompt = @import("cli").Prompt;
const Fs = @import("io").Fs;
const Compressor = @import("core").Compressor;

const Context = @import("context");
const mvzr = @import("mvzr");

/// Handles Packages
ctx: *Context,

pub fn init(ctx: *Context) Package {
    return .{
        .ctx = ctx,
    };
}

pub fn delete(self: *Package) !void {
    try self.ctx.logger.info("Deleting Package", @src());

    var manifest = try self.ctx.manifest.readManifest(Structs.Manifests.Auth, self.ctx.paths.auth_manifest);
    defer manifest.deinit();

    var packages = try self.ctx.fetcher.fetchPackages();
    defer packages.deinit(self.ctx.allocator);

    try self.ctx.printer.append("Available packages:\n", .{}, .{});
    if (packages.items.len == 0) {
        try self.ctx.printer.append("-- No packages --\n\n", .{}, .{ .color = .bright_red });
        return;
    }
    for (packages.items, 0..) |p, i| {
        try self.ctx.printer.append(" [{d}] - {s}\n", .{ i, p.Name }, .{});
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

    try self.ctx.printer.append(
        "Selected: {s}\n\n",
        .{packages.items[index].Name},
        .{ .color = .bright_black },
    );
    if (index >= packages.items.len) {
        try self.ctx.logger.info("Invalid Package Selection.", @src());
        return error.InvalidSelection;
    }

    const target = packages.items[index];
    const target_id = target.ID;

    var client = std.http.Client{ .allocator = self.ctx.allocator };
    defer client.deinit();

    var releases = try self.ctx.fetcher.fetchReleases(target.Name);
    defer releases.deinit(self.ctx.allocator);
    if (releases.items.len != 0) {
        try self.ctx.printer.append(
            "\nSelected package has {d} release(s)\n",
            .{releases.items.len},
            .{
                .color = .red,
                .weight = .bold,
            },
        );
        for (releases.items) |r| {
            try self.ctx.printer.append(
                " > {s} {s}\n    ({s})\n",
                .{
                    target.Name,
                    r.Release,
                    r.Hash,
                },
                .{},
            );
        }
        try self.ctx.printer.append(
            "\nYou want to continue?\n",
            .{},
            .{},
        );
        const answer = try Prompt.input(
            self.ctx.allocator,
            &self.ctx.printer,
            "(y/N) ",
            .{},
        );
        if (answer.len == 0 or
            (!std.mem.startsWith(u8, answer, "y") and
                !std.mem.startsWith(u8, answer, "Y")))
        {
            try self.ctx.printer.append("\nOk.\n", .{}, .{});
            return;
        }
    } else {
        try self.ctx.printer.append(
            "Deleting package...\n\n",
            .{},
            .{ .color = .red },
        );
    }

    const url = try std.fmt.allocPrint(
        self.ctx.allocator,
        Constants.Default.zep_url ++ "/api/v1/package?id={s}",
        .{target_id},
    );
    defer self.ctx.allocator.free(url);
    const delete_package_response = self.ctx.fetcher.fetch(
        url,
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
    defer delete_package_response.deinit();
    const delete_package_object = delete_package_response.value.object;
    const is_delete_package_successful = delete_package_object.get("success") orelse return;
    if (!is_delete_package_successful.bool) {
        try self.ctx.printer.append("Failed.\n", .{}, .{ .color = .red });
        return;
    }
    try self.ctx.printer.append("Deleted.\n", .{}, .{});
}

pub fn list(self: *Package) !void {
    try self.ctx.logger.info("Listing Package", @src());

    var packages = try self.ctx.fetcher.fetchPackages();
    defer packages.deinit(self.ctx.allocator);

    try self.ctx.printer.append("Available packages:\n", .{}, .{});
    if (packages.items.len == 0) {
        try self.ctx.printer.append("-- No packages --\n\n", .{}, .{ .color = .bright_red });
    }
    for (packages.items) |r| {
        try self.ctx.printer.append(" - {s}\n  > {s}\n", .{ r.Name, r.ID }, .{});
    }
    try self.ctx.printer.append("\n", .{}, .{});
}

fn packageNameAvailable(package_name: []const u8) bool {
    const package_patt = "^[a-z-]{2,20}";
    const package_regex = mvzr.compile(package_patt).?;
    if (!package_regex.isMatch(package_name)) return false;

    const allocator = std.heap.page_allocator;
    const url = std.fmt.allocPrint(
        allocator,
        Constants.Default.zep_url ++ "/api/v1/package?name={s}",
        .{package_name},
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

pub fn create(self: *Package) !void {
    try self.ctx.logger.info("Creating Package", @src());

    try self.ctx.printer.append("Package:\n\n", .{}, .{
        .color = .yellow,
        .weight = .bold,
    });

    var manifest = try self.ctx.manifest.readManifest(Structs.Manifests.Auth, self.ctx.paths.auth_manifest);
    defer manifest.deinit();
    if (manifest.value.token.len == 0) {
        return error.NotAuthed;
    }

    const package_name = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        " > Name*: ",
        .{
            .required = true,
            .validate = &packageNameAvailable,
            .invalid_error_msg = "(invalid / occupied) package name",
        },
    );

    const package_docs = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        " > Docs: ",
        .{},
    );

    const PackagePayload = struct {
        package: struct {
            name: []const u8,
            tags: []const u8,
            docs: []const u8,
            description: []const u8,
        },
    };

    const lock = try self.ctx.manifest.readManifest(Structs.ZepFiles.Lock, Constants.Default.package_files.lock);
    defer lock.deinit();

    const tags = try std.mem.join(self.ctx.allocator, ",", lock.value.root.tags);
    defer self.ctx.allocator.free(tags);

    const package_payload = PackagePayload{
        .package = .{
            .name = package_name,
            .docs = package_docs,
            .description = lock.value.root.description,
            .tags = tags,
        },
    };

    var client = std.http.Client{ .allocator = self.ctx.allocator };
    defer client.deinit();
    const package_response = self.ctx.fetcher.fetch(
        Constants.Default.zep_url ++ "/api/v1/package",
        .{
            .headers = &.{
                std.http.Header{
                    .name = "Authorization",
                    .value = try manifest.value.bearer(),
                },
                std.http.Header{
                    .name = "Content-Type",
                    .value = "application/json",
                },
            },
            .payload = try std.json.Stringify.valueAlloc(self.ctx.allocator, package_payload, .{}),
        },
    ) catch return error.FetchFailed;
    defer package_response.deinit();
    const package_object = package_response.value.object;
    const is_package_successful = package_object.get("success") orelse return;
    if (!is_package_successful.bool) {
        try self.ctx.printer.append("Failed.\n", .{}, .{ .color = .bright_red });
        return;
    }

    try self.ctx.printer.append("Created.\n", .{}, .{});
}
