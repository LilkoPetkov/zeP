const std = @import("std");

pub const Project = @This();

const Constants = @import("constants");
const Structs = @import("structs");

const Prompt = @import("cli").Prompt;
const Fs = @import("io").Fs;
const Compressor = @import("core").Compressor;

const Context = @import("context");
const mvzr = @import("mvzr");

/// Handles Projects
ctx: *Context,

pub fn init(ctx: *Context) Project {
    return .{
        .ctx = ctx,
    };
}

pub fn getProjects(self: *Project) !std.json.Parsed([]Structs.Fetch.ProjectStruct) {
    try self.ctx.logger.info("Getting Projects", @src());

    var auth = try self.ctx.manifest.readManifest(
        Structs.Manifests.AuthManifest,
        self.ctx.paths.auth_manifest,
    );
    defer auth.deinit();
    if (auth.value.token.len == 0) return error.NotAuthed;

    var client = std.http.Client{ .allocator = self.ctx.allocator };
    defer client.deinit();

    const res = self.ctx.fetcher.fetch(
        Constants.Default.zep_url ++ "/api/get/projects",
        &client,
        .{
            .method = .GET,
            .headers = &.{
                .{
                    .name = "Authorization",
                    .value = try auth.value.bearer(),
                },
            },
        },
    ) catch return error.FetchFailed;
    defer res.deinit();

    const encoded = res.value.object
        .get("projects") orelse return error.FetchFailed;
    const decoded = try self.ctx.allocator.alloc(
        u8,
        try std.base64.standard.Decoder.calcSizeForSlice(encoded.string),
    );
    defer self.ctx.allocator.free(decoded);

    try std.base64.standard.Decoder.decode(decoded, encoded.string);
    const parsed: std.json.Parsed([]Structs.Fetch.ProjectStruct) = try std.json.parseFromSlice(
        []Structs.Fetch.ProjectStruct,
        self.ctx.allocator,
        decoded,
        .{
            .allocate = .alloc_always,
        },
    );
    return parsed;
}

pub fn getReleasesFromProject(self: *Project, name: []const u8) !std.json.Parsed([]Structs.Fetch.ReleaseStruct) {
    try self.ctx.logger.infof("Getting Project {s}", .{name}, @src());

    const url = try std.fmt.allocPrint(
        self.ctx.allocator,
        Constants.Default.zep_url ++ "/api/get/project?name={s}",
        .{name},
    );
    defer self.ctx.allocator.free(url);

    var client = std.http.Client{ .allocator = self.ctx.allocator };
    defer client.deinit();
    try self.ctx.logger.infof("Fetching project url={s}", .{url}, @src());
    const get_project_response = self.ctx.fetcher.fetch(
        url,
        &client,
        .{
            .method = .GET,
        },
    ) catch return error.FetchFailed;

    defer get_project_response.deinit();
    const get_project_object = get_project_response.value.object;
    const is_get_project_successful = get_project_object.get("success") orelse return error.FetchFailed;
    if (!is_get_project_successful.bool) return error.FetchFailed;

    const releases = get_project_object.get("releases") orelse return error.FetchFailed;
    const release_decoded = try self.ctx.allocator.alloc(
        u8,
        try std.base64.standard.Decoder.calcSizeForSlice(releases.string),
    );
    defer self.ctx.allocator.free(release_decoded);
    try std.base64.standard.Decoder.decode(release_decoded, releases.string);
    const release_parsed: std.json.Parsed([]Structs.Fetch.ReleaseStruct) = try std.json.parseFromSlice(
        []Structs.Fetch.ReleaseStruct,
        self.ctx.allocator,
        release_decoded,
        .{
            .allocate = .alloc_always,
        },
    );

    return release_parsed;
}

pub fn delete(self: *Project) !void {
    try self.ctx.logger.info("Deleting Project", @src());

    var auth = try self.ctx.manifest.readManifest(Structs.Manifests.AuthManifest, self.ctx.paths.auth_manifest);
    defer auth.deinit();

    const projects = try self.getProjects();
    defer projects.deinit();

    try self.ctx.printer.append("Available projects:\n", .{}, .{});
    if (projects.value.len == 0) {
        try self.ctx.printer.append("-- No projects --\n", .{}, .{});
        return;
    }
    for (projects.value, 0..) |p, i| {
        try self.ctx.printer.append(" [{d}] - {s}\n", .{ i, p.Name }, .{});
    }
    try self.ctx.printer.append("\n", .{}, .{});

    const index_str = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        "TARGET >> ",
        .{ .required = true },
    );

    const index = try std.fmt.parseInt(
        usize,
        index_str,
        10,
    );

    try self.ctx.logger.infof("Selected Project {d}", .{index}, @src());
    if (index >= projects.value.len) {
        try self.ctx.logger.info("Invalid Project Selection", @src());
        return error.InvalidSelection;
    }

    const target = projects.value[index];
    const target_id = target.ID;

    var client = std.http.Client{ .allocator = self.ctx.allocator };
    defer client.deinit();

    const releases = try self.getReleasesFromProject(target.Name);
    defer releases.deinit();
    if (releases.value.len != 0) {
        try self.ctx.printer.append(
            "\nSelected project has {d} release(s)\n",
            .{releases.value.len},
            .{
                .color = .red,
                .weight = .bold,
            },
        );
        for (releases.value) |r| {
            try self.ctx.printer.append(
                "  > {s} {s}\n    ({s})\n",
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
        const yes_delete_project = try Prompt.input(
            self.ctx.allocator,
            &self.ctx.printer,
            "(y/N) ",
            .{},
        );
        if (yes_delete_project.len == 0) return;
        if (!std.mem.startsWith(u8, yes_delete_project, "y") and
            !std.mem.startsWith(u8, yes_delete_project, "Y")) return;
    } else {
        try self.ctx.printer.append(
            "Deleting project...\n\n",
            .{},
            .{ .color = .red },
        );
    }

    const url = try std.fmt.allocPrint(
        self.ctx.allocator,
        Constants.Default.zep_url ++ "/api/delete/project?id={s}",
        .{target_id},
    );
    defer self.ctx.allocator.free(url);
    const delete_project_response = self.ctx.fetcher.fetch(
        url,
        &client,
        .{
            .method = .DELETE,
            .headers = &.{
                std.http.Header{
                    .name = "Authorization",
                    .value = try auth.value.bearer(),
                },
            },
        },
    ) catch return error.FetchFailed;
    defer delete_project_response.deinit();
    const delete_project_object = delete_project_response.value.object;
    const is_delete_project_successful = delete_project_object.get("success") orelse return;
    if (!is_delete_project_successful.bool) {
        try self.ctx.printer.append("Failed.\n", .{}, .{ .color = .red });
        return;
    }
    try self.ctx.printer.append("Deleted.\n", .{}, .{});
}

pub fn list(self: *Project) !void {
    try self.ctx.logger.info("Listing Project", @src());

    const projects = try self.getProjects();
    defer projects.deinit();

    try self.ctx.printer.append("Available projects:\n", .{}, .{});
    if (projects.value.len == 0) {
        try self.ctx.printer.append("-- No projects --\n", .{}, .{});
    }
    for (projects.value) |r| {
        try self.ctx.printer.append(" - {s}\n  > {s}\n", .{ r.Name, r.ID }, .{});
    }
    try self.ctx.printer.append("\n", .{}, .{});
}

fn projectNameAvailable(project_name: []const u8) bool {
    const project_patt = "^[a-zA-Z]{2,}";
    const project_regex = mvzr.compile(project_patt).?;
    if (!project_regex.isMatch(project_name)) return false;

    const allocator = std.heap.page_allocator;
    const url = std.fmt.allocPrint(
        allocator,
        Constants.Default.zep_url ++ "/api/get/project?name={s}",
        .{project_name},
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

pub fn create(self: *Project) !void {
    try self.ctx.logger.info("Creating Project", @src());

    try self.ctx.printer.append("--- CREATING PROJECT MODE ---\n\n", .{}, .{
        .color = .yellow,
        .weight = .bold,
    });

    var auth = try self.ctx.manifest.readManifest(Structs.Manifests.AuthManifest, self.ctx.paths.auth_manifest);
    defer auth.deinit();
    if (auth.value.token.len == 0) {
        return error.NotAuthed;
    }

    const project_name = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        " > Name*: ",
        .{
            .required = true,
            .validate = &projectNameAvailable,
            .invalid_error_msg = "(invalid / occupied) project name",
        },
    );

    const project_description = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        " > Description: ",
        .{},
    );
    const project_docs = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        " > Docs: ",
        .{},
    );
    const project_tags = try Prompt.input(
        self.ctx.allocator,
        &self.ctx.printer,
        " > Tags (seperated by ,): ",
        .{},
    );
    const ProjectPayload = struct {
        name: []const u8,
        tags: []const u8,
        docs: []const u8,
        description: []const u8,
    };
    const project_payload = ProjectPayload{
        .name = project_name,
        .docs = project_docs,
        .description = project_description,
        .tags = project_tags,
    };
    var client = std.http.Client{ .allocator = self.ctx.allocator };
    defer client.deinit();
    const project_response = self.ctx.fetcher.fetch(
        Constants.Default.zep_url ++ "/api/post/project",
        &client,
        .{
            .headers = &.{
                std.http.Header{
                    .name = "Authorization",
                    .value = try auth.value.bearer(),
                },
            },
            .payload = try std.json.Stringify.valueAlloc(self.ctx.allocator, project_payload, .{}),
        },
    ) catch return error.FetchFailed;
    defer project_response.deinit();
    const project_object = project_response.value.object;
    const is_project_successful = project_object.get("success") orelse return;
    if (!is_project_successful.bool) {
        try self.ctx.printer.append("Failed.\n", .{}, .{ .color = .bright_red });
        return;
    }

    try self.ctx.printer.append("Create.\n", .{}, .{});
}
