"""Run bounded independent regressions with private HOME/XDG paths."""
import json, os, pathlib, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[3]
OUT = pathlib.Path(__file__).resolve().parent
GODOT = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
DEPS = '/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules'
if not (ROOT/'node_modules').exists(): (ROOT/'node_modules').symlink_to(DEPS, target_is_directory=True)
checks = []
with tempfile.TemporaryDirectory(prefix='lobby-checks-', dir='/tmp/opencode') as private:
    env = dict(os.environ, HOME=private)
    for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','XDG_RUNTIME_DIR']:
        env[key] = private+'/'+key
        pathlib.Path(env[key]).mkdir(mode=0o700)
    def run(name, args, timeout=90):
        p = subprocess.run(args, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        (OUT/(name+'.log')).write_bytes(p.stdout)
        checks.append(dict(name=name, command=args, exit=p.returncode))
        print(name, p.returncode, flush=True)
    run('semantic-export', ['node','tools/godot-export/semantic.mjs'])
    run('import', [GODOT,'--headless','--path','godot','--editor','--import'],180)
    for name in ['lobby_flow','control_safety','window_focus','stall_controls','session_recovery','round_boundaries','local_lifecycle','guest_session','native_trace','input_queue','envelopes','match_selection','match_selection_menu','game_hud_session','scoreboard_session','weapon_selection']:
        run(name, [GODOT,'--headless','--path','godot','--script','res://tests/protocol/'+name+'.gd'])
    for name, path in [('zone-unit','zone_modes/unit'),('world-contract','lattice/world_contract'),('world-commands','lattice/world_commands_contract'),('combined-controls','combined_arms/test_controls')]:
        run(name,[GODOT,'--headless','--path','godot','--script','res://tests/'+path+'.gd'])
    run('source-lifecycle', ['node','--test','--test-timeout=120000','server/room.test.mjs','server/rooms.test.mjs','server/spectator.test.mjs','server/network.test.mjs','server/resilience.test.mjs'],180)
    run('zone-routing',['node','--test','port/native-zone-modes/route.test.mjs'])
(OUT/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
raise SystemExit(any(c['exit'] for c in checks))
