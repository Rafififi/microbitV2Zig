const std = @import("std");
const LEDs = @import("leds.zig");
const utils = @import("utils.zig");
const Buttons = @import("buttons.zig");
const Uart = @import("uart.zig");
const Clock = @import("clock.zig");

extern var __bss_start__: u32;
extern var __bss_end__: u32;
extern var __data_start__: u32;
extern var __data_end__: u32;
extern var __etext: u32;

pub export fn Reset_Handler() callconv(.c) noreturn {
    const data_start: [*]volatile u32 = @ptrCast(&__data_start__);
    const data_words = (@intFromPtr(&__data_end__) - @intFromPtr(&__data_start__)) / @sizeOf(u32);
    const data_src: [*]const u32 = @ptrCast(&__etext);
    for (data_start[0..data_words], data_src[0..data_words]) |*dst, src| dst.* = src;

    const bss_start: [*]volatile u32 = @ptrCast(&__bss_start__);
    const bss_words = (@intFromPtr(&__bss_end__) - @intFromPtr(&__bss_start__)) / @sizeOf(u32);
    for (bss_start[0..bss_words]) |*b| b.* = 0;
    main();
    while (true) {}
}

const Handler = ?*const fn () callconv(.c) void;

pub export var vector_table linksection(".isr_vector") = [_]Handler{
    @ptrFromInt(0x20020000), // Initial stack pointer (top of RAM)
    &Reset_Handler, // Reset handler
};

const BUF_SIZE = 0xFFF0;
var tx_buffer: [BUF_SIZE]u8 = [_]u8{0x55} ** BUF_SIZE;

pub fn main() noreturn {
    Clock.startHFCLK();
    var led = LEDs.init();
    var uart = Uart.UARTE0.init(Uart.BUAD_RATES.Baud115200);
    for (tx_buffer[0..]) |*b| b.* = 0x55;
    uart.setDmaPtr(&tx_buffer[0], tx_buffer.len);
    uart.startTransmit();
    while (true) {
        const isDone = uart.getTxDone();
        if (isDone) {
            led.setLED(3, 3);
            uart.disableUart();
        }
        if (uart.getTXReady()) {
            utils.comp_sleep(0.1);
            led.setLED(0, 0);
            utils.comp_sleep(0.1);
            led.off();
        }
        if (uart.getTxAmount() > 1000) {
            led.setLED(2, 2);
        }
    }
}
