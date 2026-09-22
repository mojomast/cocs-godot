"""Private editor-free candidate export using the existing package preset read-only.
This tests native resources/JSON packaging, not a complete distributable game archive.
"""
import ast
import hashlib
import json
import os
from pathlib import Path
import select
import shutil
import subprocess
import tarfile
import tempfile
import time
from verify import ROOT,OUT,DEFAULT,run
from live import reap
TEMPLATE=Path('/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/data/godot/export_templates/4.5.2.stable/linux_release.x86_64')

def main():
    evidence=OUT/'evidence'/('release-'+str(time.time_ns())); evidence.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix='player-model-release-',dir='/tmp/opencode') as temporary:
        stage=Path(temporary)
        env={'PATH':os.environ['PATH'],'HOME':str(stage),'LANG':'C.UTF-8','LIBGL_ALWAYS_SOFTWARE':'1'}
        for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']:
            env[key]=str(stage/key); Path(env[key]).mkdir()
        template_dir=Path(env['XDG_DATA_HOME'])/'godot/export_templates/4.5.2.stable'
        template_dir.mkdir(parents=True)
        shutil.copy2(TEMPLATE,template_dir/TEMPLATE.name)
        (template_dir/'version.txt').write_text('4.5.2.stable\n')
        binary=os.environ.get('GODOT_BIN',DEFAULT)
        project=stage/'godot'
        shutil.copytree(ROOT/'godot',project,ignore=shutil.ignore_patterns('.godot','content','*.uid'))
        p=project/'world/presentation.gd'; p.write_text(p.read_text().replace('res://world/actor_visual.gd','res://player_models/candidate.gd'))
        p=project/'project.godot'; p.write_text(p.read_text().replace('res://main.tscn','res://player_models/preview.tscn'))
        parsed=ast.parse((ROOT/'tools/godot-package/build.py').read_text())
        preset=next(ast.literal_eval(node.value) for node in ast.walk(parsed) if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='preset' for t in node.targets))
        preset=preset.replace('include_filter="','include_filter="player_models/*.json,')
        (project/'export_presets.cfg').write_text(preset)
        (evidence/'preset.cfg').write_text(preset)
        run(['node',ROOT/'tools/godot-export/semantic.mjs',project/'content/generated'],env,evidence/'semantic.log')
        run([binary,'--headless','--path',project,'--editor','--import'],env,evidence/'import.log')
        package=stage/'package'; package.mkdir()
        run([binary,'--headless','--path',project,'--export-release','Private Linux Prototype',package/'candidate.x86_64'],env,evidence/'export.log')
        archive=stage/'candidate.tar.gz'
        with tarfile.open(archive,'w:gz') as target:
            for name in ['candidate.x86_64','candidate.pck']: target.add(package/name,arcname=name)
        fresh=stage/'fresh-extraction'; fresh.mkdir()
        with tarfile.open(archive) as source:
            for member in source.getmembers():
                if member.name not in ['candidate.x86_64','candidate.pck'] or not member.isfile(): raise RuntimeError('invalid own archive')
                source.extract(member,fresh)
        # Remove original editor project/cache and package before release startup.
        shutil.rmtree(project); shutil.rmtree(package)
        read_fd,write_fd=os.pipe(); xvfb=None
        with (evidence/'xvfb.log').open('w') as log:
            try:
                xvfb=subprocess.Popen(['Xvfb','-displayfd',str(write_fd),'-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],env=env,pass_fds=[write_fd],stdout=log,stderr=subprocess.STDOUT)
                os.close(write_fd)
                if not select.select([read_fd],[],[],10)[0]: raise RuntimeError('Xvfb readiness failed')
                env['DISPLAY']=':'+os.read(read_fd,64).decode().strip()
                text=run([fresh/'candidate.x86_64','--audio-driver','Dummy','--','--single','--output='+str(evidence)],env,evidence/'release.log',cwd=fresh,timeout=45)
                if 'PLAYER_MODEL_RELEASE_RENDER_OK' not in text: raise RuntimeError('release completion absent')
            finally:
                os.close(read_fd); reap(xvfb)
        hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in fresh.iterdir()}
        (evidence/'result.json').write_text(json.dumps({'files':hashes,'template_sha256':hashlib.sha256(TEMPLATE.read_bytes()).hexdigest(),'fresh_extraction':True,'source_project_removed':True,'candidate_preview_only':True,'full_game_package':False,'xvfb_exit':xvfb.returncode},indent=2)+'\n')
    print('PLAYER_MODEL_RELEASE_OK '+str(evidence))
if __name__=='__main__': main()
