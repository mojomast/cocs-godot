"""Dry-plan default. Native execution requires a NEW explicit local heavy grant."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import signal
import subprocess

ROOT = Path(__file__).resolve().parents[2]
CASES = [
    ('home-search', 'main_menu/search.gd', 30),
    ('home-input', 'main_menu/contracts.gd', 120),
    ('bindings', 'input_bindings/contracts.gd', 60),
    ('journal-model', 'campaign/journal_model.gd', 30),
    ('journal-input', 'campaign/journal_input.gd', 60),
    ('training-feedback', 'fighting/presentation/training_feedback.gd', 60),
    ('training-layout', 'fighting/presentation/training_layout.gd', 60),
]
parser = argparse.ArgumentParser()
parser.add_argument('--grant', help='Explicit new grant identifier; J is owned by Stormglass')
parser.add_argument('--godot', default='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64')
parser.add_argument('--output', type=Path, default=Path('/tmp/opencode/overnight-ui-native'))
args = parser.parse_args()
plan = [{'id': name, 'timeoutSeconds': limit, 'argv': [args.godot, '--headless', '--path', str(ROOT/'godot'), '--script', 'res://tests/'+script]} for name, script, limit in CASES]
if not args.grant:
    print(json.dumps({'executed': False, 'nativePending': True, 'cases': plan}, indent=2))
else:
    args.output.mkdir(parents=True, exist_ok=True)
    with open('/tmp/opencode/cocs-finish-acceptance.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        for case in plan:
            log = args.output/(case['id']+'.log')
            record = {**case, 'grant': args.grant}
            home = (args.output/case['id']).resolve()
            home.mkdir(parents=True, exist_ok=True)
            with log.open('w') as stream:
                child = subprocess.Popen(case['argv'], cwd=ROOT, start_new_session=True,
                    env={**os.environ, 'LP_NUM_THREADS': '1', 'XDG_DATA_HOME': str(home/'data'),
                         'XDG_CONFIG_HOME': str(home/'config'), 'COCS_SETTINGS_PATH': str(home/'settings.json'),
                         'COCS_BINDINGS_PATH': str(home/'bindings.json')}, stdout=stream, stderr=subprocess.STDOUT)
                record['processGroup'] = child.pid
                try:
                    child.wait(timeout=case['timeoutSeconds'])
                finally:
                    try: os.killpg(child.pid, signal.SIGKILL)
                    except ProcessLookupError: pass
                    child.wait()
                    record['exitCode'] = child.returncode
                    (args.output/(case['id']+'.json')).write_text(json.dumps(record, indent=2)+'\n')
            assert child.returncode == 0, log
            assert not re.search(r'SCRIPT ERROR:|ERROR:|Assertion failed|instances leaked', log.read_text()), log
