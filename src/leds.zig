const std = @import("std");
const bitfield = @import("bitfield.zig");

const PORT0: u32 = 0x50000000;
const PORT1: u32 = 0x50000300;
const OUTADDR: u32 = 0x50000504;
const OUT_OFFSET: u32 = OUTADDR - PORT0;
const PIN_CNF_BASE: u32 = 0x700;

fn pinCnf(port: u32, pin: u32) *volatile u32 {
    return @ptrFromInt(port + PIN_CNF_BASE + pin * 4);
}

pub fn init() LEDs {
    var led = LEDs{
        .out_addr = bitfield.BitField(u32).init(@ptrFromInt(OUTADDR)),
        .out_addr1 = bitfield.BitField(u32).init(@ptrFromInt(PORT1 + OUT_OFFSET)),
    };
    led.out_addr.clear();
    led.out_addr1.clear();
    return led;
}

pub const LEDs = struct {
    out_addr: bitfield.BitField(u32),
    out_addr1: bitfield.BitField(u32),

    const row_pins = [5]u8{ 21, 22, 15, 24, 19 };
    const col_pins = [5]u8{ 28, 11, 31, 5, 30 };

    // PORT1 for col index 3 (pin 5), PORT0 for all others
    fn colReg(col: usize) *volatile u32 {
        const port: u32 = if (col == 3) PORT1 else PORT0;
        return pinCnf(port, col_pins[col]);
    }

    fn rowReg(row: usize) *volatile u32 {
        return pinCnf(PORT0, row_pins[row]);
    }

    pub fn off(self: *LEDs) void {
        self.out_addr.clear();
        self.out_addr1.clear();
        for (0..5) |i| rowReg(i).* = 0;
        for (0..5) |i| colReg(i).* = 0;
    }

    pub fn setLED(self: *LEDs, row: usize, col: usize) void {
        rowReg(row).* = 1;
        colReg(col).* = 1;
        // Set the row's bit in OUT register
        self.out_addr.on(row_pins[row]);
        // Drive the column pin low on the correct port so current can flow
        const cp = col_pins[col];
        if (col == 3) {
            self.out_addr1.off(cp);
        } else {
            self.out_addr.off(cp);
        }
    }

    pub fn setLEDFlat(self: *LEDs, led: usize) void {
        self.setLED(led / 5, led % 5);
    }

    // Note: setting multiple LEDs simultaneously still won't work
    // without multiplexing — this is a hardware limitation.
    pub fn setMatrix(self: *LEDs, mat: [5][5]bool) void {
        self.off();
        for (0..5) |i| {
            for (0..5) |j| {
                if (mat[i][j]) {
                    self.setLED(i, j);
                }
            }
        }
    }
};
