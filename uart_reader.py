"""
uart_reader.py — Read UART messages from an nRF device (or any serial device)

Requirements:
    pip install pyserial

Usage:
    python uart_reader.py                        # auto-detect port, 115200 baud
    python uart_reader.py --port COM3            # Windows
    python uart_reader.py --port /dev/ttyACM0    # Linux
    python uart_reader.py --port /dev/cu.usbmodem0001  # macOS
    python uart_reader.py --port /dev/ttyACM0 --baud 9600 --log output.txt
"""

import argparse
import datetime
import glob
import sys
import time

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("ERROR: pyserial not found.  Run:  pip install pyserial")
    sys.exit(1)


# ── Auto-detect helpers ────────────────────────────────────────────────────────

NRF_USB_IDS = [
    (0x1366, None),   # SEGGER J-Link (nRF devkits)
    (0x0D28, 0x0204), # ARM CMSIS-DAP (nRF9160-DK, nRF52840-DK via CDC)
    (0x239A, None),   # Adafruit nRF52 boards
]

def find_nrf_port():
    """Return the first serial port that looks like an nRF device, or None."""
    for port in serial.tools.list_ports.comports():
        for vid, pid in NRF_USB_IDS:
            if port.vid == vid and (pid is None or port.pid == pid):
                return port.device
    return None

def list_ports():
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        print("No serial ports found.")
        return
    print("Available serial ports:")
    for p in ports:
        vid_pid = f"  VID:PID={p.vid:04X}:{p.pid:04X}" if p.vid else ""
        print(f"  {p.device:<20} {p.description}{vid_pid}")


# ── Core reader ────────────────────────────────────────────────────────────────

def read_uart(port, baud, log_file=None, hex_mode=False, timeout=1.0):
    """
    Open *port* at *baud* and print every received line.

    port      – serial port string, e.g. '/dev/ttyACM0' or 'COM3'
    baud      – baud rate, must match TXD.BAUDRATE on the device
    log_file  – optional path to write a timestamped log
    hex_mode  – if True, also print raw hex alongside ASCII
    timeout   – read timeout in seconds
    """
    print(f"Opening {port} @ {baud} baud  (Ctrl+C to stop)\n{'─'*50}")

    log_fh = open(log_file, "a", encoding="utf-8") if log_file else None

    try:
        with serial.Serial(
            port=port,
            baudrate=baud,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=timeout,
        ) as ser:
            ser.reset_input_buffer()

            while True:
                # Read one line (terminated by \n) or up to timeout
                raw = ser.read(32)

                if not raw:
                    # timeout — no data received, just loop
                    continue

                ts = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]

                # Decode, replacing un-decodable bytes with '?'
                text = raw.decode("utf-8", errors="replace").rstrip("\r\n")

                if hex_mode:
                    hex_str = " ".join(f"{b:02X}" for b in raw)
                    line = f"[{ts}]  {text:<40}  | {hex_str}"
                else:
                    line = f"[{ts}]  {text}"

                print(line)

                if log_fh:
                    log_fh.write(line + "\n")
                    log_fh.flush()

    except serial.SerialException as exc:
        print(f"\nSerial error: {exc}")
    except KeyboardInterrupt:
        print(f"\n{'─'*50}\nStopped by user.")
    finally:
        if log_fh:
            log_fh.close()
            print(f"Log saved to: {log_file}")


# ── Binary / raw-byte mode ─────────────────────────────────────────────────────

def read_uart_raw(port, baud, chunk=64):
    """
    Read raw bytes in chunks — useful when the device doesn't send newlines
    (e.g. binary protocol or bare DMA dump).
    """
    print(f"Raw mode: {port} @ {baud} baud  (Ctrl+C to stop)\n{'─'*50}")
    try:
        with serial.Serial(port=port, baudrate=baud, timeout=0.1) as ser:
            ser.reset_input_buffer()
            while True:
                data = ser.read(chunk)
                if data:
                    hex_str  = " ".join(f"{b:02X}" for b in data)
                    ascii_str = "".join(chr(b) if 32 <= b < 127 else "." for b in data)
                    print(f"{hex_str:<{chunk*3}}  |  {ascii_str}")
    except serial.SerialException as exc:
        print(f"\nSerial error: {exc}")
    except KeyboardInterrupt:
        print(f"\n{'─'*50}\nStopped.")


# ── CLI ────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="UART reader for nRF UARTE DMA output"
    )
    parser.add_argument(
        "--port", "-p",
        default=None,
        help="Serial port (e.g. /dev/ttyACM0 or COM3). Auto-detected if omitted."
    )
    parser.add_argument(
        "--baud", "-b",
        type=int,
        default=115200,
        help="Baud rate (default: 115200 — must match UARTE config on device)"
    )
    parser.add_argument(
        "--log", "-l",
        default=None,
        metavar="FILE",
        help="Append received lines to FILE with timestamps"
    )
    parser.add_argument(
        "--hex",
        action="store_true",
        help="Show raw hex bytes alongside ASCII text"
    )
    parser.add_argument(
        "--raw",
        action="store_true",
        help="Raw binary mode — read fixed-size chunks instead of lines"
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List available serial ports and exit"
    )
    args = parser.parse_args()

    if args.list:
        list_ports()
        return

    port = args.port
    if port is None:
        port = find_nrf_port()
        if port:
            print(f"Auto-detected nRF device on {port}")
        else:
            print("No nRF device auto-detected. Available ports:")
            list_ports()
            print("\nSpecify a port with --port, e.g.:")
            print("  python uart_reader.py --port /dev/ttyACM0")
            sys.exit(1)

    if args.raw:
        read_uart_raw(port, args.baud)
    else:
        read_uart(port, args.baud, log_file=args.log, hex_mode=args.hex)


if __name__ == "__main__":
    main()
