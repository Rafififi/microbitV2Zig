"""
uart_sender.py — Send messages to a micro:bit over USB serial (UART)

The micro:bit's RX pin is P1.08 (UART_INT_TX on schematic),
bridged to your PC via the KL27 USB interface chip.

Requirements:
    pip install pyserial

Usage:
    python uart_sender.py                         # auto-detect port, 115200 baud
    python uart_sender.py --port /dev/ttyACM0     # Linux
    python uart_sender.py --port COM3             # Windows
    python uart_sender.py --port /dev/cu.usbmodem0001 --baud 115200
    python uart_sender.py --send "hello"          # send a single message and exit
"""

import argparse
import datetime
import sys
import time

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("ERROR: pyserial not found.  Run:  pip install pyserial")
    sys.exit(1)


# ── Auto-detect ────────────────────────────────────────────────────────────────

NRF_USB_IDS = [
    (0x1366, None),   # SEGGER J-Link (nRF devkits)
    (0x0D28, 0x0204), # ARM CMSIS-DAP / KL27 (micro:bit)
    (0x239A, None),   # Adafruit nRF52
]

def find_microbit_port():
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


# ── Sender modes ───────────────────────────────────────────────────────────────

def send_once(ser: serial.Serial, message: str, newline: bool, delay: float):
    """Send a single message and return the number of bytes written."""
    data = message
    if newline:
        data += "\n"
    encoded = data.encode("utf-8")
    n = ser.write(encoded)
    ts = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
    hex_str = " ".join(f"{b:02X}" for b in encoded)
    print(f"[{ts}]  TX ({n} bytes)  {repr(data):<30}  | {hex_str}")
    if delay > 0:
        time.sleep(delay)
    return n


def interactive_mode(ser: serial.Serial, newline: bool, delay: float):
    """
    Interactive REPL — type a message, press Enter to send.
    Type 'quit' or Ctrl+C to exit.
    Special commands:
        :hex <XX XX ...>  — send raw hex bytes, e.g.  :hex 48 65 6C 6C 6F
        :repeat <n> <msg> — send <msg> <n> times
        :delay <seconds>  — change inter-message delay
    """
    print("Interactive mode — type a message and press Enter to send.")
    print("Commands:  :hex <XX XX>  |  :repeat <n> <msg>  |  :delay <s>  |  quit\n")

    while True:
        try:
            line = input("> ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nExiting.")
            break

        if not line:
            continue

        if line.lower() == "quit":
            break

        # :hex command — send raw bytes
        elif line.startswith(":hex "):
            try:
                raw = bytes(int(b, 16) for b in line[5:].split())
                n = ser.write(raw)
                ts = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
                hex_str = " ".join(f"{b:02X}" for b in raw)
                print(f"[{ts}]  TX ({n} bytes)  raw | {hex_str}")
            except ValueError:
                print("Bad hex — use format:  :hex 48 65 6C 6C 6F")

        # :repeat command
        elif line.startswith(":repeat "):
            parts = line.split(" ", 2)
            if len(parts) < 3:
                print("Usage:  :repeat <count> <message>")
                continue
            try:
                count = int(parts[1])
                msg   = parts[2]
                for _ in range(count):
                    send_once(ser, msg, newline, delay)
            except ValueError:
                print("Usage:  :repeat <count> <message>  (count must be an integer)")

        # :delay command
        elif line.startswith(":delay "):
            try:
                delay = float(line.split()[1])
                print(f"Delay set to {delay}s")
            except (ValueError, IndexError):
                print("Usage:  :delay <seconds>  e.g.  :delay 0.1")

        else:
            send_once(ser, line, newline, delay)


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Send UART messages to a micro:bit (nRF52833 RX = P1.08)"
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
        help="Baud rate — must match UARTE config on the micro:bit (default: 115200)"
    )
    parser.add_argument(
        "--send", "-s",
        default=None,
        metavar="MESSAGE",
        help="Send a single message and exit (non-interactive)"
    )
    parser.add_argument(
        "--no-newline",
        action="store_true",
        help="Do not append \\n to each message (default: newline appended)"
    )
    parser.add_argument(
        "--delay", "-d",
        type=float,
        default=0.0,
        metavar="SECONDS",
        help="Delay between messages in seconds (default: 0)"
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
        port = find_microbit_port()
        if port:
            print(f"Auto-detected micro:bit on {port}")
        else:
            print("No micro:bit detected. Available ports:")
            list_ports()
            print("\nSpecify a port with --port, e.g.:")
            print("  python uart_sender.py --port /dev/ttyACM0")
            sys.exit(1)

    newline = not args.no_newline

    print(f"Opening {port} @ {args.baud} baud\n{'─'*50}")

    try:
        with serial.Serial(
            port=port,
            baudrate=args.baud,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1,
        ) as ser:
            # Give the KL27 bridge a moment to settle after open
            time.sleep(0.1)
            ser.reset_output_buffer()

            if args.send is not None:
                # Single-shot mode
                send_once(ser, args.send, newline, args.delay)
            else:
                # Interactive mode
                interactive_mode(ser, newline, args.delay)

    except serial.SerialException as exc:
        print(f"\nSerial error: {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()
