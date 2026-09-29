#!/usr/bin/env python3
"""Isolated 3-native-client Room-wire acceptance; invoke ONLY with heavy-slot grant.

Copies source, uses unchanged default-rate GameServer, three independent Godot
processes and physical-event SceneTree scripts. The source-only oracle is
reported separately, never substituted for real multiplayer acceptance.
"""
import gzip
import hashlib
import json
import os
import pathlib
import selectors
import shutil
import subprocess
import tempfile
import time
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[2]
BIN = os.environ.get('GODOT_BIN', '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64')
DEPS = os.environ.get('GUEST_NODE_MODULES', '/home/mojo/.tmp-on-disk/cocs-arsenal-verify-20260928/node_modules')
OUT = pathlib.Path(os.environ.get('VEHICLE_EVIDENCE_ROOT','/tmp/opencode/native-vehicle-expansion'))/str(uuid.uuid4())
OUT.mkdir(parents=True)
children = []
began=time.monotonic()
report = {'evidence':str(OUT), 'classification':'3 distinct native clients, real Room wire; no authority position writes', 'stepsSeconds':{}}

def private_environment(directory, inherited):
    """No ambient credentials, existing career, display, or settings escape in."""
    env={key:value for key,value in inherited.items() if not any(word in key.upper()
         for word in ('SECRET','TOKEN','PASSWORD','CREDENTIAL','API_KEY','AUTH'))}
    for key in ['DISPLAY','WAYLAND_DISPLAY','WAYLAND_SOCKET','DBUS_SESSION_BUS_ADDRESS','SESSION_MANAGER']:
        env.pop(key,None)
    for key,leaf in [('HOME','home'),('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),
                     ('XDG_CACHE_HOME','cache'),('XDG_RUNTIME_DIR','runtime'),('TMPDIR','tmp')]:
        place=directory/leaf; place.mkdir(parents=True,exist_ok=True,mode=0o700)
        env[key]=str(place)
    career=directory/'career'; career.mkdir(parents=True,exist_ok=True,mode=0o700)
    env.update({'COCS_CAREER_ROOT':str(career),'COCS_SETTINGS_PATH':str(directory/'settings.json'),
        'COCS_CAREER_CREDENTIALS_PATH':'','COCS_CAREER_SCOPE':'','COCS_CAREER_ENDPOINT':'',
        'COCS_SOURCE_DERIVATIVE':str(ROOT/'port/contracts/lattice-catalog-derivative.json')})
    return env

def stop(p):
    if p.poll() is None:
        p.terminate()
        try: p.wait(8)
        except subprocess.TimeoutExpired: p.kill(); p.wait(5)
    try: os.kill(p.pid,0)
    except ProcessLookupError: return
    raise AssertionError(f'owned process remains: {p.pid}')

def run(args, name, env, timeout=90):
    started=time.monotonic()
    with (OUT/(name+'.log')).open('w') as file:
        child=subprocess.Popen(args,stdout=file,stderr=subprocess.STDOUT,env=env)
        children.append(child)
        try: code=child.wait(timeout)
        finally:
            stop(child)
            report['stepsSeconds'][name]=round(time.monotonic()-started,2)
    text=(OUT/(name+'.log')).read_text()
    assert code==0 and 'SCRIPT ERROR' not in text and 'ERROR:' not in text, f'{name} failed; inspect retained log'
    return text

def next_line(stream, seconds=20):
    with selectors.DefaultSelector() as selector:
        selector.register(stream,selectors.EVENT_READ)
        assert selector.select(seconds), 'server announcement timeout'
        result=stream.readline().strip()
        assert result, 'server ended without announcement'
        return result

def hashes(root, names):
    return {str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest()
            for name in names for f in sorted((root/name).rglob('*')) if f.is_file() and '.godot' not in f.parts}

try:
    assert subprocess.check_output([BIN,'--version'],text=True).strip()=='4.5.2.stable.official.6ce3de25a'
    assert pathlib.Path(DEPS).is_dir(), 'Approved ignored node_modules unavailable'
    derivative=ROOT/'port/contracts/lattice-catalog-derivative.json'
    assert derivative.is_file(), 'Explicit approved semantic derivative missing'
    with tempfile.TemporaryDirectory(prefix='vehicle-native-',dir='/tmp/opencode') as tmp:
        temp=pathlib.Path(tmp)
        env=private_environment(temp/'tools',os.environ)
        copying=time.monotonic()
        for name in ['godot','game','server']:
            shutil.copytree(ROOT/name,temp/name,ignore=shutil.ignore_patterns('.godot','node_modules'))
        report['stepsSeconds']['copy']=round(time.monotonic()-copying,2)
        (temp/'node_modules').symlink_to(DEPS,target_is_directory=True)
        source_hashes=hashes(temp,['game','server'])
        assert source_hashes==hashes(ROOT,['game','server']), 'copy changed source'
        run(['node',str(ROOT/'tools/godot-export/semantic.mjs'),str(temp/'godot/content/generated')], 'export',env)
        (OUT/'hashes.json').write_text(json.dumps({'source':source_hashes,
            'native':hashes(temp,['godot/combined_arms','godot/vehicles','godot/tests/combined_arms'])},indent=2)+'\n')
        run([BIN,'--headless','--path',str(temp/'godot'),'--editor','--import'],'import',env,90)
        for script in ['combined_arms/demo.gd','vehicles/session_bridge.gd',
                       'tests/combined_arms/observe_crew_host.gd','tests/combined_arms/observe_crew_guest.gd',
                       'tests/combined_arms/observe_crew_passenger.gd']:
            run([BIN,'--headless','--path',str(temp/'godot'),'--check-only','--script','res://'+script],
                'parse-'+pathlib.Path(script).stem,env,30)
        run([BIN,'--headless','--path',str(temp/'godot'),'--script','res://tests/combined_arms/test_controls.gd'], 'controls',env,30)
        run([BIN,'--headless','--path',str(temp/'godot'),'--script','res://tests/combined_arms/test_fleet_visuals.gd'], 'fleet',env,30)
        run([BIN,'--headless','--path',str(temp/'godot'),'--script','res://tests/combined_arms/test_shared_shots.gd'], 'shared-shots',env,30)
        oracle=run(['node',str(ROOT/'port/native-vehicle-expansion/source-oracle.mjs')],'source-oracle',env,120)
        assert 'VEHICLE_SOURCE_ORACLE ' in oracle, 'arranged direct-Match fixture missing'
        edge_oracle=run(['node',str(ROOT/'port/native-vehicle-expansion/room-edge-oracle.mjs')],'room-edge-oracle',env,120)
        assert 'VEHICLE_ROOM_EDGE_ORACLE ' in edge_oracle, 'arranged direct-Room edge fixture missing'
        live_started=time.monotonic()
        r,w=os.pipe()
        with (OUT/'xvfb.log').open('w') as log:
            xvfb=subprocess.Popen(['Xvfb','-displayfd',str(w),'-screen','0','1600x900x24','-nolisten','tcp','-nolisten','unix'],pass_fds=(w,),stdout=log,stderr=log)
            children.append(xvfb); os.close(w)
            with os.fdopen(r) as stream: display=next_line(stream,10)
            assert display.isdigit() and xvfb.poll() is None
            env['DISPLAY']=':'+display
            host_env=private_environment(temp/'host',env)
            guest_env=private_environment(temp/'guest',env)
            passenger_env=private_environment(temp/'passenger',env)
            for private in (host_env,guest_env,passenger_env): private['DISPLAY']=env['DISPLAY']
            with (OUT/'server.log').open('w') as server_log:
                server=subprocess.Popen(['node',str(ROOT/'port/native-vehicle-expansion/server.mjs'),tmp,str(OUT/'wire.json')],
                    stdout=subprocess.PIPE,stderr=server_log,text=True,env=env)
                children.append(server)
                try:
                    first=next_line(server.stdout,15)
                    assert first.startswith('ENDPOINT ws://127.0.0.1:'),first
                    endpoint=first.split(' ',1)[1]
                    command=[BIN,'--path',str(temp/'godot'),'--rendering-method','gl_compatibility',
                        '--audio-driver','Dummy','--resolution','800x680']
                    with (OUT/'host.log').open('w') as host_log, (OUT/'guest.log').open('w') as guest_log, (OUT/'passenger.log').open('w') as passenger_log:
                        host=subprocess.Popen(command+['--script','res://tests/combined_arms/observe_crew_host.gd','--',
                            '--map=sunscar-convoy','--endpoint='+endpoint,'--wait-for-players=3'],
                            stdout=host_log,stderr=subprocess.STDOUT,env=host_env)
                        children.append(host)
                        room=next_line(server.stdout,30)
                        assert room.startswith('ROOM ') and len(room)>5,room
                        guest=subprocess.Popen(command+['--script','res://tests/combined_arms/observe_crew_guest.gd','--',
                            '--map=sunscar-convoy','--endpoint='+endpoint,'--wait-for-players=3','--join-room='+room[5:]],
                            stdout=guest_log,stderr=subprocess.STDOUT,env=guest_env)
                        children.append(guest)
                        assert next_line(server.stdout,30)=='GUEST_SEATED 2', 'guest must be actor 1 before passenger joins'
                        passenger=subprocess.Popen(command+['--script','res://tests/combined_arms/observe_crew_passenger.gd','--',
                            '--map=sunscar-convoy','--endpoint='+endpoint,'--wait-for-players=3','--join-room='+room[5:]],
                            stdout=passenger_log,stderr=subprocess.STDOUT,env=passenger_env)
                        children.append(passenger)
                        try:
                            guest_code=guest.wait(210); passenger_code=passenger.wait(20); host_code=host.wait(20)
                        finally: stop(passenger); stop(guest); stop(host)
                    for role,code in [('host',host_code),('guest',guest_code),('passenger',passenger_code)]:
                        text=(OUT/(role+'.log')).read_text()
                        assert code==0 and 'SCRIPT ERROR' not in text and 'ERROR:' not in text,role+' native process failed'
                finally: stop(server)
            stop(xvfb)
        report['stepsSeconds']['three_native_live']=round(time.monotonic()-live_started,2)
        assert source_hashes==hashes(temp,['game','server']), 'executed source changed'
        assert source_hashes==hashes(ROOT,['game','server']), 'original source changed'
        from validate import verify
        report['live']=verify({role:(OUT/(role+'.log')).read_text() for role in ['host','guest','passenger']},json.loads((OUT/'wire.json').read_text()))
    report['privateTempRemoved']=not temp.exists()
    report['status']='PASS'
except Exception as exc:
    report['status']='FAIL'; report['error']=str(exc)
    raise
finally:
    cleanup=[]
    for child in reversed(children):
        try: stop(child)
        except Exception as exc: cleanup.append(str(exc))
    report['ownedProcessesReaped']=not cleanup
    if cleanup:
        report['status']='FAIL'
        report['cleanupErrors']=cleanup
    report['elapsedSeconds']=round(time.monotonic()-began,2)
    raw=OUT/'wire.json'
    if raw.exists():
        with raw.open('rb') as src, gzip.open(OUT/'wire.json.gz','wb',compresslevel=6) as dst:
            shutil.copyfileobj(src,dst)
        raw.unlink()
    report['retainedFiles']={f.name:{'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}
        for f in sorted(OUT.iterdir()) if f.is_file() and f.name!='summary.json'}
    (OUT/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    if cleanup: raise AssertionError('Owned processes survived cleanup; inspect summary')
