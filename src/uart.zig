const std = @import("std");
const bitField = @import("bitfield.zig");
const utils = @import("utils.zig");

const UART_OPTIONS = enum(u32) {
    UARTE0 = 0x40002000,
    UARTE1 = 0x40028000,
    const getValue = utils.getEnumValue(UART_OPTIONS);
};


const startRX    = 0x000; // Start UART receiver 
const stopRX     = 0x004; // Stop UART receiver
const startTX    = 0x008; // Start UART transmitter
const stopTX     = 0x00C; // Stop UART transmitter
const flushRx    = 0x02C; // Flush RX FIFO into RX buffer
const CTS        = 0x100; // CTS is activated (set low). Clear To Send.
const NCTS       = 0x104; // CTS is deactivated (set high). Not Clear To Send.
const RxReady    = 0x108; // Data received in RXD (but potentially not yet transferred to Data RAM)
const endRx      = 0x110; // Receive buffer is filled up
const TxReady    = 0x11C; // Data sent from TXD
const endTx      = 0x120; // Last TX byte transmitted
const Error      = 0x124; // Error detected
const RxTo       = 0x144; // Receiver timeout
const RxStarted  = 0x14C; // UART receiver has started
const TxStarted  = 0x150; // UART transmitter has started
const TxStopped  = 0x158; // Transmitter stopped
const Short      = 0x200; // Shortcuts between local events and tasks
const Interupts  = 0x300; // Enable or disable interrupt
const EnableInt  = 0x304; // Enable interrupt
const DisableInt = 0x308; // Disable interrupt
const ErrorSrc   = 0x480; // Error source This register is read/write one to clear.
const Enable     = 0x500; // Enable UART
const PselRts    = 0x508; // Pin select for RTS signal
const PselTxd    = 0x50C; // Pin select for TXD signal
const PselCts    = 0x510; // Pin select for CTS signal
const PselRxd    = 0x514; // Pin select for RXD signal
const BaudRate   = 0x524; // Baud rate. Accuracy depends on the HFCLK source selected.
const RxPtr      = 0x534; // Data pointer
const RxMaxCnt   = 0x538; // Maximum number of bytes in receive buffer
const RxAmount   = 0x53C; // Number of bytes transferred in the last transaction
const TxPtr      = 0x544; // Data pointer
const TxMaxCnt   = 0x548; // Maximum number of bytes in transmit buffer
const TxAmount   = 0x54C; // Number of bytes transferred in the last transaction
const Config     = 0x56C; // Configuration of parity and hardware flow control


const UART_TX_PIN: u32 = 6; // P0.06 is MCU TX for USB serial on micro:bit v2.2
const UART_RX_PIN: u32 = 8; // P0.08 is MCU RX for USB serial on micro:bit v2.2

fn pinCnf(port: u32, pin: u32) *u32 {
    const PIN_CNF_BASE: u32 = 0x700;
    return @ptrFromInt(port + PIN_CNF_BASE + pin * 4);
}

fn psel(port_index: u32, pin: u32) u32 {
    return (pin & 0x1F) | ((port_index & 0x1) << 5);
}

fn getAndSet(comptime T: type, addr: u32, val: T) T {
    const ret = @as(*T, @ptrFromInt(addr)).*;
    @as(*T, @ptrFromInt(addr)).* = val;
    return ret;
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
        startRxAddr: bitField.BitField(u32),
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
                .configAddr = bitField.BitField(u32).init(@ptrFromInt(uart.getValue() + Config)),
                .startTxAddr = bitField.BitField(u32).init(@ptrFromInt(uart.getValue() + startTX)),
                .startRxAddr = bitField.BitField(u32).init(@ptrFromInt(uart.getValue() + startRX)),
                .enableUartAddr = bitField.BitField(u32).init(@ptrFromInt(uart.getValue() + Enable)),
                .pinSelectAddr = bitField.BitField(u32).init(@ptrFromInt(uart.getValue() + PselTxd)),
                .pinSelectRxAddr = bitField.BitField(u32).init(@ptrFromInt(uart.getValue() + PselRxd)),
                .endTxAddr = bitField.BitField(u32).init(@ptrFromInt(uart.getValue() + endTx)),
                .serialTx = bitField.BitField(u32).init(pinCnf(utils.PORT0, UART_TX_PIN)),
                .serialRx = bitField.BitField(u32).init(pinCnf(utils.PORT1, UART_RX_PIN)),
            };
            self.serialTx.clear();
            // Keep TX idle high to avoid a spurious 0xFF at startup.
            utils.setOutHigh(utils.PORT0, UART_TX_PIN);
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
            self.pinSelectRxAddr.setAll(psel(1, UART_RX_PIN));
            self.enableUartAddr.setAll(8);
            return self;
        }
        pub fn startTransmit(self: *Self) void {
            self.endTxAddr.clear();
            self.startTxAddr.onComptime(0);
        }
        pub fn stopTransmit(self: *Self) void {
            self.startTxAddr.offComptime(0);
        }
        pub fn startReceive(self: *Self) void {
            self.startRxAddr.onComptime(0);
        }
        pub fn disableUart(self: *Self) void {
            self.enableUartAddr.clear();
            self.startTxAddr.offComptime(0);
            self.startRxAddr.offComptime(0);
        }
        pub fn getTxDone(_: *Self) bool {
            return getAndSet(u32, uart.getValue() + endTx, 0) == 1;
        }
        pub fn getTxAmount(_: *Self) u16 {
            return @as(*u16, @ptrFromInt(uart.getValue() + TxAmount)).*;
        }
        pub fn getTXReady(_: *Self) bool {
            return getAndSet(u32, uart.getValue() + 0x11C, 0) == 1;
        }
        pub fn setDmaTx(_: *Self, ptr: *const u8, len: u16) void {
            @as(*u32, @ptrFromInt(uart.getValue() + TxPtr)).* = @intFromPtr(ptr);
            @as(*u32, @ptrFromInt(uart.getValue() + TxMaxCnt)).* = len;
        }
        pub fn setDmaRx(_: *Self, ptr: *const u8, len: u16) void {
            @as(*u32, @ptrFromInt(uart.getValue() + RxPtr)).* = @intFromPtr(ptr);
            @as(*u32, @ptrFromInt(uart.getValue() + RxMaxCnt)).* = len;
        }
        pub fn setRxStarted(_: *Self) void {
            @as(*u32, @ptrFromInt(uart.getValue() + RxAmount)).* = 1;
        }
        pub fn getRxStarted(_: *Self) u32 {
            return getAndSet(u32, uart.getValue() + RxStarted, 0);
        }
        pub fn getTxStarted(_: *Self) u32 {
            return getAndSet(u32, uart.getValue() + TxStarted, 0);
        }
        pub fn getRxReady(_: *Self) bool {
            return getAndSet(u32, uart.getValue() + RxReady, 0) == 1;
        }
        pub fn getRxDone(_: *Self) bool {
            return getAndSet(u32, uart.getValue() + endRx, 0) == 1;
        }
        pub fn flushRxBuf(_: *Self) void {
            @as(*u32, @ptrFromInt(uart.getValue() + flushRx)).* = 1;
        }
        pub fn getRxAmount(_: *Self) u16 {
            return @as(*u16, @ptrFromInt(uart.getValue() + RxAmount)).*;
        }
    };
}

pub const UARTE0 = UART(UART_OPTIONS.UARTE0);
pub const UARTE1 = UART(UART_OPTIONS.UARTE1);
