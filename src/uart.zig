const std = @import("std");
const bitField = @import("bitfield.zig");
const utils = @import("utils.zig");

const UART_OPTIONS = enum(u32) {
    UARTE0 = 0x40002000,
    UARTE1 = 0x40028000,
    const getValue = utils.getEnumValue(UART_OPTIONS);
};

const uartEnable = 0x500;

const startRX = 0x000;
const endRX = 0x004;

const BaudRate = 0x524;
const startTX = 0x008;
const stopTX = 0x00C;
const endTX = 0x120;
const TxStopped = 0x158;
const TxdPtr = 0x544;
const TxdMaxCnt = 0x548;
const enable = 0x500;
const config = 0x56C;
const PselTxd = 0x510;
const PselRxd = 0x514;
const AmountTxd = 0x54C;

const UART_TX_PIN: u32 = 6; // P0.06 is MCU TX for USB serial on micro:bit v2.2
const UART_RX_PIN: u32 = 8; // P0.08 is MCU RX for USB serial on micro:bit v2.2

fn pinCnf(port: u32, pin: u32) *volatile u32 {
    const PIN_CNF_BASE: u32 = 0x700;
    return @ptrFromInt(port + PIN_CNF_BASE + pin * 4);
}

fn psel(port_index: u32, pin: u32) u32 {
    return (pin & 0x1F) | ((port_index & 0x1) << 5);
}

pub const BUAD_RATES = enum(u32) {
    Baud1200 = 0x0004F000,
    Baud2400 = 0x0009D000,
    Baud4800 = 0x0013B000,
    Baud9600 = 0x00275000,
    Baud14400 = 0x003AF000,
    Baud19200 = 0x004EA000,
    Baud28800 = 0x0075C000,
    Baud31250 = 0x00800000,
    Baud38400 = 0x009D0000,
    Baud56000 = 0x00E50000,
    Baud57600 = 0x00EB0000,
    Baud76800 = 0x013A9000,
    Baud115200 = 0x01D60000,
    Baud230400 = 0x03B00000,
    Baud250000 = 0x04000000,
    Baud460800 = 0x07400000,
    Baud921600 = 0x0F000000,
    Baud1M = 0x10000000,
    const getValue = utils.getEnumValue(BUAD_RATES);
};

fn UART(comptime uart: UART_OPTIONS) type {
    if (uart != UART_OPTIONS.UARTE0 and uart != UART_OPTIONS.UARTE1) {
        @compileError("Uart Option must be either UARTE0(0x40002000), or UARTE1(0x40028000)");
    }
    return struct {
        baudRateAddr: bitField.BitField(u32),
        configAddr: bitField.BitField(u32),
        startTxAddr: bitField.BitField(u32),
        endTxAddr: bitField.BitField(u32),
        enableUartAddr: bitField.BitField(u32),
        pinSelectAddr: bitField.BitField(u32),
        pinSelectRxAddr: bitField.BitField(u32),
        serialTx: bitField.BitField(u32),
        serialRx: bitField.BitField(u32),

        const Self = @This();

        pub fn init(baudRate: BUAD_RATES) Self {
            var self = Self{
                .baudRateAddr = bitField.BitField(u32).init(@ptrFromInt(uart.getValue() + BaudRate)),
                .configAddr = bitField.BitField(u32).init(@ptrFromInt(uart.getValue() + config)),
                .startTxAddr = bitField.BitField(u32).init(@ptrFromInt(uart.getValue() + startTX)),
                .enableUartAddr = bitField.BitField(u32).init(@ptrFromInt(uart.getValue() + enable)),
                .pinSelectAddr = bitField.BitField(u32).init(@ptrFromInt(uart.getValue() + PselTxd)),
                .pinSelectRxAddr = bitField.BitField(u32).init(@ptrFromInt(uart.getValue() + PselRxd)),
                .endTxAddr = bitField.BitField(u32).init(@ptrFromInt(uart.getValue() + endTX)),
                .serialTx = bitField.BitField(u32).init(pinCnf(utils.PORT0, UART_TX_PIN)),
                .serialRx = bitField.BitField(u32).init(pinCnf(utils.PORT0, UART_RX_PIN)),
            };
            self.serialTx.clear();
            self.serialTx.onComptime(0);
            self.serialRx.clear();
            self.baudRateAddr.clear();
            self.configAddr.clear();
            self.startTxAddr.clear();
            self.enableUartAddr.clear();
            self.pinSelectAddr.clear();
            self.pinSelectRxAddr.clear();
            self.endTxAddr.clear();
            self.configAddr.clear();
            self.baudRateAddr.val.* = baudRate.getValue();
            // Leave CONFIG at 0: HWFC=0, PARITY=0 so TX is not gated by CTS.
            self.pinSelectAddr.setAll(psel(0, UART_TX_PIN));
            self.pinSelectRxAddr.setAll(psel(0, UART_RX_PIN));
            self.enableUartAddr.setAll(8);
            return self;
        }
        pub fn startTransmit(self: *Self) void {
            self.endTxAddr.clear();
            self.startTxAddr.onComptime(0);
        }
        pub fn disableUart(self: *Self) void {
            self.enableUartAddr.clear();
            self.startTxAddr.offComptime(0);
        }
        pub fn getTxDone(_: *Self) bool {
            return @as(*volatile u32, @ptrFromInt(uart.getValue() + endTX)).* == 1;
        }
        pub fn getTxAmount(_: *Self) u16 {
            return @as(*u16, @ptrFromInt(uart.getValue() + AmountTxd)).*;
        }
        pub fn getTXReady(_: *Self) bool {
            const ret = @as(*volatile u32, @ptrFromInt(uart.getValue() + 0x11C)).* == 1;
            @as(*volatile u32, @ptrFromInt(uart.getValue() + 0x11C)).* = 0;
            return ret;
        }
        pub fn setDmaPtr(_: *Self, ptr: *const u8, len: u16) void {
            @as(*volatile u32, @ptrFromInt(uart.getValue() + TxdPtr)).* = @intFromPtr(ptr);
            @as(*volatile u32, @ptrFromInt(uart.getValue() + TxdMaxCnt)).* = len;
        }
    };
}

pub const UARTE0 = UART(UART_OPTIONS.UARTE0);
pub const UARTE1 = UART(UART_OPTIONS.UARTE1);
