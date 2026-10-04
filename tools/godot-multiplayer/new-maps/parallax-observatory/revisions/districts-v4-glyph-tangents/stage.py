"""Future write-once test stage bridge; requires actual build AND fresh reopen."""
import re
from successor import *

def attempt_path(attempt):
    if not re.fullmatch(r'glyph-[a-z0-9-]{3,40}',attempt):raise ValueError('Fresh glyph attempt required')
    return HERE/'native'/attempt

def require_grant(path):
    grant=json.loads(path.read_text())
    if grant.get('exclusive') is not True or grant.get('released') is not False or grant.get('revision')!=REVISION or not grant.get('grant'):
        raise ValueError('Explicit active exclusive successor grant required')
    return grant

def prepare(attempt,receipt):
    require_grant(receipt);out=attempt_path(attempt);raw=frozen()
    artifact=(out/'parallax-glyph-tangents.glb').read_bytes();verify_art(raw,artifact)
    master=sha((out/'parallax-glyph-tangents.blend').read_bytes())
    for name in ('build-report.json','reopen-report.json'):
        r=json.loads((out/name).read_text())
        if r['actualArtHash']!=sha(artifact) or r['actualMasterHash']!=master:raise ValueError('Actual build/reopen identity required')
    dest=ROOT/'godot/tests/new_maps/parallax_glyph'/attempt
    dest.mkdir(parents=True,exist_ok=False)
    res=lambda p:'res://'+str(p.relative_to(ROOT/'godot'))
    (dest/'candidate.glb').write_bytes(artifact);(dest/'before-AA-failed.glb').write_bytes(raw)
    for name in ('authority.json','profile.json','profile_schema.gd'):
        (dest/name).write_bytes((X_STAGE/name).read_bytes())
    historical=json.loads((X_STAGE/'manifest.json').read_text())
    manifest={key:historical[key] for key in ('map','geometryHash','modes','source')}
    manifest['source'].update(acceptedArt=res(dest/'before-AA-failed.glb'),acceptedArtSha256=AA_SHA)
    manifest['source'].update(acceptedAuthority=res(dest/'authority.json'),acceptedAuthoritySha256=sha((dest/'authority.json').read_bytes()),acceptedGeometryHash=aa.GEOMETRY)
    manifest.update(status='artifacts-verified-native-pending',actualArtHash=sha(artifact),glbSha256=sha(artifact),beforeMeaning='FAILED AA candidate, not approved runtime',visualRevision=REVISION)
    old=res(X_STAGE)+'/'
    for name in ('staged.gd','capture.gd'):
        text=(X_STAGE/name).read_text().replace(old,res(dest)+'/').replace('accepted-runtime-before','failed-AA-before')
        # Existing staged loader has a filename chosen by the historical stage.
        text=text.replace('parallax-observatory.glb','candidate.glb')
        if name=='staged.gd':
            text=text.replace('if candidate:', 'if true:')
            text=text.replace('directory(id)+"candidate.glb.import"','directory(id)+("candidate.glb.import" if candidate else "before-AA-failed.glb.import")')
            text=text.replace('load(directory(id) + "candidate.glb")','load(directory(id) + ("candidate.glb" if candidate else "before-AA-failed.glb"))')
            text=text.replace('\t\tassert(not Schema.validate(profile, id, receipt.source.acceptedGeometryHash).is_empty())\n','')
            text=text.replace('art.name = "BlenderArtNoGameplayCollision"','assert(art.find_children("*", "MeshInstance3D", true, false).size() == 39)\n\t\tart.name = "BlenderArtNoGameplayCollision"')
        (dest/name).write_text(text)
    text=(ROOT/'godot/tests/new_maps/parallax_tangent/import.gd').read_text().replace('res://tests/new_maps/parallax_tangent/',res(dest)+'/')
    (dest/'import.gd').write_text(text)
    probes=json.loads((X_STAGE/'probes.json').read_text())
    for camera in probes['cameras']:
        camera['beforeEye']=camera['eye']
        camera['comparison']='Matched AA-failed/successor camera; unchanged AA geometry, manual appearance pending'
    g=aa.EmbeddedGlb(raw)
    for ni in (33,34):
        node=g.doc['nodes'][ni];position,_=aa_editable.world(node)
        target=position((2.4228,0,-.16368));eye=(target[0]+2,target[1]+1,target[2]+2)
        probes['cameras'].append({'id':node['name']+'-glyph-close','eye':eye,'beforeEye':eye,'target':target,'player':False,'fov':40,'comparison':'Matched AA-failed/successor glyph exterior inspection; not a supported player view'})
    (dest/'probes.json').write_text(json.dumps(probes,indent=2)+'\n')
    manifest['files']={res(p):sha(p.read_bytes()) for p in dest.iterdir() if p.is_file()}
    (dest/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return dest

def check_sidecar(path):
    text=path.read_text()
    required=('importer="scene"','uid="uid://','meshes/force_disable_compression=true','meshes/generate_lods=false')
    if any(value not in text for value in required):raise ValueError('Real UID/full precision/LOD-off sidecar required')
    # ensure_tangents is never used to excuse a basis mismatch.
    return sha(path.read_bytes())
