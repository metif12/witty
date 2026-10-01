"""Verify the inherited XBM detection loop through both image APIs."""
import subprocess
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: verify.py V_PROBE ZIG_PROBE")

for mode in ("managed", "unmanaged"):
    for executable in sys.argv[1:]:
        try:
            result = subprocess.run([executable, mode], capture_output=True, timeout=0.25)
        except subprocess.TimeoutExpired:
            continue
        raise SystemExit(f"{executable} {mode} unexpectedly returned {result.returncode}: {result.stderr!r}")

print("PASS: both V and unchanged locked image APIs retain the XBM detection loop")
