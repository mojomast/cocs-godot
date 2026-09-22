"""Correct display prerequisites for the existing synthetic weapon regression."""
import json, os, pathlib, subprocess, tempfile, sys
ROOT = pathlib.Path(__file__).resolve().parents[3]
OUT = pathlib.Path(__file__).resolve().parent
GODOT = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
report = {}
with tempfile.TemporaryDirectory(prefix='lobby-graphical-check-',dir='/tmp/opencode') as tmp:
    env = dict(os.environ, HOME=tmp, LIBGL_ALWAYS_SOFTWARE='1')
    for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','XDG_RUNTIME_DIR']:
        env[key] = tmp+'/'+key
        pathlib.Path(env[key]).mkdir(mode=0o700)
    read, write = os.pipe()
    display = subprocess.Popen(['Xvfb','-displayfd',str(write),'-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'], pass_fds=[write],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
    os.close(write)
    try:
        with os.fdopen(read) as pipe: env['DISPLAY'] = ':'+pipe.readline().strip()
        report['exit'] = 0
        if '--menu-only' not in sys.argv and '--layout-only' not in sys.argv:
            command = [GODOT,'--path','godot','--audio-driver','Dummy','--script','res://tests/protocol/weapon_selection.gd']
            p = subprocess.run(command,cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=45)
            (OUT/'weapon_selection-graphical.log').write_bytes(p.stdout)
            report.update(command=command,exit=p.returncode)
        report['menuExit'] = 0
        if '--layout-only' in sys.argv:
            report['layout'] = []
            for size in ['960x640','1280x800']:
                command = [GODOT,'--path','godot','--audio-driver','Dummy','--resolution',size,'--script','res://tests/protocol/lobby_independent_hud.gd','--','--lobby-menu']
                p = subprocess.run(command,cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=30)
                (OUT/('hud-layout-graphical-'+size+'.log')).write_bytes(p.stdout)
                report['layout'].append(dict(command=command,exit=p.returncode))
        else:
            command = [GODOT,'--path','godot','--audio-driver','Dummy','--script','res://tests/protocol/lobby_independent_menu.gd','--','--lobby-menu']
            p = subprocess.run(command,cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=30)
            (OUT/'lobby-menu-input.log').write_bytes(p.stdout)
            report.update(menuCommand=command,menuExit=p.returncode)
    finally:
        display.terminate()
        display.communicate(timeout=5)
        report['displayPid'] = display.pid
        report['displayReaped'] = not pathlib.Path('/proc/'+str(display.pid)).exists()
report['privateRemoved'] = not pathlib.Path(tmp).exists()
(OUT/('layout-graphical-check.json' if '--layout-only' in sys.argv else 'graphical-check.json')).write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
raise SystemExit(report['exit'] or report['menuExit'] or any(c['exit'] for c in report.get('layout',[])))
