"""Pin an exact staged profile/schema; production identities remain untouched."""
import json
import hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[4]
dest=ROOT/'godot/tests/new_maps/gravemill_foundry/revision5';dest.mkdir(parents=True,exist_ok=True)
data=json.loads((HERE/'candidate.json').read_text());profile=ROOT/'godot/multiplayer_worlds/dressing/profiles/gravemill-foundry.json'
schema=ROOT/'godot/multiplayer_worlds/dressing/profile.gd';p=json.loads(profile.read_text());old=p['geometry_hash'];new=data['geometryHash']
p['geometry_hash']=new;p['materials']=[];p['budgets']['material_variants']=0
p['preserve_materials']=list(json.loads((HERE/'export-report.json').read_text())['moth']['materials'])+['GM / orange']
raw=json.dumps(p,indent=2)+'\n';(dest/'profile.json').write_text(raw)
(dest/'profile_schema.gd').write_text('## Generated R5-only exact identity schema; production schema is unchanged.\n'+schema.read_text().replace('"gravemill-foundry": "'+old+'"','"gravemill-foundry": "'+new+'"'))
sha=lambda b:hashlib.sha256(b).hexdigest()
lineage={'acceptedProfileSha256':sha(profile.read_bytes()),'acceptedSchemaSha256':sha(schema.read_bytes()),'acceptedGeometryHash':old,
 'candidateGeometryHash':new,'candidateProfileSha256':sha(raw.encode()),'candidateSchemaSha256':sha((dest/'profile_schema.gd').read_bytes()),
 'policy':'Retain actual imported R5 PBR and exact accepted orange; reuse accepted authored panels/signs/pockets through production Binder. Stage-only exact identity gate.'}
(dest/'profile-lineage.json').write_text(json.dumps(lineage,indent=2)+'\n')
lights={'geometryHash':new,'acceptedArtSha256':sha((ROOT/'godot/multiplayer_worlds/art/worlds/gravemill-foundry.glb').read_bytes()),
 'fixtureSource':'Accepted orange batch: cooling fixtures x=-89+6.5*i, y=23.5, z=36+.14*x; lights offset 0.4m below existing faces.',
 'lights':[{'id':'cooling-fixture-'+str(i),'position':[x,23.1,36+.14*x],'color':'ffd9a3','energy':3.5,'range':18} for i,x in enumerate([-89,-76,-63,-50])],
 'scope':'Bounded staged runtime presentation, not capture-only lights; no emitter material mutation'}
(dest/'lights.json').write_text(json.dumps(lights,indent=2)+'\n')
print(json.dumps(lineage))
