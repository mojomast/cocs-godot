#!/usr/bin/env python3
"""Bounded graphical acceptance on a newly owned, authenticated Xvfb display."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import secrets
import select
import shutil
import signal
import resource
import socket
import struct
import subprocess
import tempfile
import threading
import time

from x11 import X11

ROOT = Path(__file__).resolve().parents[3]
TOOLS = Path(__file__).resolve().parent


def now(): return time.time_ns() / 1_000_000
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def lines(path):
    if not path.exists(): return []
    return [json.loads(s) for s in path.read_text().splitlines() if s.strip()]
def neutral(c):
    return c['x'] == 0 and c['z'] == 0 and not any(c.get(k) for k in ['fire','jump','reload','sprint','crouch','interact','mobility'])


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',required=True,help='Read-only source checkout with node_modules')
    p.add_argument('--godot',required=True)
    p.add_argument('--output',required=True,help='New evidence directory; existing history is never overwritten')
    args=p.parse_args()
    out=Path(args.output).resolve(); out.mkdir(parents=True,exist_ok=False)
    source=Path(args.source).resolve(); binary=Path(args.godot).resolve()
    runtime=Path(tempfile.mkdtemp(prefix='graphical-private-',dir='/tmp/opencode'))
    env=os.environ.copy()
    for key in ['DISPLAY','WAYLAND_DISPLAY','XAUTHORITY','DBUS_SESSION_BUS_ADDRESS']:
        env.pop(key,None)
    for key,folder in [('HOME','home'),('XDG_CONFIG_HOME','config'),('XDG_DATA_HOME','data'),('XDG_CACHE_HOME','cache'),('XDG_RUNTIME_DIR','xdg'),('TMPDIR','tmp')]:
        d=runtime/folder; d.mkdir(mode=0o700); env[key]=str(d)
    env.update({'LIBGL_ALWAYS_SOFTWARE':'1','XDG_SESSION_TYPE':'x11'})
    children=[]; streams=[]; x=None; port=None; display=None; reader=None
    trace=[]; checks=[]; stages=[]; current='startup'; deadline=time.monotonic()+85
    report={'schema':1,'harnessStarted_ms':now(),'completionProven':False,
            'nativeTerminalMarker':None,'status':'running','runtime':str(runtime),
            'baseCommit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            'sourceCheckout':str(source),'godot':str(binary),'checks':checks,'stages':stages}

    def interrupted(signum,_frame): raise InterruptedError(f'Harness signal {signum}')
    for signum in [signal.SIGINT,signal.SIGTERM]: signal.signal(signum,interrupted)
    def bounded_files(): resource.setrlimit(resource.RLIMIT_FSIZE,(8_000_000,8_000_000))

    def save(): (out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
    def event(kind,**data):
        with (out/'actions.jsonl').open('a') as f: f.write(json.dumps({'at_ms':now(),'event':kind,**data})+'\n')
    def check(name,passed,**data):
        checks.append({'name':name,'passed':bool(passed),**data})
        if not passed: raise AssertionError(name)
    def guard():
        if time.monotonic()>deadline: raise TimeoutError('85-second harness deadline')
        for name,proc in children:
            if proc.poll() is not None: raise RuntimeError(f'{name} exited early: {proc.returncode}')
        if any(f.stat().st_size>8_000_000 for f in out.iterdir() if f.is_file()):
            raise RuntimeError('Evidence file exceeded 8 MB cap')
    def wait(seconds):
        until=time.monotonic()+seconds
        while time.monotonic()<until:
            guard(); time.sleep(.02)
    def until(fn,seconds=15):
        end=time.monotonic()+seconds
        while time.monotonic()<end:
            guard()
            if fn(): return
            time.sleep(.03)
        raise TimeoutError('Condition deadline')
    def launch(name,cmd,pipe=False):
        dest=subprocess.PIPE if pipe else (out/f'{name}.log').open('w')
        if not pipe: streams.append(dest)
        proc=subprocess.Popen(cmd,cwd=ROOT,env=env,stdout=dest,stderr=subprocess.STDOUT,text=True,preexec_fn=bounded_files)
        children.append((name,proc)); event('child_start',name=name,pid=proc.pid,command=cmd)
        return proc
    def phase(name,seconds=.5,capture=False):
        nonlocal current
        current=name; start=now(); event('stage_start',name=name)
        wait(seconds)
        os_state=x.state()
        if capture: x.screenshot(out/f'{name}.png')
        end=now()
        snaps=[r for r in trace if r['event']=='snapshot' and r['received_ms']>start+100]
        inputs=[r for r in trace if r['event']=='input_queue' and r['received_ms']>start+100]
        wire=[r for r in lines(out/'wire.jsonl') if r['event']=='input' and start+100<r['at_ms']<=end]
        stage={'name':name,'start_ms':start,'end_ms':end,'os':os_state,
               'snapshots':len(snaps),'native_inputs':len(inputs),'wire_inputs':len(wire),
               'native_sequence_range':[inputs[0]['sequence'],inputs[-1]['sequence']] if inputs else [],
               'wire_seq_range':[wire[0]['seq'],wire[-1]['seq']] if wire else []}
        stages.append(stage); event('stage_end',**stage)
        check(name+': live alive snapshots and wire',bool(snaps and inputs and wire) and all(s['lifecycle']=='alive' and s['phase']==3 for s in snaps))
        check(name+': queue succeeded',all(i['queued'] for i in inputs))
        save()
        return snaps,inputs,wire,os_state
    def is_neutral(name,rows):
        snaps,inputs,wire,state=rows
        check(name+': neutral native and server',all(neutral(r['controls']) for r in inputs+wire))
        check(name+': pointer program state released',all(not r['pointer_captured'] for r in snaps))
    def grab(name,state,expected):
        check(name+': competing XGrabPointer',state['competing_grab_status']==expected,observed=state)
    def inject(kind,*values):
        event('XTest' if kind!='focus' else 'XSetInputFocus',operation=kind,values=values)
        getattr(x,kind)(*values)

    try:
        save(); event('harness_start',completionProven=False)
        version=subprocess.check_output([str(binary),'--version'],env=env,text=True,timeout=5).strip()
        check('pinned Godot version',version=='4.5.2.stable.official.6ce3de25a',version=version)
        # Source server/dependency provenance and protection against a moving primary checkout.
        tracked=subprocess.check_output(['git','ls-files','game','server','package.json','package-lock.json'],cwd=ROOT,text=True).splitlines()
        check('read-only server checkout matches worktree',all(sha(ROOT/f)==sha(source/f) for f in tracked))
        hashes={f:sha(ROOT/f) for f in ['godot/world/session.gd','godot/world/viewer.gd','godot/net/client.gd','port/contracts/source-lock.json','package-lock.json']}
        report['provenance']={'files':hashes,'binary_sha256':sha(binary),'version':version,
                              'tools':{f.name:sha(f) for f in TOOLS.iterdir() if f.suffix in ['.py','.mjs']}}
        project=runtime/'godot'
        shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot','generated','probes'))
        with (out/'prepare.log').open('w') as log:
            subprocess.run(['node','tools/godot-export/semantic.mjs',str(project/'content/generated')],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=15)
            subprocess.run([str(binary),'--headless','--editor','--path',str(project),'--import'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=30)
        # Xvfb chooses a free display atomically; authentication cookie never enters evidence.
        auth=runtime/'Xauthority'; cookie=secrets.token_bytes(16)
        def authority(number):
            fields=[b'',number.encode(),b'MIT-MAGIC-COOKIE-1',cookie]
            auth.write_bytes(struct.pack('!H',65535)+b''.join(struct.pack('!H',len(f))+f for f in fields)); auth.chmod(0o600)
        authority(''); env['XAUTHORITY']=str(auth)
        r,w=os.pipe()
        logfile=(out/'xvfb.log').open('w'); streams.append(logfile)
        xvfb_command=['Xvfb','-displayfd',str(w),'-screen','0','1600x1000x24','-nolisten','tcp','-nolisten','unix','-auth',str(auth)]
        xvfb=subprocess.Popen(xvfb_command,env=env,pass_fds=(w,),stdout=logfile,stderr=subprocess.STDOUT,preexec_fn=bounded_files)
        event('child_start',name='xvfb',pid=xvfb.pid,command=xvfb_command)
        children.append(('xvfb',xvfb)); os.close(w)
        if not select.select([r],[],[],5)[0]: raise TimeoutError('Xvfb display allocation')
        number=os.read(r,64).decode().strip(); os.close(r)
        if not number.isdigit(): raise RuntimeError('Invalid Xvfb display number')
        display=':'+number; authority(number); env['DISPLAY']=display
        # XOpenDisplay reads the auth path from this process's environment too.
        os.environ['XAUTHORITY']=str(auth)
        x=X11(display); report['display']={'name':display,'pid':xvfb.pid,'tcp':False,'authenticated':True,'sink':x.sink}
        event('private_display_start',**report['display'])
        server=launch('server',['node',str(TOOLS/'server.mjs'),str(source),str(out)])
        until(lambda:(out/'server-ready.json').exists(),8)
        ready=json.loads((out/'server-ready.json').read_text()); port=ready['port']; report['server']=ready
        godot=launch('godot',[str(binary),'--display-driver','x11','--audio-driver','Dummy','--path',str(project),
                            '--resolution','1100x700','--position','20,20','res://world/session.tscn','--',f'--endpoint=ws://127.0.0.1:{port}','--native-trace'],pipe=True)
        def consume():
            with (out/'native.jsonl').open('w') as native,(out/'godot.log').open('w') as log:
                total=0
                for line in godot.stdout:
                    total+=len(line)
                    if total>8_000_000:
                        godot.terminate(); return
                    if line.startswith('PORT_NATIVE_TRACE '):
                        value=json.loads(line[len('PORT_NATIVE_TRACE '):]); value['received_ms']=now()
                        trace.append(value); native.write(json.dumps(value)+'\n'); native.flush()
                    else: log.write(line); log.flush()
        reader=threading.Thread(target=consume,daemon=True); reader.start()
        until(lambda:any('Port Laboratory' in name for _,name in x.windows()))
        window=next(w for w,name in x.windows() if 'Port Laboratory' in name)
        report['display']['godot_window']=window
        inject('focus',window); inject('motion',500,400)
        until(lambda:any(r.get('lifecycle')=='alive' for r in trace))
        inject('key','w',True)
        initial=phase('01_before_click',capture=True); is_neutral('before click',initial); grab('before click',initial[3],0)
        inject('button',True); wait(.08); inject('button',False)
        captured=phase('02_clicked_capture',capture=True)
        check('click captures native',all(s['pointer_captured'] for s in captured[0])); grab('click captures OS',captured[3],1)
        check('W reaches server',any(not neutral(r['controls']) for r in captured[2]))
        inject('key','w',False)
        for key in ['a','s','d']:
            inject('key',key,True); rows=phase('move_'+key,.3)
            check(key+' reaches native and server',all(any(abs(r['controls']['x'])+abs(r['controls']['z'])>.5 for r in group) for group in [rows[1],rows[2]]))
            inject('key',key,False)
        yaw_before=captured[0][-1]['yaw']
        inject('motion',40,8,True); look=phase('03_captured_look',.35)
        check('captured actual mouse look changes yaw',abs(look[0][-1]['yaw']-yaw_before)>.02)
        inject('motion',1400,180); wait(.1); confined=x.state()
        event('pointer_confinement_attempt',target=[1400,180],observed=confined)
        check('captured pointer cannot reach outside target',confined['pointer_root'][0]<1120)
        inject('key','w',True); inject('button',True)
        fire=phase('04_fire',.45,capture=True)
        check('fire reaches native and server',all(any(r['controls']['fire'] for r in group) for group in [fire[1],fire[2]]))
        inject('key','Escape',True); inject('key','Escape',False); wait(.08); inject('button',False)
        escaped=phase('05_escape_release',capture=True); is_neutral('Escape',escaped); grab('Escape OS released',escaped[3],0)
        inject('motion',1400,180); wait(.08)
        escaped_pointer=x.state(); event('pointer_escape_attempt',target=[1400,180],observed=escaped_pointer)
        check('released pointer reaches outside window',escaped_pointer['pointer_root']==[1400,180])
        inject('motion',500,400)
        still=phase('06_escape_held_key_no_click',.35); is_neutral('Escape held W',still)
        inject('button',True); wait(.08); inject('button',False)
        again=phase('07_recaptured',.35); grab('recaptured OS',again[3],1)
        inject('key','d',True); inject('button',True)
        before_loss=phase('08_held_before_focus_loss',.3)
        focus_out_at=now()
        inject('focus',x.sink)
        event('focus_out_os_immediate',observed=x.state())
        wait(.06)
        inject('motion',40,8,True)
        event('focus_out_os_after_motion',observed=x.state())
        until(lambda:any(r['event']=='snapshot' and r['received_ms']>focus_out_at and not r['focused'] and not r['pointer_captured'] for r in trace),1)
        transition=[r for r in trace if r['received_ms']>focus_out_at]
        first_released=next(r for r in transition if r['event']=='snapshot' and not r['focused'] and not r['pointer_captured'])
        report['focusOutReleaseReceiptLatency_ms']=first_released['received_ms']-focus_out_at
        report['focusTransitionLook']={'before':[before_loss[0][-1]['yaw'],before_loss[0][-1]['pitch']],
            'settled':[first_released['yaw'],first_released['pitch']],
            'motionInjectedAfter_ms':60,
            'unchanged':first_released['yaw']==before_loss[0][-1]['yaw'] and first_released['pitch']==before_loss[0][-1]['pitch']}
        transition_wire=[r for r in lines(out/'wire.jsonl') if r['event']=='input' and r['at_ms']>focus_out_at+100]
        report['focusTransitionLook']['wireAimObserved']=any(abs(r['controls']['yaw']-first_released['yaw'])<1e-6 and abs(r['controls']['pitch']-first_released['pitch'])<1e-6 for r in transition_wire)
        event('focus_out_settled',latency_ms=report['focusOutReleaseReceiptLatency_ms'])
        check('focus transition controls neutral after 100ms',all(neutral(r['controls']) for r in transition if r['event']=='input_queue' and r['received_ms']>focus_out_at+100))
        check('focus transition wire controls neutral after 100ms',bool(transition_wire) and all(neutral(r['controls']) for r in transition_wire))
        lost=phase('09_focus_lost_held',.4,capture=True); is_neutral('focus loss held W D fire',lost)
        check('OS focus sink and program focus false',lost[3]['focus']==x.sink and all(not s['focused'] and not s['control_eligible'] for s in lost[0]))
        yaw_lost=lost[0][-1]['yaw']; pitch_lost=lost[0][-1]['pitch']
        inject('motion',1400,180)
        gated=phase('10_focus_lost_motion',.35)
        is_neutral('unfocused motion',gated); grab('focus loss OS release with fire held',gated[3],0)
        check('unfocused pointer crosses boundary',gated[3]['pointer_root']==[1400,180])
        check('unfocused look gated',all(s['yaw']==yaw_lost and s['pitch']==pitch_lost for s in gated[0]))
        focus_in_at=now()
        inject('focus',window); inject('motion',500,400)
        until(lambda:any(r['event']=='snapshot' and r['received_ms']>focus_in_at and r['focused'] for r in trace),1)
        returned=phase('11_focus_return_held_no_click',.5,capture=True); is_neutral('focus return held controls',returned)
        grab('focus return does not recapture OS',returned[3],0)
        check('held W D physically present on focus return',returned[3]['keys_down']==['w','d'])
        check('fire physically held across focus loss and return',returned[3]['button1_down'])
        check('return eligible and focused but look unchanged',all(s['focused'] and s['control_eligible'] and s['yaw']==yaw_lost and s['pitch']==pitch_lost for s in returned[0]))
        inject('button',False); inject('button',True)
        fresh=phase('12_fresh_click_reactivation',.4,capture=True)
        check('fresh click restores capture and fire',all(s['pointer_captured'] for s in fresh[0]) and any(r['controls']['fire'] for r in fresh[2]))
        inject('button',False); inject('key','w',False); inject('key','d',False)
        inject('key','w',True); resumed=phase('13_fresh_movement',.35)
        check('fresh movement after recapture reaches wire',any(not neutral(r['controls']) for r in resumed[2]))
        grab('final captured OS with button up',resumed[3],1)
        inject('key','w',False)
        wire_snaps=[r for r in lines(out/'wire.jsonl') if r['event']=='snapshot' and r['actor']]
        check('source authoritative shots increased',max(s['actor'].get('shots',0) for s in wire_snaps)>0)
        first=wire_snaps[0]['actor']; moved=max(((s['actor']['x']-first['x'])**2+(s['actor']['z']-first['z'])**2)**.5 for s in wire_snaps)
        check('source authoritative movement > 0.5m',moved>.5,metres=moved)
        check('ACK advanced',max(s.get('ack',0) for s in wire_snaps)>20)
        check('mouse look gated during OS focus notification delay',report['focusTransitionLook']['unchanged'])
        report['status']='passed'
    except Exception as error:
        report['status']='failed'; report['failure']={'stage':current,'type':type(error).__name__,'message':str(error)}
        event('harness_failure',**report['failure'])
    finally:
        event('harness_termination_requested',reason=report['status'],completionProven=False)
        # Stop only direct owned child handles, with bounded escalation and wait/reap.
        cleanup=[]
        if x:
            for key in ['w','a','s','d','Escape']: x.key(key,False)
            x.button(False)
        for name,proc in reversed(children):
            if name=='xvfb' and x:
                x.close(); x=None
            requested=proc.poll() is None
            if requested: proc.terminate()
            try: proc.wait(timeout=4)
            except subprocess.TimeoutExpired: proc.kill(); proc.wait(timeout=3)
            cleanup.append({'name':name,'pid':proc.pid,'termination_requested':requested,'returncode':proc.returncode,'proc_absent':not Path(f'/proc/{proc.pid}').exists()})
        if reader: reader.join(timeout=2)
        for stream in streams: stream.close()
        port_absent=True
        if port:
            with socket.socket() as s:
                s.settimeout(.4); port_absent=s.connect_ex(('127.0.0.1',port))!=0
        socket_absent=not Path(f'/tmp/.X11-unix/X{display[1:]}').exists() if display else True
        abstract_absent=True
        if display:
            with socket.socket(socket.AF_UNIX) as s:
                s.settimeout(.4)
                abstract_absent=s.connect_ex('\0/tmp/.X11-unix/X'+display[1:])!=0
        report['cleanup']={'children':cleanup,'server_port_absent':port_absent,'display_socket_absent':socket_absent,'abstract_display_socket_absent':abstract_absent}
        if not all(c['proc_absent'] for c in cleanup) or not port_absent or not socket_absent or not abstract_absent:
            report['status']='failed'; report['cleanup']['failed']=True
        errors=(out/'godot.log').read_text() if (out/'godot.log').exists() else ''
        if 'SCRIPT ERROR' in errors or '\nERROR:' in errors:
            report['status']='failed'; report['engineError']=True
        report['harnessTerminated_ms']=now()
        event('harness_terminated',cleanup=report['cleanup'],completionProven=False)
        # Lossless compact evidence: one copy of each stream, no bulky raw duplication.
        for path in out.iterdir():
            if path.suffix in ['.jsonl','.log'] and path.stat().st_size>16000:
                with path.open('rb') as src, gzip.open(str(path)+'.gz','wb') as dst: shutil.copyfileobj(src,dst)
                path.unlink()
        save()
        shutil.rmtree(runtime)
    print(json.dumps({'status':report['status'],'checks':len(checks),'completionProven':False,'evidence':str(out),'failure':report.get('failure')}))
    return 0 if report['status']=='passed' else 1


if __name__=='__main__': raise SystemExit(main())
