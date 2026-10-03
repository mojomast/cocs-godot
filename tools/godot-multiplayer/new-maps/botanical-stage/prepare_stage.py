"""Source preparation now; artifact-backed native stage only after production.

--source runs pure author plans and source probes; never writes ready manifests.
--map requires the actual build, reopen, geometry proof and embedded GLB audit.
"""
import argparse
import copy
import json
import re
import shutil
import subprocess
import sys
from config import HERE, ROOT, DEST, MAPS, entry, source_manifest, read, write, sha, res


def probes(map_id):
    return json.loads(subprocess.check_output(['node',str(HERE/'probes.mjs'),map_id],cwd=ROOT,text=True))


def schema_source():
    original=(ROOT/'godot/multiplayer_worlds/dressing/profile.gd').read_text()
    identities='const IDENTITIES := '+json.dumps({k:v[1] for k,v in MAPS.items()},indent=2)
    return '## Test-only exact botanical identities; no runtime admission.\n'+re.sub(r'const IDENTITIES := \{.*?\}',identities,original,count=1,flags=re.S)


def prepare_source():
    manifest=source_manifest()
    write(DEST/'source-manifest.json',manifest)
    (DEST/'profile_schema.gd').write_text(schema_source())
    summary={}
    for map_id in MAPS:
        p=probes(map_id)
        write(DEST/(map_id+'-cameras.json'),{'geometryHash':p['geometryHash'],'cameras':p['cameras']})
        summary[map_id]={'points':len(p['points']),'cameras':len(p['cameras']),
                         'portals':len(p['portals']),'nativeStatus':'pending'}
    print(json.dumps(summary,indent=2))


def make_profile(map_id, used_materials):
    path=ROOT/f'godot/multiplayer_worlds/dressing/profiles/{map_id}.json'
    if path.exists():
        p=copy.deepcopy(read(path))
    else:
        # Vesper has no production Binder profile. All labels/clock/rails are in
        # the newly compiled GLB, not another loaded legacy architectural mesh.
        p={'version':1,'map_id':map_id,'materials':[],'panels':[],'signs':[],'pockets':[],
           'preserve_materials':[],'budgets':{'material_variants':0,'panels':0,'signs':0,'motes':0}}
    p['geometry_hash']=MAPS[map_id][1]
    p['materials']=[]
    p['budgets']['material_variants']=0
    p['preserve_materials']=sorted(used_materials)
    if not 0<len(p['preserve_materials'])<=32:raise ValueError('Invalid used material set')
    return p,sha(path) if path.exists() else None


def prepare_artifacts(map_id):
    from verify_export import verify
    author,data,accepted,accepted_art,modes=entry(map_id)
    source=read(DEST/'source-manifest.json')['maps'][map_id]
    if source!=source_manifest()['maps'][map_id]:raise ValueError('Source stage needs regeneration/review')
    proof=verify(map_id)  # actual bytes; fails before creating any native stage
    stage=DEST/'artifacts'/map_id
    if (stage/'manifest.json').exists():raise ValueError('Archive prior stage before replacement')
    stage.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(author.EXPORT,stage/'candidate.glb')
    shutil.copyfile(author.AUTHORITY,stage/'authority.json')
    p=probes(map_id)
    if p['cameras']!=read(DEST/(map_id+'-cameras.json'))['cameras']:raise ValueError('Camera source drift')
    p['rays']=proof['rays']
    write(stage/'probes.json',p)
    profile,prior=make_profile(map_id,proof['usedMaterials'])
    write(stage/'profile.json',profile)
    write(stage/'geometry-proof.json',proof)
    paths=[stage/'candidate.glb',stage/'authority.json',stage/'probes.json',stage/'profile.json',
           stage/'geometry-proof.json',DEST/'profile_schema.gd',DEST/'source-manifest.json',
           DEST/(map_id+'-cameras.json')]+list(DEST.glob('*.gd'))
    paths+= [ROOT/'godot/multiplayer_worlds/dressing/binder.gd',ROOT/'godot/ambience/weather_service.gd']
    manifest={'schema':'botanical-stage/v1','status':'artifacts-verified-native-pending',
              'map':map_id,'geometryHash':data['geometryHash'],'glbSha256':sha(author.EXPORT),
              'masterSha256':sha(author.MASTER),'source':source,'modes':modes,
              'acceptedProfileSha256':prior,'files':{res(path):sha(path) for path in paths},
              'nativeStatus':'pending','parserStatus':'pending',
              'scope':'Test-only WorldMap authority + new complete GLB + production Binder/Weather; no registration or promotion'}
    write(stage/'manifest.json',manifest)  # readiness written last
    print(json.dumps(manifest,indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    group=parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--source',action='store_true')
    group.add_argument('--map',choices=MAPS)
    args=parser.parse_args()
    if args.source:prepare_source()
    else:prepare_artifacts(args.map)
