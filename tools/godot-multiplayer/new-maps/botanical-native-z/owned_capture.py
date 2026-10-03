"""Preserve parser/assert failures; terminate only the exact owned Godot child."""
from pathlib import Path
source=Path(__file__).resolve().parent.parent/'gravemill-foundry/revision5/owned_capture.py'
code=source.read_text().replace('from grant import','from grant_z import')
exec(compile(code,str(source),'exec'),globals())
