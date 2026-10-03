"""Future build-only native source setup; exact R7 art identity is mandatory."""
from tangents import *

def replace(text,old,new):
    if old not in text:raise ValueError('Frozen R6 template contract changed: '+old)
    return text.replace(old,new)

def prepare(art_hash):
    if len(art_hash)!=64:raise ValueError('Actual built art hash required')
    base=ROOT/'godot/tests/new_maps/gravemill_foundry/revision6';dest=base.parent/'revision7';dest.mkdir(parents=True,exist_ok=True)
    for name in ('profile.json','profile_schema.gd','lights.json','probes.json'):
        (dest/name).write_bytes((base/name).read_bytes())
    lineage=json.loads((base/'profile-lineage.json').read_text())
    lineage.update({'visualRevision':7,'sourceR6LineageSha256':sha((base/'profile-lineage.json').read_bytes()),'policy':'Identical R6 finish, seven tangent-only corrections; distinct R7 art identity, unchanged R5 geometry authority.'})
    (dest/'profile-lineage.json').write_text(json.dumps(lineage,indent=2)+'\n')
    stage=(base/'staged.gd').read_text().replace('/revision6/','/revision7/')
    stage=replace(stage,'art/revisions/gravemill-foundry-r6.glb','art/revisions/gravemill-foundry-r7.glb')
    stage=replace(stage,'identity.visualRevision == 6','identity.visualRevision == 7')
    stage=replace(stage,'set_meta("visualRevision", 6)','set_meta("visualRevision", 7)').replace('ExactR6','ExactR7')
    (dest/'staged.gd').write_text(stage)
    identity={'visualRevision':7,'geometryHash':AUTHORITY,'artHash':art_hash,'sourceR6ArtHash':SOURCE_SHA,'acceptance':'pending native review'}
    (dest/'art-identity.json').write_text(json.dumps(identity,indent=2)+'\n')
    probe=(base/'import.gd').read_text().replace('/revision6/evidence/W/','/revision7/evidence/native-import/').replace('/revision6/','/revision7/').replace('R6_NATIVE_IMPORT','R7_NATIVE_IMPORT')
    (dest/'import.gd').write_text(probe)
    capture=(base/'capture.gd').read_text()
    capture=replace(capture,'revision6/staged.gd','revision7/staged.gd')
    capture=replace(capture,'revision5/staged.gd','revision6/staged.gd')
    capture=capture.replace('StageR5','StageR6').replace('staged-r5-before','staged-r6-before').replace('candidate-runtime-r6','candidate-runtime-r7')
    capture=capture.replace('revision6/evidence/','revision7/evidence/').replace('revision6/capture.gd','revision7/capture.gd')
    capture=replace(capture,'"visualRevision":6 if','"visualRevision":7 if');capture=replace(capture,'else 5,','else 6,')
    (dest/'capture.gd').write_text(capture.replace('R6_NATIVE_CAPTURE','R7_NATIVE_CAPTURE').replace('R6_CAPTURE_COMPLETE','R7_CAPTURE_COMPLETE'))

if __name__=='__main__':raise SystemExit('Called only after actual authorized R7 build; no source placeholder art identity')
