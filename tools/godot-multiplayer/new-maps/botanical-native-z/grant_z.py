"""Exclusive MOTH-BLENDER-20261003-Z: reviewed lifetime-lock runner in a new namespace."""
from pathlib import Path
source=Path(__file__).resolve().parent.parent/'gravemill-foundry/revision5/grant.py'
code=source.read_text()
for old,new in [('/tmp/opencode/foundry-astra-S','/tmp/opencode/vesper-astra-Z'),
                ('ROOT = HERE.parents[4]','ROOT = HERE.parents[3]'),
                ('MOTH-BLENDER-20261003-S','MOTH-BLENDER-20261003-Z'),
                ('time.monotonic()+14400','time.monotonic()+3600'),
                ('godot/tests/new_maps/gravemill_foundry/revision5','godot/tests/new_maps/botanical_post_x')]:
    assert old in code;code=code.replace(old,new)
exec(compile(code,str(source),'exec'),globals())
