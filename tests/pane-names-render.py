#!/usr/bin/env python3
"""Observe actual border rendering through an attached terminal, not format expansion."""

import fcntl
import os
import pty
import select
import struct
import subprocess
import sys
import termios
import time


def check_border(session, expected):
    master, slave = pty.openpty()
    process = None
    try:
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 161, 0, 0))
        env = dict(os.environ, TERM="xterm-256color")
        process = subprocess.Popen(
            ["tmux", "-u", "attach-session", "-t", "=" + session],
            stdin=slave,
            stdout=slave,
            stderr=slave,
            env=env,
        )
        os.close(slave)
        slave = None
        output = bytearray()
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if select.select([master], [], [], 0.1)[0]:
                try:
                    chunk = os.read(master, 65536)
                except OSError:
                    break
                if not chunk:
                    break
                output.extend(chunk)
                if expected.encode("utf-8") in output:
                    break
        if expected.encode("utf-8") not in output:
            raise AssertionError("Border did not render the literal name: " + repr(output))
        subprocess.run(
            ["tmux", "detach-client", "-s", "=" + session], check=True, timeout=5
        )
        # Drain remaining redraw output while the client exits; otherwise a full
        # pseudo-terminal buffer can prevent the client from completing detach.
        deadline = time.monotonic() + 5
        while process.poll() is None and time.monotonic() < deadline:
            if select.select([master], [], [], 0.1)[0]:
                try:
                    os.read(master, 65536)
                except OSError:
                    break
        process.wait(timeout=5)
        if process.returncode != 0:
            raise AssertionError("Attached tmux client failed")
    finally:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait(timeout=5)
        if slave is not None:
            os.close(slave)
        os.close(master)


if __name__ == "__main__":
    check_border(sys.argv[1], sys.argv[2])
