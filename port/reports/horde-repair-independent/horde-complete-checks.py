"""Finish unaffected checks after the retained Meridian validator rejection."""
from pathlib import Path
from importlib.machinery import SourceFileLoader
checks = SourceFileLoader('horde_checks', str(Path(__file__).with_name('horde-checks.py'))).load_module()
for uuid in ['fe8751ed-4200-4eec-8e91-5252bf598f4b', 'f1346289-0f65-4210-bad5-1df72d0dc179']:
    checks.run('validate-' + uuid, ['node', 'port/native-horde/validate.mjs', str(checks.OUT / 'evidence' / uuid)])
checks.run('source-lock', ['node', '--input-type=module', '-e', 'import {verifySource} from "./tools/godot-export/semantic.mjs"; import fs from "node:fs"; verifySource(JSON.parse(fs.readFileSync("port/contracts/source-lock.json"))); console.log("SOURCE_LOCK_OK");'])
