"""New repair logs only. Existing HOLD evidence and native/source files are read-only."""
import gzip
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
GODOT='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
def run(name, command, expected=0, extra=None):
    assert not (OUT/(name+'.json')).exists(), 'Never overwrite an earlier attempt/check'
    with tempfile.TemporaryDirectory(prefix='horde-event-check-',dir='/tmp/opencode') as temp:
        env=dict(os.environ,TMPDIR='/tmp/opencode',GODOT_BIN=GODOT,**(extra or {}))
        for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','XDG_RUNTIME_DIR']:
            path=Path(temp)/key;path.mkdir(mode=0o700);env[key]=str(path)
        result=subprocess.run(command,cwd=ROOT,env=env,capture_output=True,timeout=120)
        raw=result.stdout+result.stderr
        (OUT/(name+'.log.gz')).write_bytes(gzip.compress(raw,mtime=0))
    metadata=dict(command=command,envOverrides=extra or {},exit=result.returncode,expectedExit=expected,temporaryTreeRemoved=not Path(temp).exists())
    (OUT/(name+'.json')).write_text(json.dumps(metadata,indent=2)+'\n')
    print(name,json.dumps(metadata),raw.decode(errors='replace')[-1800:],flush=True)
    assert result.returncode==expected,name
    if expected==0: assert not any(x in raw for x in [b'SCRIPT ERROR',b'Parse Error',b'ERROR:',b'ObjectDB instances leaked',b'resources still in use']),name
def native(name,script,args=()):
    run(name,[GODOT,'--headless','--path','godot','--script',script,'--',*args])
if __name__=='__main__':
    run('adapter', ['node','--test','port/native-horde/test.mjs','port/native-horde/input-buffer.test.mjs','port/native-horde/repair-regression.test.mjs','port/native-horde/event-cursor.test.mjs','port/native-horde/npc-kills.test.mjs'])
    run('source-ui',['node','--test','game/singleplayer.test.mjs','game/singleplayer-ui.test.mjs'])
    run('semantic',['node','tools/godot-export/semantic.mjs'])
    run('import',[GODOT,'--headless','--path','godot','--editor','--import'])
    native('horde-model','res://tests/horde/test.gd')
    vectors=str(OUT/'input-vectors.json')
    run('source-oracle',['node','port/native-horde/input-oracle.mjs',vectors])
    native('native-input','res://tests/horde/controls_test.gd',['--vectors='+vectors])
    run('source-lock',['node','--input-type=module','-e','import {verifySource} from "./tools/godot-export/semantic.mjs"; import fs from "node:fs"; verifySource(JSON.parse(fs.readFileSync("port/contracts/source-lock.json"))); console.log("SOURCE_LOCK_OK");'])
