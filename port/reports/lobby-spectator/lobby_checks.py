"""Private spectator regression execution; previous evidence remains immutable."""
import json,os,pathlib,subprocess,tempfile,sys
ROOT=pathlib.Path(__file__).resolve().parents[3]
OUT=pathlib.Path(__file__).resolve().parent
GODOT='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
old='--old-context' in sys.argv
checks=[]
with tempfile.TemporaryDirectory(prefix='lobby-spectator-checks-',dir='/tmp/opencode') as tmp:
    env=dict(os.environ,HOME=tmp,LIBGL_ALWAYS_SOFTWARE='1')
    for k in ['XDG_RUNTIME_DIR','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
        env[k]=tmp+'/'+k;pathlib.Path(env[k]).mkdir(mode=0o700)
    def run(name,script,extra=None,headless=True):
        args=[GODOT,'--path','godot','--audio-driver','Dummy']+(['--headless'] if headless else [])+['--script','res://tests/'+script+'.gd']+(extra or [])
        try:
            p=subprocess.run(args,cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=45)
            output,code=p.stdout,p.returncode
        except subprocess.TimeoutExpired as error:
            output,code=(error.stdout or b'')+b'\nOWNED PROCESS TIMEOUT: killed/reaped by subprocess.run\n',124
        (OUT/(name+'.log')).write_bytes(output)
        checks.append(dict(name=name,command=args,exit=code));print(name,code,flush=True)
    run('context-old' if old else 'context-new','protocol/lobby_spectator_context')
    if not old:
        for name in ['lobby_flow','envelopes','replay','input_queue','control_safety','window_focus','stall_controls','session_recovery','round_boundaries','local_lifecycle','guest_session','game_hud_session','scoreboard','scoreboard_session']:
            run(name,'protocol/'+name)
        for name,path in [('zone','zone_modes/unit'),('world','lattice/world_contract'),('world-commands','lattice/world_commands_contract'),('combined','combined_arms/test_controls'),('sports','sports/test_controls')]:
            run(name,path)
        read,write=os.pipe()
        display=subprocess.Popen(['Xvfb','-displayfd',str(write),'-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],pass_fds=[write],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        os.close(write)
        try:
            with os.fdopen(read) as pipe: env['DISPLAY']=':'+pipe.readline().strip()
            run('spectator-ui','protocol/lobby_spectator_session',['--','--lobby-menu'],False)
            run('geometry-960','protocol/lobby_followup_geometry',['--resolution','960x640','--','--lobby-menu'],False)
            run('geometry-1280','protocol/lobby_followup_geometry',['--resolution','1280x800','--','--lobby-menu'],False)
            run('weapon','protocol/weapon_selection',headless=False)
        finally:
            display.terminate();display.communicate(timeout=5)
        cleanup={'displayPid':display.pid,'displayReaped':not pathlib.Path('/proc/'+str(display.pid)).exists()}
    else: cleanup={}
cleanup['tempRemoved']=not pathlib.Path(tmp).exists()
(OUT/('checks-old.json' if old else 'checks.json')).write_text(json.dumps({'checks':checks,'cleanup':cleanup},indent=2)+'\n')
raise SystemExit(any(c['exit'] for c in checks))
