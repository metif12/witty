"""Compare checked IFF traps in already-built V and unmodified Zig probes."""
import subprocess
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: verify.py V_PROBE ZIG_PROBE")

for case in ("row_stride", "padding_bit", "empty_palette", "ham_bits"):
    for executable in sys.argv[1:]:
        result = subprocess.run([executable, case], capture_output=True, timeout=5)
        if result.returncode == 0 or b"UNEXPECTED" in result.stderr:
            raise SystemExit(f"{executable} {case} did not trap: {result.stderr!r}")
        markers = (b"panic:", b"Assertion failed", b"array.get:")
        if not any(marker in result.stderr for marker in markers):
            raise SystemExit(f"{executable} {case} failed without a checked trap: {result.stderr!r}")

print("PASS: V and locked-source IFF stride, padding, palette, and HAM checks")
