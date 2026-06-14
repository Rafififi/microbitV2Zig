const utils = @import("utils.zig");

pub const IRQ = enum(u8) {
    clock_power  = 0,
    radio        = 1,
    uarte0       = 2,
    spim0_twim0  = 3,   // shared instance
    spim1_twim1  = 4,   // shared instance
    nfct         = 5,
    gpiote       = 6,
    saadc        = 7,
    timer0       = 8,
    timer1       = 9,
    timer2       = 10,
    rtc0         = 11,
    temp         = 12,
    rng          = 13,
    ecb          = 14,
    ccm_aar      = 15,
    wdt          = 16,
    rtc1         = 17,
    qdec         = 18,
    comp_lpcomp  = 19,
    swi0_egu0    = 20,
    swi1_egu1    = 21,
    swi2_egu2    = 22,
    swi3_egu3    = 23,
    swi4_egu4    = 24,
    swi5_egu5    = 25,
    timer3       = 26,
    timer4       = 27,
    pwm0         = 28,
    pdm          = 29,
    // 30, 31 reserved
    mwu          = 32,
    pwm1         = 33,
    pwm2         = 34,
    spim2        = 35,
    rtc2         = 36,
    i2s          = 37,
    fpu          = 38,
    usbd         = 39,
    uarte1       = 40,
    // 41-43 reserved
    pwm3         = 44,
    // 45 reserved
    spim3        = 46,
    const getValue = utils.getEnumValue(@This());
};

const NVIC_ISER: [*]volatile u32 = @ptrFromInt(0xE000E100);

pub fn nvicEnable(irq: IRQ) void {
    const n: u8 = @intFromEnum(irq);
    NVIC_ISER[n / 32] |= @as(u32, 1) << @as(u5, @truncate(n % 32));
}
