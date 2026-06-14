const std = @import("std");
const LEDs = @import("leds.zig");
const utils = @import("utils.zig");
const Buttons = @import("buttons.zig");
const Uart = @import("uart.zig");
const Clock = @import("clock.zig");
const Letters = @import("letters.zig");
const Timer = @import("timer.zig");
const IRQ = @import("irq.zig");

const BUF_SIZE = 0xFFF0;
const TestString = "This is A test String";
var tx_buffer: [BUF_SIZE]u8 = [_]u8{'A'} ** BUF_SIZE;

var curLight: usize = 0;
var led = LEDs.init();
var timer0 = Timer.TIMER0.init();
fn timerCallback() void {
    timer0.clearCaptureCompare(Timer.TIMER0.TimerIndexs.INDEX0);
    led.off();
    led.setLEDFlat(curLight);
    timer0.clearTimer();
    curLight += 1;
}

pub fn main() noreturn {
    IRQ.nvicEnable(IRQ.IRQ.timer0);
    Clock.startHFCLK();
    var uart = Uart.UARTE0.init(Uart.BUAD_RATES.Baud115200);
    uart.setDmaTx(&tx_buffer[0], 20);
    timer0.startTimer();
    timer0.shortCutClearEnable(Timer.TIMER0.TimerIndexs.INDEX0);
    timer0.setBitMode(Timer.BITMODES.BIT32);
    timer0.setCapturedTimer(Timer.TIMER0.TimerIndexs.INDEX0, 1_000_000);
    timer0.attach(&timerCallback);
    timer0.enableInterrupt();
    uart.startTransmit();
    while (true) {
        if (curLight == 25) {
            timer0.disableInterrupt();
        }
    }
}
