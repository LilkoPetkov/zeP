const std = @import("std");

pub const ProjectStruct = struct {
    ID: []const u8,
    UserID: []const u8,
    Name: []const u8,
    Description: []const u8,
    Docs: []const u8,
    Tags: []const u8,
    CreatedAt: []const u8,
};

pub const ReleaseStruct = struct {
    ID: []const u8,
    UserID: []const u8,
    ProjectID: []const u8,
    Url: []const u8,
    Release: []const u8,
    ZigVersion: []const u8,
    Hash: []const u8,
    RootFile: []const u8,
    CreatedAt: []const u8,
    UpdatedAt: []const u8,
};

pub const FetchOptions = struct {
    payload: ?[]const u8 = null,
    headers: []const std.http.Header = &.{},
    method: std.http.Method = .POST,
};
