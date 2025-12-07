pub const PrinterData = struct {
    data: []const u8,
    verbosity: u8 = 1,
    color: u8 = 0,
};

pub const ArtifactType = enum {
    zep,
    zig,
};
