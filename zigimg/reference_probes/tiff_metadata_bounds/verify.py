"""Compare the locked TIFF metadata's checked traps in already-built probes."""
import subprocess
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: verify.py V_PROBE ZIG_PROBE")

cases = ("unknown_tag", "compression_enum", "resolution_enum", "bits_capacity", "extra_capacity", "empty_bits", "missing_alpha", "row_components", "byte_overflow", "array_type", "palette_capacity", "palette_power", "short_palette")
for case in cases:
    for executable in sys.argv[1:]:
        result = subprocess.run([executable, case], capture_output=True, timeout=5)
        first_line = result.stderr.splitlines()[0] if result.stderr else b""
        if result.returncode == 0 or b"UNEXPECTED" in first_line:
            raise SystemExit(f"{executable} {case} did not trap: {result.stderr!r}")
        if not any(marker in result.stderr for marker in (b"panic:", b"Assertion failed", b"array.get:")):
            raise SystemExit(f"{executable} {case} failed without a checked trap: {result.stderr!r}")

print(f"PASS: V and unchanged locked TIFF enum, capacity, component, arithmetic, and palette checks ({len(cases)} probes)")
