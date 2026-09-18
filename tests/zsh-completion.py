#!/usr/bin/env python3
"""Exercise real zsh completion through ZLE in an isolated pseudo-terminal."""
import os
from pathlib import Path
import pty
import select
import shlex
import shutil
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent


def complete(text):
    with tempfile.TemporaryDirectory(prefix="tmuxify-zsh-") as directory:
        work = Path(directory)
        (work / "layout with spaces.yml").touch()
        result = work / "buffer"
        setup = work / ".zshrc"
        setup.write_text(
            "PS1='READY> '\n"
            f"fpath=({shlex.quote(str(ROOT / 'completions'))} $fpath)\n"
            "autoload -Uz compinit\ncompinit -D\n"
            "function test_complete {\n"
            "  zle expand-or-complete\n"
            f"  print -rn -- \"$BUFFER\" > {shlex.quote(str(result))}\n"
            "}\nzle -N test_complete\nbindkey '^I' test_complete\n"
        )
        pid, fd = pty.fork()
        if pid == 0:
            os.chdir(work)
            os.environ["ZDOTDIR"] = directory
            os.environ["PATH"] = str(ROOT) + os.pathsep + os.environ["PATH"]
            os.environ["TERM"] = "xterm"
            os.execv(shutil.which("zsh"), ["zsh", "-d", "-i"])
        output = b""
        try:
            deadline = time.monotonic() + 10
            sent = False
            while time.monotonic() < deadline:
                if select.select([fd], [], [], 0.05)[0]:
                    output += os.read(fd, 65536)
                if not sent and b"READY> " in output:
                    os.write(fd, text.encode() + b"\t")
                    sent = True
                if result.exists():
                    # Drain terminal diagnostics emitted before the buffer was saved.
                    while select.select([fd], [], [], 0.05)[0]:
                        output += os.read(fd, 65536)
                    transcript = output.decode(errors="replace")
                    assert "invalid argument:" not in transcript, transcript
                    assert "_arguments:" not in transcript, transcript
                    return result.read_text(), transcript
            raise AssertionError(f"Completion timed out: {output!r}")
        finally:
            os.kill(pid, signal.SIGKILL)
            os.waitpid(pid, 0)
            os.close(fd)


buffer, _ = complete("tmuxify --dr")
assert buffer.strip() == "tmuxify --dry-run", repr(buffer)
print("ok - zsh completes a long option through actual Tab input")

_, transcript = complete("tmuxify -")
metadata = subprocess.check_output([str(ROOT / "tmuxify"), "--completion-options"], text=True)
for line in metadata.splitlines():
    for alias in line.split(":")[0].split("|"):
        assert alias in transcript, f"Missing option {alias}: {transcript}"
print("ok - zsh lists every metadata option and alias without errors")

for flag in ("--file", "-f", "--export", "-e"):
    for prefix in ("", "--detach "):
        text = f"tmuxify {prefix}{flag} layout"
        buffer, _ = complete(text)
        assert buffer.strip() == text + r"\ with\ spaces.yml", repr(buffer)
print("ok - zsh completes spaced filenames for long and short file options")
