"""Compare PNG arithmetic, row/palette bounds, and its zero-stride loop."""
import resource
import subprocess
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: verify.py V_PROBE ZIG_PROBE")

cases = ("pixel_bits", "line_bytes", "short_pixels", "channels8", "channels16",
         "try_all", "palette_bounds", "skip_overflow", "plte_index",
         "gray_source", "rgb_source", "trns_arm", "gray16_odd", "rgb48_odd")


def no_core():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


for case in cases:
    for executable in sys.argv[1:]:
        result = subprocess.run([executable, case], capture_output=True, timeout=5,
                                preexec_fn=no_core)
        first_line = result.stderr.splitlines()[0] if result.stderr else b""
        if not result.returncode or b"UNEXPECTED" in first_line:
            raise SystemExit(f"{executable} {case} did not trap: {result.stderr!r}")
        if not any(marker in result.stderr for marker in (b"panic:", b"Assertion failed", b"array.get:")):
            raise SystemExit(f"{executable} {case} failed without a checked trap: {result.stderr!r}")

for executable in sys.argv[1:]:
    try:
        result = subprocess.run([executable, "zero_stride"], capture_output=True,
                                timeout=0.25, preexec_fn=no_core)
    except subprocess.TimeoutExpired as result:
        if b"READY: zero-stride row" in (result.stderr or b""):
            continue
        raise SystemExit(f"{executable} never reached the loop")
    raise SystemExit(f"{executable} zero_stride unexpectedly returned {result.returncode}: {result.stderr!r}")

print(f"PASS: V and unchanged locked PNG match {len(cases)} checked traps and the zero-stride loop")
