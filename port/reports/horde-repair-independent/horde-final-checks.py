"""Additional final-tip checks, without repeating already passing suites."""
from pathlib import Path
import subprocess
from importlib.machinery import SourceFileLoader

checks = SourceFileLoader('horde_checks', str(Path(__file__).with_name('horde-checks.py'))).load_module()
out = checks.OUT
old = out / 'horde-pre-ads-demo.gd.txt'
old.write_bytes(subprocess.check_output(['git', 'show', '48d1029:godot/horde/demo.gd']))
vectors = '--vectors=' + str(out / 'input-vectors.json')
checks.native('product-look-old', 'res://tests/horde-repair-independent-look.gd', [vectors, '--demo-source=' + str(old)], 1)
checks.native('product-look-final', 'res://tests/horde-repair-independent-look.gd', [vectors])
for folder in sorted((out / 'evidence').iterdir()):
    checks.run('validate-' + folder.name, ['node', 'port/native-horde/validate.mjs', str(folder)])
checks.run('source-lock', ['node', '--input-type=module', '-e', 'import {verifySource} from "./tools/godot-export/semantic.mjs"; import fs from "node:fs"; verifySource(JSON.parse(fs.readFileSync("port/contracts/source-lock.json"))); console.log("SOURCE_LOCK_OK");'])
