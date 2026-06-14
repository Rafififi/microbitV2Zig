const utils = @import("utils.zig");
const bitField = @import("bitfield.zig");
const interrupt = @import("interrupts.zig");

const TIMERS = enum(u32) {
    TIMER0 = 0x40008000,
    TIMER1 = 0x40009000,
    TIMER2 = 0x4000A000,
    TIMER3 = 0x4001A000,
    TIMER4 = 0x4001B000,
    const getValue = utils.getEnumValue(TIMERS);
};

const TASKS_START = 0x000; // Start Timer
const TASKS_STOP = 0x004; // Stop Timer
const TASKS_COUNT = 0x008; // Increment Timer (Counter mode only)
const TASKS_CLEAR = 0x00C; // Clear time
const TASKS_SHUTDOWN = 0x010; // Shut down timer
const TASKS_CAPTURE0 = 0x040; // Capture Timer value to CC[0] register
const TASKS_CAPTURE1 = 0x044; //Capture Timer value to CC[1] register
const TASKS_CAPTURE2 = 0x048; //Capture Timer value to CC[2] register
const TASKS_CAPTURE3 = 0x04C; //Capture Timer value to CC[3] register
const TASKS_CAPTURE4 = 0x050; //Capture Timer value to CC[4] register
const TASKS_CAPTURE5 = 0x054; //Capture Timer value to CC[5] register
const EVENTS_COMPARE0 = 0x140; //Compare event on CC[0] match
const EVENTS_COMPARE1 = 0x144; //Compare event on CC[1] match
const EVENTS_COMPARE2 = 0x148; //Compare event on CC[2] match
const EVENTS_COMPARE3 = 0x14C; //Compare event on CC[3] match
const EVENTS_COMPARE4 = 0x150; //Compare event on CC[4] match
const EVENTS_COMPARE5 = 0x154; //Compare event on CC[5] match
const SHORTS = 0x200; // Shortcuts between local events and tasks
const INTENSET = 0x304; //Enable interrupt
const INTENCLR = 0x308; // Disable interrupt
const MODE = 0x504; // Timer mode selection
const BITMODE = 0x508; // Configure the number of bits used by the TIMER
const PRESCALER = 0x510; // Timer prescaler register
const CC0 = 0x540; //Capture/Compare register 0
const CC1 = 0x544; //Capture/Compare register 1
const CC2 = 0x548; //Capture/Compare register 2
const CC3 = 0x54C; //Capture/Compare register 3
const CC4 = 0x550; //Capture/Compare register 4
const CC5 = 0x554; //Capture/Compare register 5
//
fn GenericTimer(comptime timerInst: TIMERS) type {
    const timerAddr                   = timerInst.getValue();
    const timerStartAddr: *u32        = @ptrFromInt(timerAddr + TASKS_START);
    const timerStopAddr: *u32         = @ptrFromInt(timerAddr + TASKS_STOP);
    const timerCaptureBaseAddr: u32   = (timerAddr + TASKS_CAPTURE0);
    const timerCompareBaseAddr: u32   = (timerAddr + EVENTS_COMPARE0);
    const timerInterruptEnable: *u32  = @ptrFromInt(timerAddr + INTENSET);
    const timerInterruptDisable: *u32 = @ptrFromInt(timerAddr + INTENCLR);
    const bitModeAddr:*u32            = @ptrFromInt(timerAddr + BITMODE);
    const timerCCBaseAddr: u32        = (timerAddr + CC0);
    const timerClearAddr: *u32        = @ptrFromInt(timerAddr + TASKS_CLEAR);
    const shortAddr: *u32             =  @ptrFromInt(timerAddr + SHORTS);

    const TimerIndex = if (timerInst == TIMERS.TIMER3 or timerInst == TIMERS.TIMER4) enum(u4) {
        INDEX0 = 0,
        INDEX1 = 1,
        INDEX2 = 2,
        INDEX3 = 3,
        INDEX4 = 4,
        INDEX5 = 5,
        const getValue = utils.getEnumValue(@This());
    } else enum(u4) {
        INDEX0 = 0,
        INDEX1 = 1,
        INDEX2 = 2,
        INDEX3 = 3,
        const getValue = utils.getEnumValue(@This());
    };
    
    const currTimerIndex = switch (timerInst) {
        TIMERS.TIMER0 => 0,
        TIMERS.TIMER1 => 1,
        TIMERS.TIMER2 => 2,
        TIMERS.TIMER3 => 3,
        TIMERS.TIMER4 => 4,
    };

    return struct {
        const Self = @This();
        pub const TimerIndexs = TimerIndex;
        pub fn init() Self {
            return Self{};
        }
        pub fn startTimer(_: *Self) void {
            timerStartAddr.* = 1;
        }
        pub fn stopTimer(_: *Self) void {
            timerStopAddr.* = 1;
        }
        pub fn captureTimer(_: *Self, idx: TimerIndex) void {
            @as(*u32, @ptrFromInt(timerCaptureBaseAddr + idx.getValue() * 4)).* = 1;
        }
        pub fn enableInterrupt(_: *Self) void {
            const shift = currTimerIndex + 16;
            timerInterruptEnable.* = @as(u32, 1) << @intCast(shift);
        }
        pub fn disableInterrupt(_: *Self) void {
            const shift = currTimerIndex + 16;
            timerInterruptDisable.* = @as(u32, 1) << @intCast(shift);
        }
        pub fn shortCutClearEnable(_: *Self, idx: TimerIndex) void {
            const shift = idx.getValue();
            shortAddr.* |= @as(u32, 1) << @intCast(shift);
        }
        pub fn shortCutStopEnable(_: *Self, idx: TimerIndex) void {
            const shift = idx.getValue() + 8;
            shortAddr.* |= @as(u32, 1) << @intCast(shift);
        }
        pub fn shortCutClearDisable(_: *Self, idx: TimerIndex) void {
            const shift = idx.getValue();
            shortAddr.* = 0xFF ^ (@as(u32, 1) << @intCast(shift));
        }
        pub fn shortCutStopDisable(_: *Self, idx: TimerIndex) void {
            const shift = idx.getValue() + 8;
            shortAddr.* = 0xFF ^ (@as(u32, 1) << @intCast(shift));
        }
        pub fn getCapturedTimer(_: *Self, idx: TimerIndex) u32 {
            return @as(*u32, @ptrFromInt(timerCCBaseAddr + idx.getValue() * 4)).*;
        }
        pub fn setCapturedTimer(_: *Self, idx: TimerIndex, val: u32) void {
            @as(*u32, @ptrFromInt(timerCCBaseAddr + idx.getValue() * 4)).* = val;
        }
        pub fn clearCapturedTimer(_: *Self, idx: TimerIndex) void {
            @as(*u32, @ptrFromInt(timerCCBaseAddr + idx.getValue() * 4)).* = 0;
        }
        pub fn setBitMode(_: *Self, mode: BITMODES) void {
            bitModeAddr.* = mode.getValue();
        }
        pub fn getCompareEvent(_: *Self, idx: TimerIndex) bool {
            return @as(*u32, @ptrFromInt(timerCompareBaseAddr + idx.getValue() * 4)).* == 1;
        }
        pub fn clearCaptureCompare(_: *Self, idx: TimerIndex) void {
            @as(*u32, @ptrFromInt(timerCompareBaseAddr + idx.getValue() * 4)).* = 0;
        }
        pub fn clearTimer(_: *Self) void {
            timerClearAddr.* = 1;
        }
        pub fn attach(_: *Self, cb: *const fn() void) void {
            interrupt.timerCallbacks[currTimerIndex].* = cb;
        }
        pub fn detach(_: *Self) void {
            interrupt.timerCallbacks[currTimerIndex].* = &utils.dummyHandler;
        }
    };
}

pub const BITMODES = enum(u2) {
    BIT16 = 0,
    BIT08 = 1,
    BIT24 = 2,
    BIT32 = 3,
    const getValue = utils.getEnumValue(@This());
};

pub const TIMER0 = GenericTimer(TIMERS.TIMER0);
pub const TIMER1 = GenericTimer(TIMERS.TIMER1);
pub const TIMER2 = GenericTimer(TIMERS.TIMER2);
pub const TIMER3 = GenericTimer(TIMERS.TIMER3);
pub const TIMER4 = GenericTimer(TIMERS.TIMER4);
