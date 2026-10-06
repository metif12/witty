"""Strictly compare already-built TIFF probes; this helper does not verify provenance."""
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from verify_tiff_metadata_bounds_reference import BOUNDS
from verify_tiff_decode_reference import checked_trap, no_core

if len(sys.argv) != 3:
    raise SystemExit("usage: verify.py V_PROBE ZIG_PROBE")

for case, categories in BOUNDS.items():
    for executable, category in zip(sys.argv[1:], reversed(categories)):
        result = subprocess.run([executable, case], capture_output=True, timeout=5, preexec_fn=no_core)
        checked_trap(result, executable + " " + case, category)

print(f"PASS: TIFF checked categories in supplied binaries ({len(BOUNDS)} probes; provenance not checked)")
