"""Compare checked GIF traps in already-built V and unmodified Zig probes."""
import subprocess
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: verify.py V_PROBE ZIG_PROBE")

for case in ("plain_text_overflow", "graphic_toss", "short_loop_count", "background_index"):
    for executable in sys.argv[1:]:
        result = subprocess.run([executable, case], capture_output=True, timeout=5)
        first_line = result.stderr.splitlines()[0] if result.stderr else b""
        if result.returncode == 0 or b"UNEXPECTED" in first_line:
            raise SystemExit(f"{executable} {case} did not trap: {result.stderr!r}")
        if not any(marker in result.stderr for marker in (b"panic:", b"Assertion failed", b"array.get:")):
            raise SystemExit(f"{executable} {case} failed without a checked trap: {result.stderr!r}")

print("PASS: V and locked-source GIF text, buffered toss, loop count, and background bounds")
