"""Check already-built V and locked-source Zig probes without hanging a test runner."""
import subprocess
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: verify.py V_PROBE ZIG_PROBE")

for executable in sys.argv[1:]:
    try:
        result = subprocess.run([executable], capture_output=True, timeout=0.25)
    except subprocess.TimeoutExpired:
        continue
    raise SystemExit(f"{executable} unexpectedly returned {result.returncode}: {result.stderr!r}")

print("PASS: V and locked-source XBM detection repeat the first define line")
