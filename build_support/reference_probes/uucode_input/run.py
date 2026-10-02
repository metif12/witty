#!/usr/bin/env python3
"""Regenerate the unchanged pinned uucode dependency input and compare bytes.
Usage: run.py /path/to/zig-0.15.2 /path/to/pinned-uucode [output.bin]
"""
from pathlib import Path
import hashlib, subprocess, sys, tempfile
zig, package = sys.argv[1:3]
p = Path(package).resolve()
here = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix="witty-uucode-input-") as directory:
    r = Path(directory)
    shared = ["--dep", "types.zig", "-Mconfig.zig=" + str(p / "src/config.zig"),
              "--dep", "config.zig", "-Mtypes.zig=" + str(p / "src/types.zig"),
              "--dep", "config.zig", "--dep", "types.zig", "--dep", "config.x.zig", "--dep", "types.x.zig",
              "-Mbuild_config=" + str(here / "uucode_config.zig"),
              "--dep", "types.x.zig", "--dep", "types.zig", "--dep", "config.zig", "-Mconfig.x.zig=" + str(p / "src/x/config.x.zig"),
              "--dep", "config.x.zig", "-Mtypes.x.zig=" + str(p / "src/x/types.x.zig")]
    # The original build.zig uses Debug for dependency table generation.
    subprocess.run([zig, "build-exe", "-lc", "-target", "aarch64-macos.14.0",
                    "--dep", "config.zig", "--dep", "build_config", "--dep", "types.zig",
                    "-Mroot=" + str(p / "src/build/tables.zig")] + shared + ["-femit-bin=" + str(r / "tables")], check=True)
    subprocess.run([str(r / "tables"), str(r / "tables.zig")], cwd=p, check=True, stdout=subprocess.DEVNULL)
    subprocess.run([zig, "build-exe", "-lc", "-target", "aarch64-macos.14.0",
                    "--dep", "tables", "-Mroot=" + str(here / "dump_tables.zig"),
                    "--dep", "config.zig", "--dep", "types.zig", "--dep", "types.x.zig", "--dep", "build_config",
                    "-Mtables=" + str(r / "tables.zig")] + shared + ["-femit-bin=" + str(r / "dump")], check=True)
    raw = subprocess.check_output([str(r / "dump")])
    expected = here.parents[2] / "build_assets/unicode/uucode-buildtime.bin"
    assert raw == expected.read_bytes(), "pinned dependency input differs"
    if len(sys.argv) > 3: Path(sys.argv[3]).write_bytes(raw)
    print("Matched", len(raw), "bytes; SHA-256", hashlib.sha256(raw).hexdigest())
