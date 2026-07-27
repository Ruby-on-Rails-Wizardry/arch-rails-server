#!/usr/bin/env python3
"""Serial smoke test against a QEMU guest (arch-rails-server live ISO).

Connects to a unix serial socket, waits for a shell (autologin root on ttyS0),
runs `ars status` / path checks, exits 0 on success.
"""
from __future__ import annotations

import os
import re
import socket
import sys
import time

SOCKET = os.environ.get("ARS_VM_SOCKET", "work/vm/serial.sock")
TIMEOUT = float(os.environ.get("ARS_VM_TIMEOUT", "240"))
CAPTURE = os.environ.get(
    "ARS_VM_SERIAL_LOG",
    os.path.join(os.path.dirname(SOCKET) if SOCKET else "work/vm", "smoke-capture.log"),
)


class Serial:
    def __init__(self, path: str) -> None:
        self.path = path
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(2.0)
        self.buf = bytearray()
        self.capture = open(CAPTURE, "wb")

    def connect(self, deadline: float) -> None:
        last_err: Exception | None = None
        while time.time() < deadline:
            try:
                self.sock.connect(self.path)
                return
            except OSError as e:
                last_err = e
                time.sleep(0.2)
        raise SystemExit(f"could not connect to {self.path}: {last_err}")

    def close(self) -> None:
        try:
            self.sock.close()
        finally:
            self.capture.close()

    def write(self, data: str) -> None:
        self.sock.sendall(data.encode())

    def read_some(self) -> bytes:
        try:
            chunk = self.sock.recv(4096)
        except socket.timeout:
            return b""
        if chunk:
            self.capture.write(chunk)
            self.capture.flush()
            self.buf.extend(chunk)
        return chunk

    def wait_for(self, patterns: list[str | re.Pattern[str]], deadline: float) -> str:
        compiled: list[re.Pattern[str]] = [
            p if isinstance(p, re.Pattern) else re.compile(p, re.I | re.M) for p in patterns
        ]
        while time.time() < deadline:
            self.read_some()
            text = self.buf.decode("utf-8", errors="replace")
            for c in compiled:
                m = c.search(text)
                if m:
                    return m.group(0)
            time.sleep(0.15)
        tail = self.buf.decode("utf-8", errors="replace")[-2000:]
        raise TimeoutError(f"timeout waiting for {patterns!r}\n--- serial tail ---\n{tail}")

    def drain(self, seconds: float = 0.5) -> None:
        end = time.time() + seconds
        while time.time() < end:
            if not self.read_some():
                time.sleep(0.05)


def main() -> int:
    deadline = time.time() + TIMEOUT
    ser = Serial(SOCKET)
    try:
        print(f"==> connecting to {SOCKET} (timeout {TIMEOUT}s)", flush=True)
        ser.connect(deadline)

        # Boot: UEFI + kernel + systemd can take a while
        print("==> waiting for live shell / login", flush=True)
        ser.wait_for(
            [
                r"root@archiso",
                r"root@.*[:#]\s*$",
                r"login:\s*$",
                r"arch-rails-server live media",
                r"\(none\) login:",
            ],
            deadline,
        )

        # If we hit a login prompt, log in as root (empty password on stock live)
        text = ser.buf.decode("utf-8", errors="replace")
        if re.search(r"login:\s*$", text, re.M) and "root@" not in text[-200:]:
            ser.write("root\n")
            ser.drain(1.0)
            # empty password
            if re.search(r"Password:", ser.buf.decode("utf-8", errors="replace")[-300:]):
                ser.write("\n")
            ser.wait_for([r"root@|#\s*$"], deadline)

        print("==> running ars path / status", flush=True)
        ser.drain(0.3)
        ser.write("export PS1='SMK# '\n")
        ser.drain(0.3)
        ser.write("ars path; ars status; test -x /opt/arch-rails-server/bin/bootstrap && echo BOOTSTRAP_OK; echo SMOKE_DONE\n")

        ser.wait_for([r"SMOKE_DONE"], deadline)
        body = ser.buf.decode("utf-8", errors="replace")

        checks = {
            "/opt/arch-rails-server": "/opt/arch-rails-server" in body,
            "kit present or ARS_ROOT": ("kit: present" in body) or ("ARS_ROOT=" in body),
            "BOOTSTRAP_OK": "BOOTSTRAP_OK" in body,
            "SMOKE_DONE": "SMOKE_DONE" in body,
        }
        for name, ok in checks.items():
            print(f"{'PASS' if ok else 'FAIL'}  {name}", flush=True)

        if not all(checks.values()):
            print(body[-3000:], file=sys.stderr)
            return 1

        print("==> vm smoke OK", flush=True)
        return 0
    except TimeoutError as e:
        print(f"FAIL  {e}", file=sys.stderr)
        return 1
    finally:
        try:
            ser.write("poweroff -f\n")
        except OSError:
            pass
        ser.close()


if __name__ == "__main__":
    sys.exit(main())
