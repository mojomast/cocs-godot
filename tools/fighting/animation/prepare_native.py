"""Prepare a minimal native project without invoking Godot or its importer.

Use after exports exist, then run its import/playback during the granted slot.
Only the selected operators are copied; no maps or FPS asset import fan-out.
"""
import argparse
import json
from pathlib import Path
import shutil
import re
from recipes import OPERATORS


def prepare(root,output,operators,stage=False):
    output.mkdir(parents=True,exist_ok=True)
    for operator in operators:
        if operator not in OPERATORS: raise ValueError(operator)
        for suffix in ('.glb','.json'):
            relative = Path('fighting/assets/operators')/(operator+suffix)
            destination = output/relative
            destination.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(root/'godot'/relative,destination)
        import_path=output/'fighting/assets/operators'/f'{operator}.glb.import'
        source_import=root/'godot/fighting/assets/operators'/f'{operator}.glb.import'
        if source_import.exists(): shutil.copy2(source_import,import_path)
        if import_path.exists():
            settings=import_path.read_text().replace('animation/fps=30','animation/fps=60').replace('meshes/generate_lods=true','meshes/generate_lods=false')
            subresources={'nodes':{'PATH:AnimationPlayer':{'optimizer/enabled':False,'compression/enabled':False}}}
            settings=re.sub(r'_subresources=.*?(?=\ngltf/|\Z)','_subresources='+json.dumps(subresources),settings,flags=re.S)
            import_path.write_text(settings)
    for relative in ('fighting/visuals','tests/fighting/animation','fighting/data','source_operators/moth_finish'):
        shutil.copytree(root/'godot'/relative,output/relative,dirs_exist_ok=True)
    (output/'source_operators/generated').mkdir(parents=True,exist_ok=True)
    shutil.copy2(root/'godot/source_operators/generated/catalog.gd',output/'source_operators/generated/catalog.gd')
    if stage:
        for relative in ('fighting/core','fighting/presentation','fighting/effects','fighting/assets/effects','fighting/stages'):
            shutil.copytree(root/'godot'/relative,output/relative,dirs_exist_ok=True)
        for relative in ('fighting/main.gd','fighting/main.tscn','identity_maps/generated/basalt-reach.json'):
            (output/relative).parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(root/'godot'/relative,output/relative)
        queue=list((output/'fighting').rglob('*.gd'))
        seen=set()
        while queue:
            file=queue.pop()
            if file in seen: continue
            seen.add(file)
            for match in re.findall(r'res://([^"\s\)]+)',file.read_text()):
                if match=='ui/main_menu.tscn': continue  # proof never enters Home
                source=root/'godot'/match
                if source.is_file():
                    target=output/match
                    target.parent.mkdir(parents=True,exist_ok=True)
                    if not target.exists(): shutil.copy2(source,target)
                    if target.suffix in ('.gd','.gdshader','.tscn','.tres'): queue.append(target)
    (output/'project.godot').write_text('''config_version=5

[application]
config/name="Operator Clash animation proof"
config/features=PackedStringArray("4.5", "GL Compatibility")

[display]
window/size/viewport_width=1280
window/size/viewport_height=800

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
''')
    (output/'proof-selection.json').write_text(json.dumps({'operators':operators,'source':str(root),'status':'prepared_not_imported'},indent=2)+'\n')


if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[3])
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--operators',default='meta,mistral')
    parser.add_argument('--stage',action='store_true')
    options = parser.parse_args()
    prepare(options.root,options.output,options.operators.split(','),options.stage)
