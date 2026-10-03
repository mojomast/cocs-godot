"""Retain superseded corrective artifacts with the failed attempt logs."""
from pathlib import Path
import datetime
import tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[4]
name=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S')
with tarfile.open(HERE/'evidence/attempts'/('superseded-'+name+'.tar.gz'),'w:gz') as archive:
 for p in list(HERE.glob('*.json'))+list(HERE.glob('*.blend'))+list((ROOT/'godot/tests/new_maps/gravemill_foundry/revision5').glob('*report.json'))+[ROOT/'godot/multiplayer_worlds/art/revisions/gravemill-foundry-r5.glb']:
  archive.add(p,arcname=str(p.relative_to(ROOT)))
 for p in (HERE/'evidence/native').glob('*.png'):archive.add(p,arcname=str(p.relative_to(ROOT)))
print('Archived superseded corrective artifacts',name)
