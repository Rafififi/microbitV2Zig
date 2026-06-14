
pub fn sleep(time: u32) void {
    for (0..@as(u32,time*6_400_000))  |_| {
    }
}

pub fn comp_sleep(comptime time: f32) void {
    for (0..@round(time*6_400_000))  |_| {
    }
}

pub fn getEnumValue(comptime enum_type: type) fn(enum_type) u32 {
    return struct {
        fn getValue(self: enum_type) u32 {
            return @intFromEnum(self);
        }
    }.getValue;
}

pub const PORT0: u32 = 0x50000000;
pub const PORT1: u32 = 0x50000300;

const PortOutOffset = 0x504;
pub fn setOutHigh(port: u32, pin: u32) void {
    const out_reg: *u32 = @ptrFromInt(port + PortOutOffset);
    out_reg.* |= @as(u32, 1) << @intCast(pin);
}

pub fn dummyHandler() void {}
