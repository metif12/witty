"""Compare the pinned chunk writer's direct methods and inherited build failures."""
import argparse
import hashlib
import os
from pathlib import Path
import resource
import shutil
import subprocess
import tempfile

from verify_png_foundation_reference import PINNED_SOURCE_SHA256, FLATE_SOURCES, PINNED_FLATE_SHA256


def corpus():
    cases = []
    for size in (0, 1, 4, 16, 16384):
        data = bytes((i*37+11) & 255 for i in range(size+3))
        sequences = [[], [b""], [b"a"], [data[:size]], [data[:size+1]],
                     [data[:size], b"x"], [data[:1], data[:size], data],
                     [data[:size//2], data[:size//2+1], data, b""],
                     [data[:size], b"", data[:size], data[:size]],
                     [b"a", b"bc", b"def", b"ghij", data]]
        capacities = sorted(set(range(25)) | {max(0,size+offset) for offset in (0,1,4,7,8,11,12,13,24,100)} | {size*3+100})
        for index, writes in enumerate(sequences):
            for capacity in capacities:
                for maximum in (0, 1, 3, size+1):
                    operations = ",".join(["W"+data.hex() for data in writes]+["F", "F"])
                    cases.append((f"size{size}-sequence{index}-capacity{capacity}-max{maximum}", f"{size}|{capacity}|{maximum}|{operations}"))
    return cases


def no_core():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("zig", type=Path)
    parser.add_argument("v", type=Path)
    parser.add_argument("--target", default="aarch64-macos.14.0")
    args = parser.parse_args()
    source = args.source.resolve()/"src"
    digest = hashlib.sha256()
    for path in sorted(source.rglob("*")):
        if path.is_file():
            digest.update(path.relative_to(source).as_posix().encode()+b"\0")
            digest.update(path.read_bytes())
    if digest.hexdigest() != PINNED_SOURCE_SHA256:
        parser.error("src differs from locked zigimg")
    digest = hashlib.sha256()
    for name in FLATE_SOURCES:
        digest.update(name.encode()+b"\0")
        digest.update((args.zig.resolve().parent/"lib/std"/name).read_bytes())
    if digest.hexdigest() != PINNED_FLATE_SHA256:
        parser.error("standard library differs from Zig 0.15.2")
    probe = Path(__file__).resolve().parent/"reference_probes/png_chunk_writer"
    with tempfile.TemporaryDirectory(prefix="witty-png-chunk-") as directory:
        root = Path(directory)
        shutil.copytree(source, root/"src")
        shutil.copyfile(probe/"reference.zig", root/"reference.zig")
        base = [str(args.zig.resolve()), "build-exe", "-target", args.target, "-lc"]
        subprocess.run(base+[f"-femit-bin={root/'native'}", str(root/"reference.zig")], check=True)
        subprocess.run([str(args.v.resolve()), "-o", str(root/"translated"), str(probe/"main.v")], env=dict(os.environ,VEXE=str(args.v.resolve()),V_C_ERROR_BUG_REPORT_DISABLED="1"),check=True)
        cases = corpus()
        corpus_path = root/"corpus.txt"
        corpus_path.write_text("\n".join(case[1] for case in cases)+"\n")
        outputs = [subprocess.run([str(root/executable),str(corpus_path)],capture_output=True,check=True,timeout=60).stdout.splitlines() for executable in ("native","translated")]
        if any(len(output)!=len(cases) for output in outputs):
            raise AssertionError([len(cases)]+[len(output) for output in outputs])
        for (label,_),native,translated in zip(cases,*outputs):
            if native!=translated:
                raise AssertionError(f"{label}: native={native!r}, V={translated!r}")
        digest=hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
        print(f"PNG chunk writer: {len(cases)} cases, SHA256 {digest}")
        for boundary in ("overflow","bounds"):
            corpus_path.write_text(f"4|128|0|{boundary}\n")
            for executable in ("native","translated"):
                result=subprocess.run([str(root/executable),str(corpus_path)],capture_output=True,timeout=5,preexec_fn=no_core)
                unexpected = any(line.startswith(b"UNEXPECTED") for line in result.stderr.splitlines()+result.stdout.splitlines())
                if result.returncode==0 or unexpected or not any(marker in result.stderr for marker in (b"panic:",b"Assertion failed",b"slice:")):
                    raise AssertionError((boundary,executable,result.returncode,result.stdout,result.stderr))
        print("PNG chunk writer: 2 checked traps matched")
        # These files expose unsupported upstream APIs; do not modify originals
        # or add replacement compression to make them compile.
        failures = {
            "legacy-writer": ('const S=struct{pub const Error=error{WriteFailed};}; pub fn main() void { _=@sizeOf(@import("src/formats/png/chunk_writer.zig").ChunkWriter(4,S).Writer); }', b"type 'type' not a function"),
            "zlib-compressor": ('pub fn main() void { _=@sizeOf(@import("src/formats/png/zlib_compressor.zig").ZlibCompressor(@import("std").Io.Writer)); }', b"no member named 'Compressor'"),
        }
        for label,(text,marker) in failures.items():
            path=root/(label+".zig")
            path.write_text(text+"\n")
            result=subprocess.run(base+[f"-femit-bin={root/label}",str(path)],capture_output=True)
            if result.returncode==0 or marker not in result.stderr:
                raise AssertionError((label,result.returncode,result.stderr))
        print("PNG helpers: legacy Writer and ZlibCompressor reject unchanged source under Zig 0.15.2")


if __name__ == "__main__":
    main()
