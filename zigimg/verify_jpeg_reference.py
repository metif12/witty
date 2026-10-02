"""Compare the V JPEG reader with unchanged locked zigimg (requires Pillow).

The source has undefined, uninitialized component blocks for some padded
progressive/subsampled/restart inputs. Its checked build may trap in IDCT or
coefficient multiplication. Those are reported separately, never called matches.
"""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
from PIL import Image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--zig', required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--v', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    source = Path(args.source)
    probes = root / 'zigimg/reference_probes/jpeg_decode'
    with tempfile.TemporaryDirectory(prefix='witty-jpeg-reference-') as tmp:
        tmp = Path(tmp)
        files = []
        for width, height in [(8, 8), (17, 3), (31, 17), (32, 32)]:
            for mode in ['L', 'RGB']:
                for progressive in [False, True]:
                    for sub in ([0] if mode == 'L' else [0, 1, 2]):
                        for restart in [0, 1]:
                            image = Image.new(mode, (width, height))
                            image.putdata([((x * 37 + y * 13) & 255) if mode == 'L' else
                                (((x * 37 + y * 13) & 255), ((x * 5 + y * 61) & 255),
                                 ((x * 17 + y * 3) & 255))
                                for y in range(height) for x in range(width)])
                            path = tmp / f'{width}x{height}-{mode}-{int(progressive)}-{sub}-{restart}.jpg'
                            image.save(path, quality=90, subsampling=sub, progressive=progressive,
                                       restart_marker_blocks=restart)
                            files.append(path)
        original = files[0].read_bytes()
        for count in [0, 1, 2, 4, 8, 16, 64, 128]:
            path = tmp / f'truncated-{count}.jpg'
            path.write_bytes(original[:count])
            files.append(path)
        for name, bytes_ in [('bad-soi', b'\x00\x00'),
                             ('unsupported-frame', b'\xff\xd8\xff\xc1')]:
            path = tmp / f'{name}.jpg'
            path.write_bytes(bytes_)
            files.append(path)
        native = tmp / 'native'
        translated = tmp / 'translated'
        subprocess.run([args.zig, 'build-exe', '-target', 'aarch64-macos.14.0', '-lc',
            '--dep', 'zigimg', f'-Mroot={probes / "main.zig"}',
            f'-Mzigimg={source / "zigimg.zig"}', f'-femit-bin={native}'], check=True)
        subprocess.run([args.v, '-path', f'{root}|@vlib|@vmodules', '-o', str(translated),
                        str(probes / 'main.v')], check=True, env={**os.environ, 'VEXE': args.v})
        matched = 0
        traps = []
        for path in files:
            n = subprocess.run([native, path], capture_output=True, timeout=5)
            v = subprocess.run([translated, path], capture_output=True, timeout=5)
            if n.returncode != 0:
                traps.append(path.name)
                continue
            if v.returncode != 0 or n.stderr != v.stdout:
                raise AssertionError((path.name, n.returncode, n.stderr, v.returncode, v.stdout, v.stderr))
            matched += len(n.stderr.splitlines())
        hashes = hashlib.sha256()
        for path in sorted((source / 'src/formats/jpeg').glob('*.zig')):
            hashes.update(path.read_bytes())
        hashes.update((source / 'src/formats/jpeg.zig').read_bytes())
        print(f'{matched} native/V result rows matched; {len(traps)} source checked traps excluded')
        print('Source checked traps:', ', '.join(traps))
        print('JPEG source SHA-256 (sorted support files then jpeg.zig):', hashes.hexdigest())


if __name__ == '__main__':
    main()
