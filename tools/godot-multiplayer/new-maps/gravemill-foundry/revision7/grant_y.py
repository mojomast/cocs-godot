"""Explicit Y authorization only; isolated serial lifetime-lock runner."""
from pathlib import Path
source=Path(__file__).resolve().parent.parent/'revision5/grant.py'
code=source.read_text()
for old,new in [('/tmp/opencode/foundry-astra-S','/tmp/opencode/foundry-astra-Y'),
                ('MOTH-BLENDER-20261003-S','MOTH-BLENDER-20261003-Y'),
                ("HERE/'evidence/attempts'","HERE/'evidence/Y/attempts'"),
                ('godot/tests/new_maps/gravemill_foundry/revision5','godot/tests/new_maps/gravemill_foundry/revision7')]:
    assert old in code;code=code.replace(old,new)
exec(compile(code,str(source),'exec'),{'__file__':__file__,'__name__':'__main__'})
