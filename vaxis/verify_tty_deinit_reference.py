"""Compare macOS public Tty.deinit with the unchanged zero-buffer writer source."""
import argparse
import fcntl
import hashlib
import itertools
import json
import os
from pathlib import Path
import pty
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
REPO=Path(__file__).resolve().parent.parent
PROBE=REPO/'vaxis/reference_probes/tty_deinit'
sys.path.insert(0,str(PROBE.parent/'widgets_classic'))
from source_build import VAXIS_SHA256,UUCODE_SHA256,UUCODE_PACKAGE,module,prepare_uucode,tree_hash


def session():
    signal.signal(signal.SIGHUP,signal.SIG_IGN);signal.signal(signal.SIGTTOU,signal.SIG_IGN)
    os.setsid();fcntl.ioctl(0,termios.TIOCSCTTY,0);os.tcsetpgrp(0,os.getpgrp())
    signal.signal(signal.SIGTTOU,signal.SIG_DFL)


def run_pty(binary,case,environment,timeout,root=None,label=None):
    count,mutate,rows,cols=case
    master,slave=pty.openpty();release,send=os.pipe()
    original=termios.tcgetattr(slave)
    original[0]=termios.BRKINT|termios.ICRNL|termios.IXON;original[1]=termios.OPOST|termios.ONLCR
    original[2]=termios.CS8|termios.CREAD|termios.HUPCL
    original[3]=termios.ISIG|termios.ICANON|termios.ECHO|termios.ECHOE|termios.ECHOK|termios.IEXTEN
    termios.tcsetattr(slave,termios.TCSANOW,original);original=termios.tcgetattr(slave)
    fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',rows,cols,32,48))
    process=subprocess.Popen([str(binary),str(count),str(int(mutate)),str(release)],stdin=slave,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=environment,pass_fds=(release,),preexec_fn=session)
    try:
        output=b'';record=b'';deadline=time.monotonic()+timeout
        # Source tcsetattr(.FLUSH) waits for prior output: drain the master
        # while waiting for the child's completion record.
        while not record.endswith(b'\n'):
            if time.monotonic()>=deadline:raise AssertionError('PTY stdout timeout')
            ready=select.select([process.stdout,master],[],[],min(0.1,deadline-time.monotonic()))[0]
            if master in ready:output+=os.read(master,4096)
            if process.stdout in ready:
                chunk=os.read(process.stdout.fileno(),4096)
                if not chunk:raise AssertionError('PTY consumer exited before record')
                record+=chunk
        deadline=time.monotonic()+0.1
        while time.monotonic()<deadline:
            if select.select([master],[],[],0.01)[0]:output+=os.read(master,4096)
        current=termios.tcgetattr(slave)
        restored=current==original
        os.write(send,b'x');os.close(master);master=-1;os.close(slave);slave=-1
        tail,error=process.communicate(timeout=timeout)
        if root is not None:
            stem=root/f'{label}-{count}-{int(mutate)}-{rows}-{cols}'
            stem.with_suffix('.stdout').write_bytes(record+tail)
            stem.with_suffix('.stderr').write_bytes(error)
            stem.with_suffix('.tty').write_bytes(output)
            def attrs(state):return [*state[:6],[byte if isinstance(byte,int) else byte[0] for byte in state[6]]]
            stem.with_suffix('.termios.json').write_text(json.dumps({'before':attrs(original),'after':attrs(current),'restored':restored}))
        expected=f'1|{int(count>0)}|{count}|{rows}|{cols}|32|48\n'.encode()
        if process.returncode or error or record+tail!=expected or output!=b'D'*count or restored!=(count>0):
            raise AssertionError((case,process.returncode,record+tail,error,output,restored))
        return record+output
    finally:
        for fd in [master,slave,release,send]:
            if fd>=0:os.close(fd)
        if process.poll() is None:process.kill();process.wait(timeout=5)


def verify(args,root):
    source=args.source.resolve()/'src'
    if tree_hash(source)!=VAXIS_SHA256:raise ValueError('Vaxis source differs from pinned tree')
    shutil.copytree(source,root/'src');graph=prepare_uucode(args.zig.resolve(),root,args.uucode.resolve())
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    fixtures={name:hashlib.sha256((PROBE/name).read_bytes()).hexdigest() for name in ('reference.zig','main.v')}
    metadata={'source_sha256':VAXIS_SHA256,'uucode_sha256':UUCODE_SHA256,'fixtures':fixtures,'source_mode':mode,'v_mode':'production' if args.v_prod else 'ordinary','target':'aarch64-macos.14.0','source_writer_buffer_size':0}
    (root/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
    native=[str(args.zig.resolve()),'build-exe','-O',mode,'-target','aarch64-macos.14.0','-lc',*module('root',PROBE/'reference.zig',['vaxis']),*module('vaxis',root/'src/main.zig',['uucode']),*graph,f'-femit-bin={root}/native']
    translated=[str(args.v.resolve()),*(['-prod'] if args.v_prod else []),'-path',f'{REPO}|@vlib|@vmodules','-o',str(root/'translated'),str(PROBE/'main.v')]
    environment=dict(os.environ,VEXE=str(args.v.resolve()),V_C_ERROR_BUG_REPORT_DISABLED='1')
    for label,argv in [('native',native),('translated',translated)]:
        print(f'Building {label} ({mode})',file=sys.stderr,flush=True);(root/f'{label}-argv.json').write_text(json.dumps(argv));subprocess.run(argv,env=environment,check=True)
    records=[]
    cases=list(itertools.product([0,1,2,3,8],[False,True],[4,24],[8,80]))
    for case in cases:
        expected=run_pty(root/'native',case,environment,args.timeout,root,'native');actual=run_pty(root/'translated',case,environment,args.timeout,root,'translated')
        if expected!=actual:raise AssertionError((case,expected,actual))
        records.append('|'.join(map(str,case)).encode()+b'|'+expected)
    if tree_hash(source)!=VAXIS_SHA256 or tree_hash(root/'src')!=VAXIS_SHA256:raise AssertionError('Source tree changed during comparison')
    if tree_hash(args.uucode.resolve())!=UUCODE_SHA256 or tree_hash(root/'uucode')!=UUCODE_SHA256:raise AssertionError('uucode tree changed during comparison')
    if any(hashlib.sha256((PROBE/name).read_bytes()).hexdigest()!=value for name,value in fixtures.items()):raise AssertionError('fixture changed during comparison')
    data=b'\n'.join(records);(root/'returning.txt').write_bytes(data)
    print(f'Tty.deinit ({mode}): {len(cases)} public macOS PTY records, SHA256 {hashlib.sha256(data).hexdigest()}')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--uucode',type=Path,default=Path.home()/'.cache/zig/p'/UUCODE_PACKAGE)
    parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=float,default=15)
    args=parser.parse_args();resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    if args.workdir:
        args.workdir.mkdir(parents=True,exist_ok=False);verify(args,args.workdir.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix='witty-tty-deinit-') as directory:verify(args,Path(directory))
if __name__=='__main__':main()
