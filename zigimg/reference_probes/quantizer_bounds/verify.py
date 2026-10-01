"""Compare checked quantizer boundaries in already-built V and Zig probes."""
import subprocess
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: verify.py V_PROBE ZIG_PROBE")

for case in ("palette_capacity", "repeated_reduction", "component_overflow", "reference_overflow", "average_cast", "color_level"):
    for executable in sys.argv[1:]:
        result = subprocess.run([executable, case], capture_output=True, timeout=5)
        first_line = result.stderr.splitlines()[0] if result.stderr else b""
        if result.returncode == 0 or b"UNEXPECTED" in first_line:
            raise SystemExit(f"{executable} {case} did not trap: {result.stderr!r}")
        if not any(marker in result.stderr for marker in (b"panic:", b"Assertion failed", b"array.get:")):
            raise SystemExit(f"{executable} {case} failed without a checked trap: {result.stderr!r}")

print("PASS: V and unchanged locked quantizer capacity, reduction, arithmetic, and level checks")
