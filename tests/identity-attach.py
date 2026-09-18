#!/usr/bin/env python3
"""Observe CLI attachment and client switching on a private, real tmux server."""
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import shlex
import shutil
import struct
import subprocess
import tempfile
import termios
import time

ROOT = Path(__file__).resolve().parent.parent
BASH = os.environ.get("TMUXIFY_BASH", shutil.which("bash"))
TMUX = shutil.which("tmux")

with tempfile.TemporaryDirectory(prefix="tmuxify-attach.", dir="/tmp") as directory:
    work = Path(directory)
    env = os.environ.copy()
    env.pop("TMUX", None)
    env.pop("TMUX_PANE", None)
    env.update(HOME=str(work / "home"), XDG_CONFIG_HOME=str(work / "config"),
               TMUX_TMPDIR=directory, TMPDIR=directory, TERM="xterm-256color")
    (work / "home").mkdir()
    project = work / "project with spaces"
    project.mkdir()
    for name in ("first", "second"):
        (work / f"{name}.yml").write_text(
            f"session: {{name: {name}}}\n"
            "layout: {type: horizontal, splits: [{id: shell}]}\n"
        )

    def tmux(*args):
        return subprocess.check_output([TMUX, *args], env=env, text=True, timeout=10).strip()

    def command(name):
        return [BASH, str(ROOT / "tmuxify"), "--root", str(project),
                "--file", str(work / f"{name}.yml"), "--no-commands"]

    master, slave = pty.openpty()
    process = None
    try:
        tmux("-f", "/dev/null", "new-session", "-d", "-s", "keepalive", "sleep 300")
        tmux("set-option", "-g", "default-shell", "/bin/bash")
        tmux("set-option", "-g", "default-command",
             "exec env HISTFILE=/dev/null /bin/bash --noprofile --norc")
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 32, 120, 0, 0))
        process = subprocess.Popen(command("first"), stdin=slave, stdout=slave,
                                   stderr=slave, env=env)
        os.close(slave)
        slave = None

        def drain(timeout=0.05):
            if select.select([master], [], [], timeout)[0]:
                try:
                    return os.read(master, 65536)
                except OSError:
                    pass
            return b""

        def wait_for_workspace(name):
            deadline = time.monotonic() + 15
            transcript = b""
            while time.monotonic() < deadline and process.poll() is None:
                transcript += drain()
                for native in tmux("list-clients", "-F", "#{session_id}").splitlines():
                    identity = tmux("show-options", "-qv", "-t", native,
                                    "@tmuxify_workspace_identity")
                    if identity and json.loads(identity)[3] == name:
                        return native
            raise AssertionError(f"Client did not reach {name}: {transcript!r}")

        first = wait_for_workspace("first")
        pane = tmux("display-message", "-p", "-t", first, "#{pane_id}")
        tmux("send-keys", "-t", pane, "-l", shlex.join(command("second")))
        tmux("send-keys", "-t", pane, "Enter")
        second = wait_for_workspace("second")
        assert first != second, "client remained on the first workspace"
        tmux("has-session", "-t", first)
        assert tmux("display-message", "-p", "-t", second,
                    "#{pane_current_path}") == str(project.resolve())
        tmux("detach-client", "-s", second)
        deadline = time.monotonic() + 5
        while process.poll() is None and time.monotonic() < deadline:
            drain()
        assert process.wait(timeout=5) == 0, "tmux client handoff failed"
        print("ok - CLI attaches and switches the real client using scoped native identity")
    finally:
        # Closing the terminal also releases pending terminal I/O on macOS.
        if slave is not None:
            os.close(slave)
        os.close(master)
        if process is not None and process.poll() is None:
            process.kill()
            process.wait(timeout=5)
        subprocess.run([TMUX, "kill-server"], env=env, capture_output=True, timeout=10)
