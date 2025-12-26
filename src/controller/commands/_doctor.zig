const std = @import("std");

const Doctor = @import("../../lib/functions/doctor.zig");
const Context = @import("context");
const Args = @import("args");

fn doctor(ctx: *Context) !void {
    const doctor_args = try Args.parseDoctor();
    try Doctor.doctor(ctx, doctor_args.fix);
    return;
}

pub fn _doctorController(ctx: *Context) !void {
    try doctor(ctx);
}
