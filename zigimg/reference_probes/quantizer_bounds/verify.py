"""Compare checked quantizer boundaries in already-built V and Zig probes."""
import subprocess
import sys
import resource

if len(sys.argv) != 3:
    raise SystemExit("usage: verify.py V_PROBE ZIG_PROBE")

cases = ("palette_capacity", "repeated_reduction", "component_overflow", "green_overflow", "blue_overflow",
    "reference_overflow", "average_cast", "green_average_cast", "blue_average_cast", "zero_average",
    "color_level", "negative_color_level", "negative_level", "high_level", "leaf_count_underflow", "palette_context_capacity")
for case in cases:
    for executable in sys.argv[1:]:
        result = subprocess.run([executable, case], capture_output=True, timeout=5,
            preexec_fn=lambda: resource.setrlimit(resource.RLIMIT_CORE, (0, 0)))
        if result.returncode == 0 or b"UNEXPECTED" in result.stderr + result.stdout:
            raise SystemExit(f"{executable} {case} did not trap: {result.stderr!r}")
        if not any(marker in result.stderr for marker in (b"panic:", b"Assertion failed", b"array.get:")):
            raise SystemExit(f"{executable} {case} failed without a checked trap: {result.stderr!r}")

print(f"PASS: {len(cases)} V and unchanged locked quantizer capacity, reduction, arithmetic, and level checks")
