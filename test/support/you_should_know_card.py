import fcntl
import json
import os
import pty
import select
import struct
import subprocess
import tempfile
import termios
import time
from pathlib import Path

root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="ysk-card-") as directory:
    session = Path(directory) / "session.jsonl"
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 90, 0, 0))
    process = subprocess.Popen([
        "pi", "--offline", "--no-extensions", "--no-skills", "--no-prompt-templates", "--no-context-files",
        "--session", str(session), "--provider", "ysk-test", "--model", "observer",
        "-e", str(root / "test/support/you_should_know_provider.ts"),
        "-e", str(root / "test/support/you_should_know_card.ts"),
        "-e", str(root / "files/home/.pi/agent/extensions/you-should-know/index.ts"),
    ], stdin=slave, stdout=slave, stderr=slave, cwd=directory,
        env=dict(os.environ, TERM="xterm-256color", PI_CODING_AGENT_DIR=str(Path(directory) / "agent"),
                 YSK_FIXTURE_REAL_JEV="", YSK_FIXTURE_REAL_LUNA="", YSK_CARD_TRACE=str(Path(directory) / "trace.json")))
    os.close(slave)
    captured = bytearray()

    def wait_for(needle, seconds=10):
        output = bytearray()
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if select.select([master], [], [], .05)[0]:
                try:
                    chunk = os.read(master, 65536)
                except OSError:
                    break
                output.extend(chunk)
                captured.extend(chunk)
                if b"\x1b[6n" in chunk:
                    os.write(master, b"\x1b[1;1R")
                if needle in output:
                    return output
        raise AssertionError(f"Terminal did not render {needle!r}")

    try:
        startup = wait_for(b"2 more waiting")
        assert b"Ctrl+; review" not in startup
        os.write(master, b"DRAFT PRESERVED\x1b[59;5u")
        wait_for(b"1 of 3")
        os.write(master, b"\t")
        wait_for(b"2 of 3")
        os.write(master, b"\x1b[C\r")
        chat = wait_for(b"Enter: send")
        assert b"Fixture two" in chat
        os.write(master, b"\x1b")
        wait_for(b"DRAFT PRESERVED")
        os.write(master, b"\x1b[59;5u")
        wait_for(b"2 of 3")
        os.write(master, b"A")
        wait_for(b"2 of 2")
        os.write(master, b"B")
        wait_for(b"DRAFT PRESERVED")
        os.write(master, b"\x1b[59;5u")
        wait_for(b"2 of 2")
        os.write(master, b"a")
        wait_for(b"1 of 1")
        os.write(master, b"a")
        wait_for(b"DRAFT PRESERVED")
        # No conversational messages are sent, so Pi intentionally has not flushed a session file.
        # Inspect the session manager's exact entries via a fixture-only command.
        os.write(master, b"\x15/ysk-card-proof\r")
        wait_for(b"Card proof captured")
        rows = json.loads((Path(directory) / "trace.json").read_text())
        acknowledged = [row["data"]["id"] for row in rows if row.get("customType") == "you-should-know-acknowledged"]
        assert acknowledged == ["two", "three", "one"], acknowledged
        assert not any(row.get("customType") == "you-should-know-usage" for row in rows), "UI test made a model call"
        assert not any(row.get("message", {}).get("role") == "user" for row in rows), "draft entered the main transcript"
        assert b"Failed to load extension" not in captured and b"Error:" not in captured
        print("PASS: real Ctrl+; card, Tab warnings, arrow/Enter Details, pinned side chat, A/B actions, draft preservation, zero model calls")
    finally:
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        os.close(master)
