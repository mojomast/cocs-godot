"""W-owned serial runner; reuse immutable S implementation with isolated state/logs."""
from pathlib import Path
source=Path(__file__).resolve().parent.parent/'revision5/grant.py'
code=source.read_text()
for old,new in [('/tmp/opencode/foundry-astra-S','/tmp/opencode/foundry-astra-W'),
                ('MOTH-BLENDER-20261003-S','MOTH-BLENDER-20261003-W'),
                ("HERE/'evidence/attempts'","HERE/'evidence/W/attempts'")]:
    assert old in code
    code=code.replace(old,new)
exec(compile(code,str(source),'exec'),{'__file__':__file__,'__name__':'__main__'})
