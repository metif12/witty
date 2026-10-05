"""Build the exact vaxis-locked uucode tables without changing dependency source.

Zig's native build runner currently detects a macOS target newer than its bundled
libSystem stub. Direct CLI modules select the same macOS 14 target as the probes,
and reproduce the dependency module graph from its unchanged build.zig.
"""
import hashlib
from pathlib import Path
import shutil
import subprocess

VAXIS_SHA256 = "bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed"
UUCODE_SHA256 = "2aa27f96be622d6fa42dcbf6b07f190c75450d2c98854ad33b1bab715783a380"
UUCODE_PACKAGE = "uucode-0.1.0-ZZjBPj96QADXyt5sqwBJUnhaDYs_qBeeKijZvlRa0eqM"
UUCODE_COMMIT = "5f05f8f83a75caea201f12cc8ea32a2d82ea9732"


def tree_hash(path):
    digest = hashlib.sha256()
    for item in sorted(Path(path).rglob("*")):
        if item.is_file():
            digest.update(item.relative_to(path).as_posix().encode() + b"\0")
            digest.update(item.read_bytes())
    return digest.hexdigest()


def module(name, path, dependencies=()):
    arguments = []
    for dependency in dependencies:
        arguments += ["--dep", dependency]
    return arguments + [f"-M{name}={path}"]


def prepare_uucode(zig, root, uucode, target="aarch64-macos.14.0"):
    """Return runtime module args after hashing/copying the locked package."""
    root, uucode = Path(root), Path(uucode)
    if tree_hash(uucode) != UUCODE_SHA256:
        raise ValueError("uucode package differs from the recorded locked source")
    dependency = root / "uucode"
    shutil.copytree(uucode, dependency)
    config = root / "build_config.zig"
    config.write_text('const config=@import("config.zig");const d=config.default;'
        'pub const tables=[_]config.Table{.{.fields=&.{d.field("east_asian_width"),'
        'd.field("grapheme_break"),d.field("general_category"),d.field("is_emoji_presentation")}}};\n')

    def shared(include_get):
        return (module("config.zig", dependency / "src/config.zig", ["types.zig"])
            + module("types.zig", dependency / "src/types.zig",
                     ["config.zig", "get.zig"] if include_get else ["config.zig"])
            + module("config.x.zig", dependency / "src/x/config.x.zig",
                     ["types.x.zig", "types.zig", "config.zig"])
            + module("types.x.zig", dependency / "src/x/types.x.zig", ["config.x.zig"])
            + module("build_config", config, ["types.zig", "config.zig", "types.x.zig", "config.x.zig"]))

    subprocess.run([str(zig), "build-exe", "-target", target, "-lc",
        *module("root", dependency / "src/build/tables.zig", ["config.zig", "build_config", "types.zig"]),
        *shared(False), f"-femit-bin={root / 'uucode_generator'}"], check=True)
    subprocess.run([str(root / "uucode_generator"), str(root / "tables.zig")], cwd=dependency, check=True)
    return (module("uucode", dependency / "src/root.zig",
                   ["types.zig", "config.zig", "types.x.zig", "tables", "get.zig"])
        + shared(True)
        + module("tables", root / "tables.zig", ["types.zig", "types.x.zig", "config.zig", "build_config"])
        + module("get.zig", dependency / "src/get.zig", ["types.zig", "tables"]))
