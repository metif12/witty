"""Compare public vxfw.App lifecycle through a controlled native macOS PTY."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import pty
import re
import resource
import select
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import time

PROBE = Path(__file__).resolve().parent / 'reference_probes/app_run'
REPO = PROBE.parents[2]
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash


def session():
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    signal.signal(signal.SIGTTOU, signal.SIG_IGN)
    os.setsid()
    fcntl.ioctl(0, termios.TIOCSCTTY, 0)
    os.tcsetpgrp(0, os.getpgrp())
    signal.signal(signal.SIGTTOU, signal.SIG_DFL)


def cases():
    return [(name, rate) for name in (
        'init_only', 'init_quit', 'basic', 'focus', 'capture_consume', 'target_consume',
        'commands', 'buffer_probe', 'timers', 'timer_nested', 'seed_sorted', 'seed_unsorted', 'seed_resort', 'focus_change', 'refresh', 'focus_reports',
        'mouse', 'resize', 'error_init', 'error_focus', 'error_draw', 'error_capture',
        'error_key', 'error_tick', 'error_enter', 'error_mouse', 'error_focus_in', 'error_focus_out')
        for rate in ((0, 60, 255) if name in ('basic', 'timers') else (60,))]


TRAPS = {
    'focus_invalid': ('reached unreachable code', 'Assertion failed'),
    'focus_absent': ('reached unreachable code', 'Assertion failed'),
    'zero_width': ('division by zero', 'division by zero'),
    'zero_height': ('division by zero', 'division by zero'),
    'render_invalid': ('reached unreachable code', 'Assertion failed'),
    'surface_overflow': ('integer overflow', 'integer overflow'),
    'layout_commands': ('reached unreachable code', 'Assertion failed'),
}


def plan(name):
    draw = lambda text: any(line.startswith('D|0|') for line in text.splitlines())
    key = lambda code: lambda text: f'|key|{ord(code)}\n' in text
    if name in ('basic', 'focus', 'seed_unsorted'):
        return [(draw, b'q')]
    if name == 'focus_absent':
        return [(draw, b'q')]
    if name in ('error_key', 'error_capture'):
        return [(draw, b'e')]
    if name == 'capture_consume':
        return [(draw, b'c'), (key('c'), b'q')]
    if name == 'target_consume':
        return [(draw, b't'), (key('t'), b'q')]
    if name in ('error_focus_in', 'error_focus_out'):
        return [(draw, b'f')]
    if name == 'focus_change':
        return [(draw, b'f'), (lambda text: 'D|0|2|' in text, b'q')]
    if name == 'refresh':
        return [(draw, b'r'), (lambda text: 'D|0|2|' in text, b'q')]
    if name == 'focus_reports':
        return [(draw, b'\x1b[O'), (lambda text: 'H|0|at_target|focus_out\n' in text, b'\x1b[I'),
                (lambda text: text.count('H|0|at_target|focus_in\n') == 2, b'q')]
    if name in ('mouse', 'error_enter', 'error_mouse'):
        steps = [(draw, b'\x1b[<0;3;3M')]
        if name == 'mouse':
            steps += [(lambda text: 'H|0|bubbling|mouse|' in text, b'\x1b[<0;3;3m'),
                      (lambda text: '|left|release\n' in text, b'\x1b[O'),
                      (lambda text: 'H|0|at_target|focus_out\n' in text, b'q')]
        return steps
    if name == 'resize':
        return [(draw, b'\x1b[48;5;9;50;90t'),
                (lambda text: 'D|0|2|9|5|10|10\n' in text, b'q')]
    return []


def run_pty(binary, case, environment, root, label, timeout=15):
    name, rate = case
    master, slave = pty.openpty()
    release, send = os.pipe()
    initial = termios.tcgetattr(slave)
    initial[0] = termios.BRKINT | termios.ICRNL | termios.IXON
    initial[1] = termios.OPOST | termios.ONLCR
    initial[2] = termios.CS8 | termios.CREAD | termios.HUPCL
    initial[3] = termios.ISIG | termios.ICANON | termios.ECHO | termios.ECHOE | termios.ECHOK | termios.IEXTEN
    initial[4] = initial[5] = termios.B9600
    initial[6] = [bytes([byte]) for byte in (4,255,255,127,23,21,18,255,3,28,26,25,17,19,22,15,1,0,20,255)]
    termios.tcsetattr(slave, termios.TCSANOW, initial)
    before = termios.tcgetattr(slave)
    rows, cols = ((4, 0) if name == 'zero_width' else (0, 8) if name == 'zero_height'
                  else (256, 256) if name == 'surface_overflow' else (4, 8))
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, cols * 10, rows * 10))
    process = subprocess.Popen([str(binary), name, str(rate), str(release)], stdin=slave,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, preexec_fn=session,
        pass_fds=(release,), env=environment)
    os.close(release); release = -1
    os.set_blocking(master, False)
    watched = [master, process.stdout.fileno(), process.stderr.fileno()]
    output = b''; diagnostic = b''; tty = b''; answered = 0; stopped = 0; step = 0
    steps = plan(name)
    deadline = time.monotonic() + timeout
    restored = False
    barrier = None
    try:
        while time.monotonic() < deadline:
            for descriptor in select.select(watched, [], [], 0.025)[0]:
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
            # DA1 wakes the public capability query. DSR wakes stop's blocked
            # reader; keep servicing it after the final callback/error too.
            queries = tty.count(b'\x1b[c')
            while answered < queries:
                os.write(master, b'\x1b[?1;2c'); answered += 1
            status = tty.count(b'\x1b[5n')
            while stopped < status:
                os.write(master, b'\x1b[0n'); stopped += 1
            text = output.decode(errors='replace')
            if 'BARRIER\n' in text and barrier is None:
                # Focus callback is held; no command flush or shutdown can race
                # the observed buffered/unbuffered raw write. Drain pending
                # PTY bytes before releasing that public callback.
                time.sleep(0.025)
                while select.select([master], [], [], 0)[0]:
                    tty += os.read(master, 65536)
                barrier = tty
                (root/f'{label}-{name}-{rate}.barrier').write_bytes(barrier)
                os.write(send, b'+')
            if step < len(steps) and steps[step][0](text):
                os.write(master, steps[step][1]); step += 1
            if b'DONE\n' in output:
                time.sleep(0.015)
                while select.select([master], [], [], 0)[0]:
                    tty += os.read(master, 65536)
                restored = termios.tcgetattr(slave) == before
                if process.poll() is not None:
                    raise AssertionError(f'{label} {case}: consumer exited before held termios observation')
                os.write(send, b'+')
                break
            if name in TRAPS and b'panic:' in diagnostic:
                break
            if process.poll() is not None:
                break
        else:
            raise AssertionError(f'{label} {case}: timed out at step {step}: {output!r}; {diagnostic!r}')
        # Close PTY before process exit to avoid macOS controlling-TTY close
        # stalls. All terminal restoration observations precede this close.
        os.close(master); master = -1; os.close(slave); slave = -1
        tail, error = process.communicate(timeout=5)
        output += tail; diagnostic += error
        (root/f'{label}-{name}-{rate}.stdout').write_bytes(output)
        (root/f'{label}-{name}-{rate}.stderr').write_bytes(diagnostic)
        (root/f'{label}-{name}-{rate}.tty').write_bytes(tty)
        lines = (output + diagnostic).decode(errors='replace').splitlines()
        if any(line.lstrip().startswith('UNEXPECTED') for line in lines):
            raise AssertionError(f'{label} {case}: unexpected fixture error: {lines}')
        if name in TRAPS:
            category = TRAPS[name][0 if label == 'native' else 1]
            headers = [match.group(1) for line in diagnostic.decode(errors='replace').splitlines()
                       if (match := re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)', line))]
            if process.returncode == 0 or category not in headers or b'R|' in output or b'DONE\n' in output:
                raise AssertionError(f'{label} {case}: missing {category} trap: {output!r}; {diagnostic!r}')
        elif process.returncode or diagnostic or not restored or not output.endswith(b'DONE\n') or step != len(steps):
            raise AssertionError(f'{label} {case}: returning failure ({process.returncode}, restore={restored}, step={step}): {output!r}; {diagnostic!r}')
        if name == 'buffer_probe':
            visible = b'buffered-proof' in barrier
            if visible != (label == 'translated'):
                raise AssertionError(f'{label}: buffer boundary not observed: {barrier!r}')
        return output, tty
    finally:
        for descriptor in (master, slave, release, send):
            if descriptor >= 0: os.close(descriptor)
        if process.poll() is None:
            process.kill(); process.wait(timeout=5)


def verify(args, root):
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256:
        raise ValueError('Vaxis source differs from the pinned tree')
    shutil.copytree(source, root/'src')
    graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), 'aarch64-macos.14.0')
    shutil.copy2(PROBE/'reference.zig', root/'reference.zig')
    shutil.copy2(PROBE/'main.v', root/'main.v')
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    native = [str(args.zig.resolve()), 'build-exe', '-O', mode, '-target', 'aarch64-macos.14.0', '-lc',
              *module('root', root/'reference.zig', ['vaxis']),
              *module('vaxis', root/'src/main.zig', ['uucode']), *graph, f'-femit-bin={root/"native"}']
    translated = [str(args.v.resolve()), *(['-prod'] if args.v_prod else []), '-keepc',
                  '-path', f'{REPO}|@vlib|@vmodules', '-o', str(root/'translated'), str(root/'main.v')]
    environment = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    for key in ('TERMUX_VERSION', 'VHS_RECORD', 'TERM_PROGRAM', 'VAXIS_FORCE_LEGACY_SGR',
                'VAXIS_FORCE_WCWIDTH', 'VAXIS_FORCE_UNICODE', 'VAXIS_FORCE_NO_KITTY_KEYBOARD'):
        environment.pop(key, None)
    environment['TERM'] = 'xterm-256color'
    for label, argv in (('native', native), ('translated', translated)):
        print(f'Building {label} {mode}', file=sys.stderr, flush=True)
        (root/f'{label}-argv.json').write_text(json.dumps(argv))
        subprocess.run(argv, env=environment, check=True)
        if label == 'translated':
            generated = Path('/tmp') / f'v_{os.getuid()}' / 'translated.tmp.c'
            if generated.exists() and b'buffered-proof' in generated.read_bytes() and b'seed_resort' in generated.read_bytes():
                shutil.copy2(generated, root/'translated-generated.c')
    records = []
    output_rows = []
    for case in cases():
        print(f'Checking {case}', file=sys.stderr, flush=True)
        expected, source_output = run_pty(root/'native', case, environment, root, 'native', args.timeout)
        actual, v_output = run_pty(root/'translated', case, environment, root, 'translated', args.timeout)
        if actual != expected:
            raise AssertionError(f'{case}: callback/state traces differ:\nSource {expected!r}\nV {actual!r}')
        prefix = '|'.join(map(str, case)).encode()
        records.append(prefix+b'|'+expected)
        # Retain raw bytes and explicitly report equal/different output rather
        # than excluding buffering/control-sequence differences from a claim.
        output_rows.append(prefix+b'|'+str(len(source_output)).encode()+b'|'+str(len(v_output)).encode()+b'|'+hashlib.sha256(source_output).hexdigest().encode()+b'|'+hashlib.sha256(v_output).hexdigest().encode())
    for name in TRAPS:
        expected, _ = run_pty(root/'native', (name, 60), environment, root, 'native', args.timeout)
        actual, _ = run_pty(root/'translated', (name, 60), environment, root, 'translated', args.timeout)
        if expected != actual:
            raise AssertionError(f'{name}: pre-trap callback traces differ: {expected!r}; {actual!r}')
    data = b''.join(records)
    (root/'returning.txt').write_bytes(data)
    (root/'terminal-output.txt').write_bytes(b'\n'.join(output_rows)+b'\n')
    print(f'App.run ({mode}, V {"production" if args.v_prod else "ordinary"}): {len(records)} returning public PTY traces, {len(TRAPS)} strict public trap pairs; SHA256 {hashlib.sha256(data).hexdigest()}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--uucode', type=Path, default=Path.home()/'.cache/zig/p'/UUCODE_PACKAGE)
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path)
    parser.add_argument('--timeout', type=float, default=15)
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    if args.workdir:
        root = args.workdir.resolve(); root.mkdir(); verify(args, root)
    else:
        with tempfile.TemporaryDirectory(prefix='witty-app-run-') as directory:
            verify(args, Path(directory))


if __name__ == '__main__': main()
