"""Compare checked converter boundaries in already-built V and Zig probes."""
import subprocess
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: verify.py V_PROBE ZIG_PROBE")

cases = ["bgr_" + tag for tag in ("rgb555", "rgb565", "rgb24", "rgba32", "bgr24", "bgra32", "rgb48", "rgba64", "float32")]
cases += ["empty_rgba32", "empty_bgra32", "empty_float_rgba", "empty_float_bgra", "empty_raw_float", "unaligned_float", "palette_index", "float_negative", "float_large", "float_nan", "float_infinity"]
for case in cases:
    for executable in sys.argv[1:]:
        result = subprocess.run([executable, case], capture_output=True, timeout=5)
        first_line = result.stderr.splitlines()[0] if result.stderr else b""
        if case == "float_nan":
            if result.returncode or first_line != b"PASS: pinned ARM64 NaN prefix converts to zero":
                raise SystemExit(f"{executable} {case} differs from pinned ARM64: {result.stderr!r}")
            continue
        if result.returncode == 0 or b"UNEXPECTED" in first_line:
            raise SystemExit(f"{executable} {case} did not trap: {result.stderr!r}")
        if not any(marker in result.stderr for marker in (b"panic:", b"Assertion failed", b"array.get:")):
            raise SystemExit(f"{executable} {case} failed without a checked trap: {result.stderr!r}")

print(f"PASS: V and unchanged locked converter union, alignment, palette, and float casts ({len(cases)} probes)")
