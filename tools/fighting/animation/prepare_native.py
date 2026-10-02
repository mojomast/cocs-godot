"""Prepare a minimal native project without invoking Godot or its importer.

Use after exports exist, then run its import/playback during the granted slot.
Only the selected operators are copied; no maps or FPS asset import fan-out.
"""
import argparse
import json
from pathlib import Path
import shutil
from recipes import OPERATORS


def prepare(root,output,operators):
    output.mkdir(parents=True,exist_ok=True)
    for operator in operators:
        if operator not in OPERATORS: raise ValueError(operator)
        for suffix in ('.glb','.json'):
            relative = Path('fighting/assets/operators')/(operator+suffix)
            destination = output/relative
            destination.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(root/'godot'/relative,destination)
    for relative in ('fighting/visuals','tests/fighting/animation','fighting/data'):
        shutil.copytree(root/'godot'/relative,output/relative,dirs_exist_ok=True)
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
    options = parser.parse_args()
    prepare(options.root,options.output,options.operators.split(','))
