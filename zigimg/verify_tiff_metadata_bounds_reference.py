"""Compare public TIFF metadata values and checked failures with pinned source."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil

from verify_tiff_decode_reference import (
    PINNED_SOURCE_SHA256, ProofLog, checked_trap, tree_hash, work_directory,
)

STDLIB_SOURCES = ("hash_map.zig", "math.zig", "math/pow.zig", "math/powi.zig")
PINNED_STDLIB_SHA256 = "5fd6e9e31ace4bf2e70d2c01b131764cccfadef6f2ba9b287e072894826a3026"
INDEX_CHECKS = ("index out of bounds", "array.get: index out of range", "array.set: index out of range")
BOUNDS = {
    "unknown_tag": ("invalid enum value", "invalid TIFF tag enum"),
    "compression_enum": ("invalid enum value", "invalid TIFF compression enum"),
    "resolution_enum": ("invalid enum value", "invalid TIFF resolution enum"),
    **{name: ("index out of bounds", "FixedStorage resize exceeds inline capacity") for name in
       ("bits_capacity", "extra_capacity", "palette_capacity")},
    **{name: ("index out of bounds", INDEX_CHECKS) for name in
       ("empty_bits", "missing_alpha", "row_components", "short_palette")},
    "byte_overflow": ("integer overflow", "integer overflow"),
    "array_type": ("for loop over objects with non-equal lengths", "for loop over objects with non-equal lengths"),
    "palette_power": ("attempt to unwrap error: Overflow", "attempt to unwrap error: Overflow"),
    "map_capacity_cast": ("integer does not fit in destination type", "integer does not fit in destination type"),
    "map_capacity_power": ("attempt to unwrap error: Overflow", "attempt to unwrap error: Overflow"),
}
EXPECTED_ROWS = 86
EXPECTED_SHA256 = "c22c2516d50b6861d84f15605a3904f2a4fc935e45c8b3583ca0ead0c76f1346"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="locked zigimg package directory")
    parser.add_argument("zig", type=Path, help="Zig 0.15.2 executable")
    parser.add_argument("v", type=Path, help="pinned V executable")
    parser.add_argument("--target", default="aarch64-macos.14.0")
    parser.add_argument("--v-prod", action="store_true", help="compile V with -prod; defaults Zig to ReleaseSafe")
    parser.add_argument("--zig-mode", choices=("Debug", "ReleaseSafe"))
    parser.add_argument("--workdir", type=Path, help="retain sources, binaries, commands and diagnostics in an empty directory")
    args = parser.parse_args()
    args.zig_mode = args.zig_mode or ("ReleaseSafe" if args.v_prod else "Debug")
    source = args.source.resolve() / "src"
    if tree_hash(source) != PINNED_SOURCE_SHA256:
        parser.error("src differs from locked zigimg d7b7ab0ba0899643831ef042bd73289510b39906")
    stdlib = args.zig.resolve().parent / "lib/std"
    digest = hashlib.sha256()
    for name in STDLIB_SOURCES:
        digest.update(name.encode() + b"\0")
        digest.update((stdlib / name).read_bytes())
    if digest.hexdigest() != PINNED_STDLIB_SHA256:
        parser.error("HashMap and integer-power sources differ from Zig 0.15.2")
    probe = Path(__file__).resolve().parent / "reference_probes/tiff_metadata_bounds"
    repo = Path(__file__).resolve().parent.parent
    with work_directory(args.workdir, "witty-tiff-metadata-bounds-") as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / "src")
        if tree_hash(root / "src") != PINNED_SOURCE_SHA256:
            raise AssertionError("copied source differs from pinned source")
        for name in ("reference.zig", "main.v"):
            shutil.copyfile(probe / name, root / name)
        (root / "provenance.json").write_text(json.dumps({
            "source_sha256": PINNED_SOURCE_SHA256, "stdlib_sha256": PINNED_STDLIB_SHA256,
            "source_revision": "d7b7ab0ba0899643831ef042bd73289510b39906",
            "zig_mode": args.zig_mode, "v_prod": args.v_prod, "target": args.target,
            "reference_fixture_sha256": hashlib.sha256((root / "reference.zig").read_bytes()).hexdigest(),
            "v_fixture_sha256": hashlib.sha256((root / "main.v").read_bytes()).hexdigest(),
        }, indent=2) + "\n")
        print(f"Building TIFF metadata source {args.zig_mode} and V {'production' if args.v_prod else 'ordinary'}", flush=True)
        proof.run([str(args.zig.resolve()), "build-exe", "-target", args.target, "-lc", "-O", args.zig_mode,
                   f"-femit-bin={root / 'native'}", str(root / "reference.zig")], "build-source")
        environment = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED="1")
        proof.run([str(args.v.resolve()), *(["-prod"] if args.v_prod else []), "-path",
                   f"{repo}|@vlib|@vmodules", "-o", str(root / "translated"), str(root / "main.v")],
                  "build-v", env=environment)
        outputs = [proof.run([str(root / executable), "--returning"], f"returning-{executable}").stdout.splitlines()
                   for executable in ("native", "translated")]
        if any(len(rows) != EXPECTED_ROWS for rows in outputs):
            raise AssertionError([EXPECTED_ROWS, *map(len, outputs)])
        for index, (expected, actual) in enumerate(zip(*outputs)):
            if expected != actual:
                raise AssertionError(f"metadata row {index}: source={expected!r}, V={actual!r}")
        digest = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
        if digest != EXPECTED_SHA256:
            raise AssertionError(f"metadata output changed: {digest} != {EXPECTED_SHA256}")
        print(f"TIFF metadata: {EXPECTED_ROWS} returning records, SHA256 {digest}", flush=True)
        for name, categories in BOUNDS.items():
            for executable, category in zip(("native", "translated"), categories):
                label = f"trap-{executable}-{name}"
                result = proof.run([str(root / executable), name], label, timeout=10, check=False)
                checked_trap(result, label, category)
        print(f"TIFF metadata: {len(BOUNDS)} strict checked trap pairs matched", flush=True)
        if tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / "src") != PINNED_SOURCE_SHA256:
            raise AssertionError("source changed during the proof")
        (root / "result.json").write_text(json.dumps({"returning_records": EXPECTED_ROWS,
            "sha256": digest, "strict_trap_pairs": len(BOUNDS), "zig_mode": args.zig_mode,
            "v_prod": args.v_prod}, indent=2) + "\n")


if __name__ == "__main__":
    main()
