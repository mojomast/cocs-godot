"""Fresh checks; never writes the earlier independent review evidence."""
import json, os, pathlib, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[3]
OUT = pathlib.Path(__file__).resolve().parent
GODOT = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
checks=[]
with tempfile.TemporaryDirectory(prefix='lobby-followup-checks-',dir='/tmp/opencode') as tmp:
    env=dict(os.environ,HOME=tmp,LIBGL_ALWAYS_SOFTWARE='1')
    for key in ['XDG_RUNTIME_DIR','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
        env[key]=tmp+'/'+key;pathlib.Path(env[key]).mkdir(mode=0o700)
    def run(name,args):
        command=[GODOT,'--path','godot','--audio-driver','Dummy',*args]
        p=subprocess.run(command,cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=40)
        (OUT/(name+'.log')).write_bytes(p.stdout)
        checks.append(dict(name=name,command=command,exit=p.returncode))
        print(name,p.returncode,flush=True)
    for name in ['lobby_flow','control_safety','window_focus','stall_controls','session_recovery','round_boundaries','local_lifecycle','guest_session','input_queue','envelopes','game_hud_session','scoreboard','scoreboard_session']:
        run(name,['--headless','--script','res://tests/protocol/'+name+'.gd'])
    for name,flag in [('hud-setup','--setup'),('hud-debug','--debug-hud')]:
        run(name,['--headless','--script','res://tests/protocol/game_hud_session.gd','--',flag])
    read,write=os.pipe()
    display=subprocess.Popen(['Xvfb','-displayfd',str(write),'-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],pass_fds=[write],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
    os.close(write)
    try:
        with os.fdopen(read) as pipe: env['DISPLAY']=':'+pipe.readline().strip()
        for size in ['960x640','1280x800']:
            run('geometry-'+size,['--resolution',size,'--script','res://tests/protocol/lobby_followup_geometry.gd','--','--lobby-menu'])
        run('weapon_selection',['--script','res://tests/protocol/weapon_selection.gd'])
    finally:
        display.terminate();display.communicate(timeout=5)
    cleanup={'displayPid':display.pid,'displayReaped':not pathlib.Path('/proc/'+str(display.pid)).exists()}
cleanup['tempRemoved']=not pathlib.Path(tmp).exists()
(OUT/'checks.json').write_text(json.dumps({'checks':checks,'cleanup':cleanup},indent=2)+'\n')
raise SystemExit(any(c['exit'] for c in checks))
