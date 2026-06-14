const utils = @import("utils.zig");
const leds = @import("leds.zig");
const Timers = @import("timer.zig");


fn genInterruptHandler(
    comptime func_ptr: *const *const fn() void
        ) fn() callconv(.c) void{
    return struct {
        fn interruptHandler() callconv(.c) void {
            func_ptr.*();
        }
    }.interruptHandler;
}


const TIMERS = enum(u32) {
    TIMER0 = 0x40008000,
    TIMER1 = 0x40009000,
    TIMER2 = 0x4000A000,
    TIMER3 = 0x4001A000,
    TIMER4 = 0x4001B000,
    const getValue = utils.getEnumValue(TIMERS);
};

fn dummyHandler() void { 
}

var timer0Callback: *const fn() void = &dummyHandler;
var timer1Callback: *const fn() void = &dummyHandler;
var timer2Callback: *const fn() void = &dummyHandler;
var timer3Callback: *const fn() void = &dummyHandler;
var timer4Callback: *const fn() void = &dummyHandler;
pub const timerCallbacks: [5]**const fn()void = .{
    &timer0Callback,
    &timer1Callback,
    &timer2Callback,
    &timer3Callback,
    &timer4Callback,
};
pub const timer0Handler = genInterruptHandler(timerCallbacks[0]);
pub const timer1Handler = genInterruptHandler(timerCallbacks[1]);
pub const timer2Handler = genInterruptHandler(timerCallbacks[2]);
pub const timer3Handler = genInterruptHandler(timerCallbacks[3]);
pub const timer4Handler = genInterruptHandler(timerCallbacks[4]);
