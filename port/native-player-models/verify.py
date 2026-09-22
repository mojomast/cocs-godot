"""Run release-safe checks and inherited gates against a privately patched project."""
import difflib
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'port/native-player-models'
DEFAULT = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'

def run(args, env, logfile, cwd=ROOT, timeout=240):
    result = subprocess.run(list(map(str,args)),cwd=cwd,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
    logfile.write_text(result.stdout)
    if result.returncode or any(x in result.stdout for x in ['SCRIPT ERROR','ERROR:','Assertion failed']):
        raise RuntimeError(f'{logfile}: exit {result.returncode}\n{result.stdout[-2500:]}')
    return result.stdout

def main():
    evidence=OUT/'evidence'/str(time.time_ns())
    evidence.mkdir(parents=True)
    binary=os.environ.get('GODOT_BIN',DEFAULT)
    with tempfile.TemporaryDirectory(prefix='player-model-check-',dir='/tmp/opencode') as temporary:
        stage=Path(temporary)
        env={'PATH':os.environ['PATH'],'HOME':str(stage),'TMPDIR':str(stage),'LANG':'C.UTF-8'}
        for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
            env[key]=str(stage/key); Path(env[key]).mkdir()
        version=run([binary,'--version'],env,evidence/'engine.log').strip()
        for i in range(2):
            recipe=stage/f'recipes-{i}.json'
            run(['python3','-B',OUT/'author_recipes.py','--output',recipe],env,evidence/f'recipe-{i}.log')
            if recipe.read_bytes() != (ROOT/'godot/player_models/recipes.json').read_bytes():
                raise RuntimeError('clean authored recipe rebuild differs')
        if version!='4.5.2.stable.official.6ce3de25a': raise RuntimeError('wrong engine')
        project=stage/'godot'
        shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot','content','*.uid'))
        source=project/'world/presentation.gd'
        old=source.read_text(); new=old.replace('res://world/actor_visual.gd','res://player_models/candidate.gd')
        if new==old: raise RuntimeError('missing exact integration hook')
        patch=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/godot/world/presentation.gd',tofile='b/godot/world/presentation.gd',n=0))
        package_old=(ROOT/'tools/godot-package/build.py').read_text()
        package_new=package_old.replace('include_filter="content/generated/*.json,content/generated/maps/*/*.json"','include_filter="content/generated/*.json,content/generated/maps/*/*.json,player_models/*.json"')
        if package_old==package_new: raise RuntimeError('package include hook changed')
        patch+=''.join(difflib.unified_diff(package_old.splitlines(True),package_new.splitlines(True),fromfile='a/tools/godot-package/build.py',tofile='b/tools/godot-package/build.py',n=0))
        (OUT/'integration.patch').write_text(patch)
        run(['git','apply','--check','--unidiff-zero',OUT/'integration.patch'],env,evidence/'patch-check.log')
        source.write_text(new)
        # Catalog-backed replay requires the real locked semantic export.
        run(['node',ROOT/'tools/godot-export/semantic.mjs',project/'content/generated'],env,evidence/'semantic.log')
        run([binary,'--headless','--path',project,'--editor','--import'],env,evidence/'import.log')
        results=[]
        for i in range(2):
            BuilderCache=project/'.godot'
            if i and BuilderCache.exists():
                shutil.rmtree(BuilderCache)
                run([binary,'--headless','--path',project,'--editor','--import'],env,evidence/f'import-{i}.log')
            text=run([binary,'--headless','--path',project,'--script','res://tests/player_models/geometry.gd'],env,evidence/f'geometry-{i}.log')
            record=json.loads(next(line.removeprefix('PLAYER_MODEL_RESULT ') for line in text.splitlines() if line.startswith('PLAYER_MODEL_RESULT ')))
            if not record['passed']: raise RuntimeError('geometry did not pass')
            results.append(record)
        if results[0]['variants']!=results[1]['variants']: raise RuntimeError('canonical rebuild mismatch')
        for name,marker in [('entity_visuals','PORT_ENTITY_VISUALS_OK'),('presentation','PORT_PRESENTATION_REPLAY_OK'),('local_lifecycle','PORT_LOCAL_LIFECYCLE_OK')]:
            text=run([binary,'--headless','--path',project,'--script',f'res://tests/protocol/{name}.gd'],env,evidence/f'{name}.log')
            if marker not in text: raise RuntimeError(f'missing {marker}')
        inputs={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for folder in ['godot/player_models','godot/tests/player_models'] for p in sorted((ROOT/folder).glob('*')) if p.is_file() and not p.name.endswith('.uid')}
        (evidence/'result.json').write_text(json.dumps(dict(engine=version,inputs=inputs,patch_sha256=hashlib.sha256(patch.encode()).hexdigest(),clean_rebuilds=2,geometry=results,staged_inherited_gates=True,live=False,export=False),indent=2)+'\n')
    print('PLAYER_MODEL_VERIFY_OK '+str(evidence))

if __name__=='__main__': main()
