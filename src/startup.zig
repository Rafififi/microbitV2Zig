const main = @import("main.zig");
const LEDS = @import("leds.zig");
const Timer = @import("timer.zig");
const Interrupt = @import("interrupts.zig");

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
    main.main();
    while (true) {}
}

const Handler = ?*const fn () callconv(.c) void;

fn dummyHandler() callconv(.c) void {}

pub export var vector_table linksection(".isr_vector") = [_]Handler{
    @ptrFromInt(0x20020000), // Initial stack pointer (top of RAM)
    &Reset_Handler,  // Reset handler
    &dummyHandler,   // NMI Handler
    &dummyHandler,   // HardFault Handler
    &dummyHandler,   // MemoryManagement Handler
    &dummyHandler,   // BusFault Handler
    &dummyHandler,   // UsageFault Handler
    null,            // Reserved
    null,            // Reserved
    null,            // Reserved
    null,            // Reserved
    &dummyHandler,   // SVC Handler
    &dummyHandler,   // Debug Mon Handler
    null,            // Reserved
    &dummyHandler,   // 
    &dummyHandler,   // POWER_CLOCK_IRQHandler
    &dummyHandler,   // RADIO_IRQHandler
    &dummyHandler,   // UARTE0_UART0_IRQHandler
    &dummyHandler,   // SPIM0_SPIS0_TWIM0_TWIS0_SPI0_TWI0_IRQHandler
    &dummyHandler,   // SPIM1_SPIS1_TWIM1_TWIS1_SPI1_TWI1_IRQHandler
    &dummyHandler,   // NFCT_IRQHandler
    &dummyHandler,   // GPIOTE_IRQHandler
    &dummyHandler,   // SAADC_IRQHandler
    &Interrupt.timer0Handler,   // TIMER0_IRQHandler
    &Interrupt.timer0Handler,   // TIMER1_IRQHandler
    &Interrupt.timer2Handler,   // TIMER2_IRQHandler
    &dummyHandler,   // RTC0_IRQHandler
    &dummyHandler,   // TEMP_IRQHandler
    &dummyHandler,   // RNG_IRQHandler
    &dummyHandler,   // ECB_IRQHandler
    &dummyHandler,   // CCM_AAR_IRQHandler
    &dummyHandler,   // WDT_IRQHandler
    &dummyHandler,   // RTC1_IRQHandler
    &dummyHandler,   // QDEC_IRQHandler
    &dummyHandler,   // COMP_LPCOMP_IRQHandler
    &dummyHandler,   // SWI0_EGU0_IRQHandler
    &dummyHandler,   // SWI1_EGU1_IRQHandler
    &dummyHandler,   // SWI2_EGU2_IRQHandler
    &dummyHandler,   // SWI3_EGU3_IRQHandler
    &dummyHandler,   // SWI4_EGU4_IRQHandler
    &dummyHandler,   // SWI5_EGU5_IRQHandler
    &Interrupt.timer3Handler,   // TIMER3_IRQHandler
    &Interrupt.timer4Handler,   // TIMER4_IRQHandler
    &dummyHandler,   // PWM0_IRQHandler
    &dummyHandler,   // PDM_IRQHandler
    &dummyHandler,   // ACL_NVMC
    &dummyHandler,   // PPI
    &dummyHandler,   // MWU_IRQHandler
    &dummyHandler,   // PWM1_IRQHandler
    &dummyHandler,   // PWM2_IRQHandler
    &dummyHandler,   // SPIM2_SPIS2_SPI2_IRQHandler
    &dummyHandler,   // RTC2_IRQHandler
    &dummyHandler,   // I2S_IRQHandler
    &dummyHandler,   // FPU_IRQHandler
    &dummyHandler,   // USBD_IRQHandler
    &dummyHandler,   // UARTE1_IRQHandler
    null,   // Reserved
    null,   // Reserved
    null,   // Reserved
    null,   // Reserved
    &dummyHandler,   // PWM3_IRQHandler
    &dummyHandler,   // Reserved
    &dummyHandler,   // SPIM3_IRQHandler
};
