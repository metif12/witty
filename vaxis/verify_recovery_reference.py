"""Compare global-TTY recovery and explicit panic entry points with unchanged Vaxis."""
import argparse
import fcntl
import hashlib
import itertools
import json
import os
from pathlib import Path
import pty
import re
import resource
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import termios
import time

PROBE = Path(__file__).resolve().parent / 'reference_probes/recovery'
REPO = PROBE.parents[2]
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash

RESET = b'\x1b[<u\x1b[?1002;1003;1004;1006;1016l\x1b[?2004l\x1b[?1049l'


def cases():
    rows = [('empty', n, 0, 0) for n in (0, 1, 2, 4)]
    rows += [('none_fail', n, 0, 0) for n in (1, 2)]
    rows += [('basic', n, 0, p) for n, p in itertools.product((0, 1, 2, 3, 8), (0, 1, 7, 63))]
    rows += [(mode, n, 0, p) for mode, n, p in itertools.product(('mutate', 'deinit', 'two', 'fail_init', 'readonly'), (1, 2, 3), (0, 3))]
    return rows


def buffers():
    return [('basic', n, size, prefix) for n, size, prefix in itertools.product((1, 2, 3), (1, 8, 32, 47, 48, 49, 64, 128), (0, 5))]


def attrs(value):
    return [*value[:6], [byte if isinstance(byte, int) else byte[0] for byte in value[6]]]


def session():
    # Fixture process setup only: acquire the PTY and its foreground process group.
    # Ignore HUP so closing the observed PTY cannot terminate the held consumer.
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    signal.signal(signal.SIGTTOU, signal.SIG_IGN)
    os.setsid()
    fcntl.ioctl(0, termios.TIOCSCTTY, 0)
    os.tcsetpgrp(0, os.getpgrp())
    signal.signal(signal.SIGTTOU, signal.SIG_DFL)


def read_available(fd):
    data = b''
    while select.select([fd], [], [], 0)[0]:
        try:
            chunk = os.read(fd, 65536)
        except BlockingIOError:
            break
        if not chunk:
            break
        data += chunk
    return data


def full_pipe():
    read, write = os.pipe()
    os.set_blocking(write, False)
    total = 0
    for chunk in (b'F' * 4096, b'F'):
        while True:
            try:
                total += os.write(write, chunk)
            except BlockingIOError:
                break
    os.set_blocking(write, True)
    return read, write, total


def run_pty(binary, case, environment, panic=False):
    mode, count, size, prefix = case
    master, slave = pty.openpty()
    release, send = os.pipe()
    initial = termios.tcgetattr(slave)
    # macOS can retain raw attributes when a PTY minor is reused. Start every
    # process from the same explicit canonical fixture profile.
    initial[0] = termios.BRKINT | termios.ICRNL | termios.IXON
    initial[1] = termios.OPOST | termios.ONLCR
    initial[2] = termios.CS8 | termios.CREAD | termios.HUPCL
    initial[3] = termios.ISIG | termios.ICANON | termios.ECHO | termios.ECHOE | termios.ECHOK | termios.IEXTEN
    initial[4] = initial[5] = termios.B9600
    initial[6] = [bytes([byte]) for byte in (4,255,255,127,23,21,18,255,3,28,26,25,17,19,22,15,1,0,20,255)]
    termios.tcsetattr(slave, termios.TCSANOW, initial)
    before = termios.tcgetattr(slave)
    pipe_read = pipe_write = -1
    filler = 0
    if panic:
        pipe_read, pipe_write, filler = full_pipe()
    env = dict(environment, WITTY_RECOVERY_CASE='|'.join(map(str, case)), WITTY_RECOVERY_RELEASE_FD=str(release))
    process = subprocess.Popen([str(binary), *map(str, case), str(release)], stdin=slave,
        stdout=subprocess.PIPE, stderr=pipe_write if panic else subprocess.PIPE,
        preexec_fn=session, pass_fds=(release,), env=env)
    os.close(release); release = -1
    if pipe_write >= 0:
        os.close(pipe_write); pipe_write = -1
    os.set_blocking(master, False)
    output = b''; diagnostic = b''; tty = b''
    watched = [master, process.stdout.fileno()]
    if not panic:
        watched.append(process.stderr.fileno())
    deadline = time.monotonic() + 10
    try:
        # Drain the master concurrently: macOS terminal attribute changes may
        # wait for output to drain before the consumer can print observations.
        while b'\n' not in output and time.monotonic() < deadline:
            for descriptor in select.select(watched, [], [], 0.05)[0]:
                try:
                    chunk = os.read(descriptor, 65536)
                except BlockingIOError:
                    continue
                if not chunk:
                    watched.remove(descriptor)
                    continue
                if descriptor == master:
                    tty += chunk
                elif descriptor == process.stdout.fileno():
                    output += chunk
                else:
                    diagnostic += chunk
        if b'\n' not in output:
            raise AssertionError(f'{binary.name} {case}: missing observation: {output!r} {diagnostic!r}')
        if panic:
            if output != b'READY\n':
                raise AssertionError(f'{binary.name} {case}: unexpected pre-panic output {output!r}')
            expected = (b'' if mode == 'panic_empty' else b'P' * prefix) + (b'' if mode in ('panic_empty', 'panic_readonly') else RESET)
            # With the panic diagnostic blocked on the full pipe, observe actual
            # restored termios before allowing the panic runtime to terminate.
            while time.monotonic() < deadline:
                tty += read_available(master)
                current = termios.tcgetattr(slave)
                target_matches = current != before if mode == 'panic_two' else current == before
                if tty == expected and target_matches:
                    break
                time.sleep(0.002)
            else:
                raise AssertionError(f'{binary.name} {case}: reset/restore order not observed: {tty!r}')
            if process.poll() is not None:
                raise AssertionError(f'{binary.name} {case}: panic exited before blocked diagnostic observation')
            observed = attrs(current)
            # Closing the PTY before waiting avoids macOS /dev/tty exit-close
            # stalls; all terminal state and bytes have already been observed.
            os.close(master); master = -1; os.close(slave); slave = -1
            os.set_blocking(pipe_read, False)
            stream = b''
            while time.monotonic() < deadline:
                stream += read_available(pipe_read)
                if process.poll() is not None:
                    stream += read_available(pipe_read)
                    break
                time.sleep(0.002)
            else:
                raise AssertionError(f'{binary.name} {case}: panic runtime did not terminate')
            tail, _ = process.communicate(timeout=2)
            output += tail
            if stream[:filler] != b'F' * filler:
                raise AssertionError('panic pipe filler changed')
            diagnostic = stream[filler:]
            texts = (output + diagnostic).decode(errors='replace')
            headers = [match.group(1) for line in diagnostic.decode(errors='replace').splitlines()
                       if (match := re.fullmatch(r'(?:thread \d+ )?(?:V )?panic:\s*(.*)', line))]
            if process.returncode == 0 or output != b'READY\n' or any(line.lstrip().startswith('UNEXPECTED') for line in texts.splitlines()) or 'recovery-proof' not in headers:
                raise AssertionError(f'{binary.name} {case}: missing explicit panic: {texts}')
            return b'panic|'+tty.hex().encode()+b'|'+json.dumps(observed, separators=(',', ':')).encode(), diagnostic
        tty += read_available(master)
        observed = attrs(termios.tcgetattr(slave))
        if process.poll() is not None:
            raise AssertionError(f'{binary.name} {case}: observation consumer did not remain alive')
        os.write(send, b'+')
        os.close(master); master = -1; os.close(slave); slave = -1
        tail, error = process.communicate(timeout=5)
        output += tail; diagnostic += error
        if process.returncode or diagnostic or not re.fullmatch(rb'[01](?:,[01]){5},\d+,[01]\n', output):
            raise AssertionError(f'{binary.name} {case}: failed returning consumer {process.returncode}: {output!r} {diagnostic!r}')
        record = output.rstrip(b'\n')+b'|'+tty.hex().encode()+b'|'+json.dumps(observed, separators=(',', ':')).encode()
        return record, b''
    finally:
        for descriptor in (master, slave, release, send, pipe_read, pipe_write):
            if descriptor >= 0:
                os.close(descriptor)
        if process.poll() is None:
            process.kill(); process.wait(timeout=5)



def ordinary_rejection(result, label, required):
    diagnostic = (result.stdout + result.stderr).decode(errors='replace')
    bug = re.search(r'(?im)(?:panic:|segmentation fault|compiler bug|compiler error:|C compilation failed|builder error:|internal compiler|report a bug|please report this)', diagnostic)
    if result.returncode != 1 or bug or not re.search(r'(?m)^.*error:.*$', diagnostic) or required not in diagnostic:
        raise AssertionError(f'{label}: missing ordinary compiler boundary: {diagnostic}')


def compiler_boundaries(root, environment):
    native = json.loads((root/'native-argv.json').read_text())
    translated = json.loads((root/'translated-argv.json').read_text())
    names = ('sentinel_mismatch', 'unwrap_error', 'out_of_bounds', 'start_greater_than_end', 'inactive_union_field', 'messages')
    for name in (*names, 'global_access'):
        source = [f'-Mroot={PROBE/"contracts"/(name+".zig")}' if arg.startswith('-Mroot=') else arg
                  for arg in native if not arg.startswith('-femit-bin=')]
        source += [f'-femit-bin={root/"global_access"}'] if name == 'global_access' else ['-fno-emit-bin']
        result = subprocess.run(source, capture_output=True, env=environment)
        (root/('source-contract-'+name+'.stderr')).write_bytes(result.stderr)
        if name == 'global_access':
            if result.returncode:
                raise AssertionError(result.stderr.decode(errors='replace'))
            observed = subprocess.run([str(root/'global_access')], capture_output=True, env=environment)
            if observed.returncode or observed.stdout or observed.stderr:
                raise AssertionError('source public empty global access failed')
        else:
            ordinary_rejection(result, 'Source '+name, 'FormattedPanic')
        v = [arg for arg in translated[:-1] if arg != '-keepc']
        index = v.index('-o'); del v[index:index+2]
        v += ['-check', str(PROBE/'contracts'/(name+'.v'))]
        result = subprocess.run(v, capture_output=True, env=environment)
        (root/('V-contract-'+name+'.stderr')).write_bytes(result.stderr)
        ordinary_rejection(result, 'V '+name, 'global_tty' if name == 'global_access' else name)
    return len(names)

def verify(args, root):
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256:
        raise ValueError('vaxis source differs from the recorded local source')
    shutil.copytree(source, root / 'src')
    graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), 'aarch64-macos.14.0')
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    native = [str(args.zig.resolve()), 'build-exe', '-O', mode, '-target', 'aarch64-macos.14.0', '-lc',
              *module('root', PROBE/'reference.zig', ['vaxis']), *module('vaxis', root/'src/main.zig', ['uucode']),
              *graph, f'-femit-bin={root/"native"}']
    snapshot = root / 'translated_src'; snapshot.mkdir()
    shutil.copy2(REPO/'v.mod', snapshot/'v.mod')
    shutil.copytree(REPO/'vaxis', snapshot/'vaxis')
    shutil.copy2(PROBE/'probe.v', snapshot/'vaxis/recovery_reference_test.v')
    environment = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1', WITTY_RECOVERY_CASE='')
    translated = [str(args.v.resolve()), *(['-prod'] if args.v_prod else []), '-keepc', '-path', f'{snapshot}|{REPO}|@vlib|@vmodules', '-o', str(root/'translated'), str(snapshot/'vaxis/recovery_reference_test.v')]
    for name, command in (('native', native), ('translated', translated)):
        print('Building '+name+' '+mode, file=sys.stderr, flush=True)
        (root/(name+'-argv.json')).write_text(json.dumps(command))
        subprocess.run(command, env=environment, check=True)
    outputs = []
    for name in ('native', 'translated'):
        returning = []
        for index, case in enumerate(cases()):
            record, _ = run_pty(root/name, case, environment)
            expected = (b'' if case[0] in ('empty', 'none_fail') else b'P'*case[3]) + (b'' if case[0] in ('empty', 'none_fail', 'readonly') else RESET*case[1])
            if record.split(b'|')[1] != expected.hex().encode():
                raise AssertionError(f'{name} {case}: wrong reset bytes: {record}')
            returning.append(record)
        (root/(name+'-returning.txt')).write_bytes(b'\n'.join(returning)+b'\n')
        outputs.append(returning)
    for case, expected, actual in zip(cases(), *outputs):
        if expected != actual:
            raise AssertionError(f'{case}: source={expected!r}; V={actual!r}')
    panics = [('panic_'+name, 1, 0, prefix) for name, prefix in itertools.product(('empty', 'basic', 'call', 'trace', 'readonly', 'two', 'mutate'), (0, 3))]
    for index, case in enumerate(panics):
        records = []
        for name in ('native', 'translated'):
            record, diagnostic = run_pty(root/name, case, environment, panic=True)
            (root/f'{name}-panic-{index}.stderr').write_bytes(diagnostic)
            records.append(record)
        if records[0] != records[1]:
            raise AssertionError(f'{case}: panic recovery records differ {records}')
    buffered = []
    for case in buffers():
        record, _ = run_pty(root/'native', case, environment)
        buffered.append('|'.join(map(str, case)).encode()+b'|'+record)
    (root/'source-buffered.txt').write_bytes(b'\n'.join(buffered)+b'\n')
    # At the reset-sized source buffer, first recover retains reset bytes without
    # flushing them; V intentionally exposes only the zero-buffer write contract.
    first = buffers().index(('basic', 1, len(RESET), 0))
    fields = buffered[first].split(b'|')
    if fields[5] != b'' or fields[4].split(b',')[6] != str(len(RESET)).encode():
        raise AssertionError('source buffered boundary was not observed')
    boundaries = compiler_boundaries(root, environment)
    digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
    buffered_digest = hashlib.sha256(b'\n'.join(buffered)).hexdigest()
    print(f'Recovery: {len(cases())} returning PTY records, {len(panics)} explicit panic/order pairs, {len(buffered)} source-only buffered records, {boundaries} paired ordinary removed-stdlib alias boundaries, 1 measured public-variable access adaptation; SHA256 {digest}; buffered SHA256 {buffered_digest}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--uucode', type=Path, default=Path.home()/'.cache/zig/p'/UUCODE_PACKAGE)
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path, help='retain artifacts in a new directory')
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    if args.workdir:
        root = args.workdir.resolve(); root.mkdir(); verify(args, root)
    else:
        with tempfile.TemporaryDirectory(prefix='witty-recovery-') as directory:
            verify(args, Path(directory))


if __name__ == '__main__':
    main()
