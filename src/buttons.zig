const bitField = @import("bitfield.zig");

const BUTTONS = enum(u8) {
    BTN_A = 14,
    BTN_B = 23,
};

const PORT0        = 0x50000000;
const PIN_CNF_BASE = 0x700;
const BTN_BASE     = PORT0;
const INADDR       = 0x50000510;

fn Button(comptime btn: BUTTONS) type {
    if (btn != BUTTONS.BTN_A and btn != BUTTONS.BTN_B) {
        @compileError("Button must be either 14 (Button A) or 23 (Button B)");
    }
    return struct {
        inAddr: bitField.BitField(u32),
        btnAddr: bitField.BitField(u32),

        const Self = @This();

        pub fn init() Self {
            var self = Self{
                .inAddr  = bitField.BitField(u32).init(@ptrFromInt(INADDR)),
                .btnAddr = bitField.BitField(u32).init(@ptrFromInt(PIN_CNF_BASE + PORT0 + @as(u32, @intFromEnum(btn))*4)),
            };
            self.btnAddr.clear();
            self.btnAddr.offComptime(0);
            self.btnAddr.offComptime(1);
            self.btnAddr.offComptime(2);
            self.btnAddr.offComptime(3);
            self.btnAddr.onComptime(16);
            return self;
        }

        pub fn isPressed(self: *Self) bool {
            return !self.inAddr.checkComptime(@as(u32, @intFromEnum(btn)));
        }
    };
}

pub const ButtonA = Button(BUTTONS.BTN_A);
pub const ButtonB = Button(BUTTONS.BTN_B);
