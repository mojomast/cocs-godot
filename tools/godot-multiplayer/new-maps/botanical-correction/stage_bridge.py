"""Successor attempt adapter. Source-only setup now; artifact stage later.

Never starts a supervisor, engine, server, or heavy job. Build entrypoints are
run separately under the next grant's owned, bounded supervisor.
"""
import argparse
import copy
import hashlib
import itertools
import json
import re
import shutil
import subprocess
import sys
from stage_config import HERE,ROOT,NATIVE,MAPS,TEMPLATES,paths,source,sha,read,write,res,BLENDER,GODOT

def render_scripts(attempt,ident):
    _,dest=paths(attempt,ident);prefix=res(dest)+'/'
    scripts={}
    for name,digest in TEMPLATES.items():
        path=ROOT/f'godot/tests/new_maps/botanical_stage/{name}.gd'
        if sha(path)!=digest:raise ValueError('Approved U template changed: '+name)
        text=path.read_text().replace('res://tests/new_maps/botanical_stage/',prefix)
        if name=='profile_schema':
            text=re.sub(r'const IDENTITIES := \{.*?\}', 'const IDENTITIES := '+json.dumps({k:v[1] for k,v in MAPS.items()},indent=2),text,count=1,flags=re.S)
        if name=='staged':
            text=text.replace('return DIR + "artifacts/" + id + "/"','return DIR')
            text=text.replace('assert(Schema.IDENTITIES.has(id))',f'assert(id == "{ident}")')
        if name=='physics':
            text=text.replace('var query := PhysicsShapeQueryParameters3D.new()',
                'capsule.radius = .42 if str(p.kind).begins_with("successor-") else .41\n\t\tcapsule.height = 1.8 if str(p.kind).begins_with("successor-") else 1.7\n\t\tvar query := PhysicsShapeQueryParameters3D.new()')
            text=text.replace('origin+Vector3.UP*.9','origin+Vector3.UP*(capsule.height/2.0+.05)')
        # Actual native receipts and PNGs are write-once even when invoked by hand.
        text=re.sub(r'(\t)var file := FileAccess.open\((.*),FileAccess.WRITE\)',
            r'\1assert(not FileAccess.file_exists(\2), "Receipt exists; use a new attempt")\n\1var file := FileAccess.open(\2,FileAccess.WRITE)',text)
        text=text.replace('assert(root.get_texture().get_image().save_png(path)==OK)',
            'assert(not FileAccess.file_exists(path), "Capture exists; use a new attempt")\n\t\t\tassert(root.get_texture().get_image().save_png(path)==OK)')
        scripts[name+'.gd']=text
    return scripts

def setup(attempt,ident):
    out,dest=paths(attempt,ident)
    if out.exists() or dest.exists():raise FileExistsError('Attempt/map already exists; retain it and select another attempt')
    src,data=source(ident)
    accepted=ROOT/f'godot/multiplayer_worlds/generated/{ident}.json'
    art=ROOT/f'godot/multiplayer_worlds/art/{ident}/{ident}.glb'
    if ident=='vesper-viaduct':art=ROOT/f'godot/multiplayer_worlds/art/worlds/{ident}.glb'
    probes=json.loads(subprocess.check_output(['node',str(HERE/'stage_probes.mjs'),str(src/'authority.json'),str(accepted)],cwd=ROOT))
    scripts=render_scripts(attempt,ident)
    catalog=(ROOT/'godot/multiplayer_worlds/catalog.gd').read_text()
    modes=json.loads(re.search(r'"'+re.escape(ident)+r'":\s*(\[[^\]]+\])',catalog).group(1))
    if len(modes)!=(5 if ident=='helix-conservatory' else 6):raise ValueError('Mode support drift')
    dependencies=[ROOT/'godot/multiplayer_worlds/dressing/binder.gd',ROOT/'godot/multiplayer_worlds/dressing/profile.gd',
        ROOT/'godot/multiplayer_worlds/map.gd',ROOT/'godot/ambience/weather_service.gd',ROOT/'godot/ambience/weather_look.gd']
    dependencies+=list(HERE.glob('*.py'))+list(HERE.glob('*.mjs'))
    dependencies+=[ROOT/'tools/godot-multiplayer/new-maps/map_variety'/n for n in
        ['kit_build.py','kit_expander.py','source_geometry.py','base_craft.py','export_audit.py','glb_geometry.py']]
    profile=ROOT/f'godot/multiplayer_worlds/dressing/profiles/{ident}.json'
    if profile.exists():dependencies.append(profile)
    dependencies+=[ROOT/'tools/godot-multiplayer/new-maps/botanical-stage/probes.mjs',ROOT/'tools/godot-multiplayer/new-maps/botanical-stage/geometry.py']
    dependencies+=[ROOT/'tools/map-variety-pipeline/blender_kit.py',ROOT/'tools/map-variety-pipeline/material_adapter.py']
    out.mkdir(parents=True);dest.mkdir(parents=True)
    for name in ['authority.json','bindings.json']:shutil.copyfile(src/name,out/name)
    for name,text in scripts.items():(dest/name).write_text(text)
    write(dest/'source-probes.json',probes)
    write(out/'source.json',{'attempt':attempt,'map':ident,'geometryHash':data['geometryHash'],'recipeHash':data['recipeHash'],
        'reviewedSourceBoundary':'parent 6e1d4b1e: a22e8956/6fc988a9/231fe1e4/6e1d4b1e; isolated f358e497/3002a9ba/da2e53eb/4136bb4a',
        'authoritySha256':sha(src/'authority.json'),'bindingsSha256':sha(src/'bindings.json'),
        'glbSha256':None,'masterSha256':None,'artifactStatus':'pending-build','nativeStatus':'pending',
        'source':{'acceptedAuthority':res(accepted),'acceptedAuthoritySha256':sha(accepted),
            'acceptedGeometryHash':read(accepted)['geometryHash'],'acceptedArt':res(art),'acceptedArtSha256':sha(art)},
        'modes':modes,'dependencies':{str(p.relative_to(ROOT)):sha(p) for p in dependencies},
        'setupFiles':{str(p.relative_to(ROOT)):sha(p) for p in [*dest.glob('*.gd'),dest/'source-probes.json',out/'authority.json',out/'bindings.json']}})
    print('Source-only setup:',attempt,ident,'points',len(probes['points']),'cameras',len(probes['cameras']),'no ready manifest')

def validate_setup(attempt,ident):
    out,dest=paths(attempt,ident);_,data=source(ident);record=read(out/'source.json')
    if (record['attempt'],record['map'],record['geometryHash'],record['recipeHash'])!=(attempt,ident,data['geometryHash'],data['recipeHash']):raise ValueError('Wrong attempt/source identity')
    for p,digest in (record['dependencies']|record['setupFiles']).items():
        if sha(ROOT/p)!=digest:raise ValueError('Attempt source drift: '+p)
    for field in ['acceptedAuthority','acceptedArt']:
        if sha(ROOT/'godot'/record['source'][field][6:])!=record['source'][field+'Sha256']:raise ValueError('Accepted baseline drift')
    return out,dest,record

def artifact_proof(attempt,ident):
    out,dest,record=validate_setup(attempt,ident)
    master=out/'masters'/f'{ident}.blend';glb=out/f'{ident}.glb'
    # Required actual receipts first; source setup can never manufacture readiness.
    for p in [master,glb,out/'build-report.json',out/'reopen-report.json',out/'evaluated-proof.json']:
        if not p.is_file():raise FileNotFoundError(p)
    import verify_future
    verify_future.paths=lambda m: (out,master) if m==ident else (_ for _ in ()).throw(ValueError('Map mismatch'))
    verify_future.verify(ident)
    from export_audit import audit_glb
    from geometry import glb_triangles,RayIndex,authority_triangles,normal,center,cross,sub,length
    from source_geometry import CaptureKit,world_vertices,SOLIDS
    import kit_expander,kit_build
    data=read(out/'authority.json');bindings=read(out/'bindings.json');measured=read(out/'evaluated-proof.json')
    build=read(out/'build-report.json');reopen=read(out/'reopen-report.json')
    for report in [build,reopen]:
        if report['geometryHash']!=record['geometryHash']:raise ValueError('Stale actual build receipt')
    if reopen['glbSha256']!=sha(glb):raise ValueError('Stale reopen bytes')
    audit=audit_glb(glb,ROOT,bindings,expected_materials=build['exportAudit']['usedMaterials'],expected_triangles=len(measured['exportTriangles']))
    rows=glb_triangles(glb.read_bytes());visual=RayIndex([r['vertices'] for r in rows]);authority=RayIndex(authority_triangles(data['arena']))
    probes=read(dest/'source-probes.json');specs=probes.pop('raySpecs')
    for d in data['arena']['art']['kit']:
        if d['class'] not in SOLIDS:continue
        kit=CaptureKit()
        for op in kit_expander.expand_kit([d],set(bindings['materials'])):kit_build.create_assembly(kit,op)
        for obj in kit.source.objects:
            vertices=world_vertices(obj);faces=[[vertices[f[0]],vertices[f[i]],vertices[f[i+1]]] for f in obj.faces for i in range(1,len(f)-1)]
            tri=max(faces,key=lambda t:length(cross(sub(t[1],t[0]),sub(t[2],t[0]))));n=normal(tri);c=center(tri)
            specs.append({'id':'solid:'+obj.name,'kind':'solid','origin':[v+.15*a for v,a in zip(c,n)],'direction':[-a for a in n],'max':.3})
    rays=[]
    for spec in specs:
        collision=authority.ray(spec['origin'],spec['direction'],spec['max']);rendered=visual.ray(spec['origin'],spec['direction'],spec['max'])
        if abs(collision-rendered)>.04:raise ValueError('Actual GLB/source ray mismatch '+spec['id'])
        if spec['kind']=='aperture' and min(collision,rendered)<spec['max']-.0001:raise ValueError('Filled successor aperture '+spec['id'])
        rays.append({**spec,'authority':collision,'glb':rendered,'toleranceMetres':.04})
    probes['rays']=rays
    return record,probes,{'evaluatedExportTriangles':len(rows),'usedMaterials':audit['usedMaterials'],'exportAudit':audit,
        'geometryHash':record['geometryHash'],'glbSha256':sha(glb),'masterSha256':sha(master),'rays':rays,
        'fullAuthorityShell':'verified against actual GLB','attachments':'verified for Helix','nativeStatus':'pending'}

def stage(attempt,ident):
    out,dest=paths(attempt,ident)
    if any((dest/n).exists() for n in ['manifest.json','candidate.glb','geometry-proof.json']):raise FileExistsError('Stage attempt already used')
    record,probes,proof=artifact_proof(attempt,ident) # no stage bytes before all gates pass
    from glb_geometry import EmbeddedGlb
    from export_audit import png_pixels
    glb=out/f'{ident}.glb';container=EmbeddedGlb(glb.read_bytes());pixels={}
    for material in container.doc['materials']:
        channels={};pbr=material.get('pbrMetallicRoughness',{})
        for key,texture in [('albedo',pbr.get('baseColorTexture')),('normal',material.get('normalTexture')),('roughness',pbr.get('metallicRoughnessTexture'))]:
            if texture:
                (w,h),rgba=png_pixels(container.image_bytes(texture))
                channels[key]={'width':w,'height':h,'rgba8Sha256':hashlib.sha256(bytes(itertools.chain.from_iterable(rgba))).hexdigest()}
        pixels[material['name']]=channels
    path=ROOT/f'godot/multiplayer_worlds/dressing/profiles/{ident}.json'
    profile=copy.deepcopy(read(path)) if path.exists() else {'version':1,'map_id':ident,'panels':[],'signs':[],'pockets':[], 'budgets':{'material_variants':0,'panels':0,'signs':0,'motes':0}}
    profile.update(geometry_hash=record['geometryHash'],materials=[],preserve_materials=sorted(proof['usedMaterials']))
    profile['budgets']['material_variants']=0
    shutil.copyfile(glb,dest/'candidate.glb');shutil.copyfile(out/'authority.json',dest/'authority.json')
    for name,value in [('probes',probes),('profile',profile),('geometry-proof',proof),('expected-pixels',pixels)]:write(dest/(name+'.json'),value)
    manifest={**proof,'map':ident,'attempt':attempt,'status':'artifacts-verified-native-pending','source':record['source'],'modes':record['modes'],
        'files':{res(p):sha(p) for p in dest.iterdir() if p.is_file()},'buildReceiptSha256':sha(out/'build-report.json'),
        'reopenReceiptSha256':sha(out/'reopen-report.json'),'measurementSha256':sha(out/'evaluated-proof.json'),
        'scope':'successor test-only WorldMap/Binder/Weather; hosted/performance/manual acceptance pending'}
    manifest['files'].update({res(ROOT/p):digest for p,digest in record['dependencies'].items() if p.startswith('godot/')})
    write(dest/'manifest.json',manifest) # ready manifest written last

def pin_import(attempt,ident):
    _,dest,_=validate_setup(attempt,ident);path=dest/'candidate.glb.import'
    if (dest/'import-policy.json').exists():raise FileExistsError('Import policy already pinned')
    text=path.read_text();before=sha(path)
    for key,old,new in [('meshes/force_disable_compression','false','true'),('meshes/generate_lods','true','false')]:
        if key+'='+old not in text:raise ValueError('Unexpected actual import option '+key)
        text=text.replace(key+'='+old,key+'='+new)
    path.write_text(text)
    write(dest/'import-policy.json',{'beforeSha256':before,'afterSha256':sha(path),'nativeUID':'retained from actual Godot import'})

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['source','stage','pin-import']);p.add_argument('attempt');p.add_argument('map',choices=MAPS)
    a=p.parse_args();{'source':setup,'stage':stage,'pin-import':pin_import}[a.action](a.attempt,a.map)
