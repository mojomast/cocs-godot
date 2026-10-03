"""Inventory and remove only W-generated unrelated import sidecars."""
from pathlib import Path
import sys
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'revision5'))
import grant
grant.HERE=HERE
code=(HERE.parent/'revision5/clean_sidecars.py').read_text()
code=code.replace('evidence/attempts/','evidence/W/attempts/').replace('/gravemill_foundry/revision5/','/gravemill_foundry/revision6/').replace('gravemill-foundry-r5','gravemill-foundry-r6').replace('S-generated','W-generated').replace('S import','W import').replace('S sidecars','W sidecars')
exec(compile(code,__file__,'exec'))
