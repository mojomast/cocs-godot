#!/usr/bin/env python3
"""Independent executions of the reviewed delivery harness, new output only.

No runtime/observer/server substitutions. Exact harness transformations below
redirect output, add focused tests, and strengthen owned-process/listener checks.
"""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[3]
original = ROOT / 'port/native-arms-race/run.py'
source = original.read_text()
changes = {
    "ROOT / 'port/native-arms-race/evidence'": "ROOT / 'port/reports/arms-race-independent/evidence'",
    "'game/armsrace.test.mjs','game/outcome.test.mjs'": "'game/armsrace.test.mjs','game/outcome.test.mjs','game/input.test.mjs','game/movement-input.test.mjs'",
    "run(base+['--script','res://tests/arms_race/fixtures.gd'],OUT/'fixtures.log',env)": "run(base+['--script','res://tests/arms_race/independent_fixtures.gd'],OUT/'fixtures.log',env)\n        if not args.attempt:\n            for test in ['control_safety','local_lifecycle','round_boundaries','session_recovery','stall_controls','game_hud_session','scoreboard_session']:\n                run(base+['--script','res://tests/protocol/'+test+'.gd'],OUT/(test+'.log'),env)",
    "cases = [('meridian-exchange','1280x800',False)]": "if args.startup:\n                    run([BIN,'--path',str(temp/'godot'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','1280x800','--script','res://tests/protocol/weapon_selection.gd'],OUT/'weapon_selection.log',env,30)\n                cases = [('meridian-exchange','1280x800',False)]",
    "temp = Path(tmp)": "temp = Path(tmp)\n        report['privateTemp'] = tmp",
    "finally: stop(server)": "finally:\n                            stop(server)\n                            if 'endpoint' in locals():\n                                import socket\n                                with socket.socket() as probe:\n                                    probe.settimeout(1)\n                                    closed = probe.connect_ex(('127.0.0.1',int(endpoint.rsplit(':',1)[1]))) != 0\n                                require(closed,'Owned authority listener survived')\n                                report.setdefault('listenerCleanup',[]).append({'endpoint':endpoint,'closed':closed})",
    "report['ownedProcessesReaped'] = True": "report['ownedProcessesReaped'] = True\n    report['processes'] = [{'pid':c.pid,'returncode':c.returncode,'command':c.args} for c in children]\n    report['privateTempRemoved'] = not Path(report.get('privateTemp','/nonexistent')).exists()\n    report['provenance'] = {'originalRunnerSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'independentWrapperSHA256':hashlib.sha256((ROOT/'port/reports/arms-race-independent/run.py').read_bytes()).hexdigest(),'observer':'unchanged delivery observer','budget':'independent review: max two live combat attempts; delivery attempts excluded'}",
}
for before, after in changes.items():
    if source.count(before) != 1:
        raise RuntimeError('Harness drift: '+before)
    source = source.replace(before, after)
exec(compile(source, str(original), 'exec'), {'__file__':str(original), '__name__':'__main__'})
