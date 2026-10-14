"""Compare GIF loop counts, metadata precedence, aliases and exact bounds."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap

EXPECTED_ROWS = 160902
EXPECTED_SHA256 = 'ec13251605eb891bad0b2608663649fda9d7c1a20f64368775d96d491bda17e4'
EXPECTED_STATE_SHA256 = '97ff010dee4bb92007e127ad83d3a3e846eb4628271bbf17ae96f60986d04c56'
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_xbm_contracts_reference import FMT_SHA256

IDENTITIES = ((b'NETSCAPE', b'2.0'), (b'ANIMEXTS', b'1.0'))


def info(identifier=b'NETSCAPE', code=b'2.0', data=b'\x63\x07\x00'):
    assert len(identifier)==8 and len(code)==3
    return identifier+code+data


def spec(infos=(),op=0,index=0):
    return f'{op}|{index}|'+ ';'.join(value.hex() for value in infos)


def corpus():
    rows=[]
    for identifier,code in IDENTITIES:
        for count in range(65536):
            data=bytes((count&255,count&255,count>>8,165,90))
            rows.append(('all-counts',spec((info(identifier,code,data),))))
        for count,byte,op in itertools.product((0,1,2,255,256,65535),range(256),(1,2)):
            rows.append(('mutation-and-copy',spec((info(identifier,code,bytes((byte,count&255,count>>8))),),op)))
        identity=identifier+code
        for position,byte,length in itertools.product(range(11),range(256),range(4)):
            altered=identity[:position]+bytes((byte,))+identity[position+1:]
            if altered==identity and length<3:continue
            rows.append(('identifier-byte',spec((altered+bytes((99,37,0))[:length],))))
        for count,length in itertools.product((0,1,65535),range(65)):
            rows.append(('ignored-suffix',spec((info(identifier,code,bytes((255,count&255,count>>8))+bytes(range(length))),))))
    entries=(info(b'UNKNOWN!',b'abc',b''),info(b'NETSCAPE',b'abc',b'\x63\x07'),
             info(),info(b'ANIMEXTS',b'1.0',b'\x63\x09\x00'),info(data=b'\x63\x00\x00'),
             info(b'ANIMEXTS',b'1.0',b'\x63\xff'))
    for length in range(4):
        for sequence in itertools.product(entries,repeat=length):
            matching=next((value for value in sequence if (value[:8],value[8:11]) in IDENTITIES),None)
            if matching is not None and len(matching)<14:continue
            rows.append(('first-match',spec(sequence)))
            for index,value in enumerate(sequence):
                if len(value)>=14:
                    for op in (1,2):rows.append(('first-match-mutation',spec(sequence,op,index)))
    return rows


def traps():
    cases={}
    prefixes=((),(info(b'UNKNOWN!',b'abc',b''),),(info(b'NETSCAPE',b'abc',b''),),
              (info(b'netSCAPE',b'2.0',b'\xff\xff'),))
    for kind,(identifier,code) in enumerate(IDENTITIES):
        for sample,data in enumerate((b'',b'\x00',b'\xff',b'\x00\x00',b'\xff\xff',b'\x63\x00',b'\x63\xff')):
            for prefix,values in enumerate(prefixes):
                for suffix in (0,1):
                    infos=values+(info(identifier,code,data),)+((info(data=b'\x63\x11\x00'),) if suffix else ())
                    category='start index 1 is larger than end index 0' if not data else 'index out of bounds'
                    cases[f'short-{kind}-{sample}-{prefix}-{suffix}']=(spec(infos),category)
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path)
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    if args.timeout <= 0: parser.error('--timeout must be positive')
    source = args.source.resolve() / 'src'
    zig, v = args.zig.resolve(), args.v.resolve()
    fmt_path=zig.parent/'lib/std/fmt.zig'
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or hashlib.sha256(fmt_path.read_bytes()).hexdigest()!=FMT_SHA256:
        parser.error('Source or selected compiler library differs from the pins')
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/gif_loop_count'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-gif-loop-') as root:
        tmp=root/'tmp';tmp.mkdir()
        env.update(TMPDIR=str(tmp),VTMP=str(tmp))
        proof = ProofLog(root)
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('main.v', 'reference.zig'):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('unexpected compiler versions')
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py','verify_xbm_contracts_reference.py')}
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_revision='d7b7ab0ba0899643831ef042bd73289510b39906',
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            fmt_sha256=FMT_SHA256, versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, helper_sha256=helpers,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        print(f'Building GIF loop counts: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run([str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                   '--global-cache-dir', str(root.parent / 'zig-global'), '--cache-dir', str(root/'zig-cache'), '-femit-bin=' + str(root / 'native'),
                   str(root / 'reference.zig')], 'build-source', env=env, timeout=args.timeout)
        proof.run([str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path',
                   f'{repo}|@vlib|@vmodules', '-o', str(root / 'translated'), str(root / 'main.v')],
                  'build-v', env=env, timeout=args.timeout)
        rows = corpus()
        corpus_path = root / 'corpus.txt'
        corpus_path.write_text('\n'.join(data for _, data in rows) + '\n')
        input_hash=hashlib.sha256(corpus_path.read_bytes()).hexdigest()
        (root/'input_sha256.json').write_text(json.dumps({'corpus.txt':input_hash},indent=2)+'\n')
        outputs = []
        for exe in ('native', 'translated'):
            r = proof.run([str(root / exe), str(corpus_path)], 'returning-' + exe, env=env, timeout=args.timeout, check=False)
            if r.returncode or r.stderr or len(r.stdout.splitlines()) != len(rows):
                raise AssertionError(f'{exe}: invalid returning output ({r.returncode}, {len(r.stdout.splitlines())} rows); see raw proof files')
            outputs.append(r.stdout.splitlines())
        for index, (native, translated) in enumerate(zip(*outputs)):
            if native != translated:
                raise AssertionError(f'{index}/{rows[index][0]}: Source={native[:200]!r}, V={translated[:200]!r}; see retained corpus/output')
        digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and len(rows) != EXPECTED_ROWS: raise AssertionError('corpus changed')
        if EXPECTED_SHA256 is not None and digest != EXPECTED_SHA256: raise AssertionError('returning golden changed')
        print(f'{len(rows)} returning rows match; checking failure state', flush=True)
        states = hashlib.sha256()
        for name, (data, category) in traps().items():
            observed = []
            native_message = None
            for exe in ('native','translated'):
                path = root / (name + '-' + exe + '.state')
                r = proof.run([str(root / exe), '--trap', str(path), data], name + '-' + exe,
                              env=env, timeout=args.timeout, check=False)
                checked_trap(r, name + '/' + exe, category)
                messages=[match.group(1) for line in r.stderr.decode().splitlines() if (match:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                if len(messages)!=1:raise AssertionError(f'{name}/{exe}: expected sole panic: {messages}')
                if exe=='native':
                    native_message=messages[0]
                    if category=='index out of bounds' and not re.fullmatch(r'index out of bounds: index 2, len [01]',native_message):raise AssertionError('unexpected Source bounds diagnostic')
                    if category not in ('index out of bounds','access of union field') and native_message!=category:raise AssertionError('unexpected Source panic')
                elif messages!=[native_message]:raise AssertionError(f'{name}/{exe}: exact panic differs: {messages} != {[native_message]}')
                if not path.exists(): raise AssertionError('missing panic observer')
                observed.append(path.read_bytes())
            if not observed[0] or observed[0] != observed[1]: raise AssertionError(f'{name}: differing states {observed}')
            states.update(name.encode() + b'\0' + native_message.encode() + b'\0' + observed[0] + b'\n')
        state_digest = states.hexdigest()
        if EXPECTED_STATE_SHA256 is not None and state_digest != EXPECTED_STATE_SHA256: raise AssertionError('failure-state golden changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or hashlib.sha256(fmt_path.read_bytes()).hexdigest()!=FMT_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((p / name).read_bytes()).hexdigest() != expected for p in (root, probe)):
                raise AssertionError('fixture changed')
        if hashlib.sha256(corpus_path.read_bytes()).hexdigest()!=input_hash:raise AssertionError('input changed')
        for name,expected in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=expected:raise AssertionError('helper changed')
        summary = dict(returning_records=len(rows), returning_groups=dict(Counter(group for group, _ in rows)),
                       calls=sum((1,3,2)[int(data.split('|')[0])] for _,data in rows), output_sha256=digest,
                       paired_traps=len(traps()), state_sha256=state_digest, zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
