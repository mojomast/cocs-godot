"""Source-only write-once future controller fixtures. Never starts an engine."""
import argparse
import json
import re
import subprocess
from fixture_inputs import ROOT,HERE,SOURCE_PINS,sha,write
from art_binding import preflight,inspect_pair
PINS={
 # walker.gd re-pinned 2026-10-05 for the approved floor_block_on_wall=false
 # stair-traversal fix (VESPER_STAIR_FIX_EXPERIMENT_20261005.md).
 'godot/exploration/walker.gd':'99185806ab8a233bc57e7f06e7fd3dc58877ab5cb46b7066c3ae31e0f2041cd7',
 'godot/multiplayer_worlds/map.gd':'42f7a343947a43f8de328d6b7fedc031824432d73655cc488d42c167cddac543',
 'godot/multiplayer_worlds/dressing/binder.gd':'b3e707af9da73f21b3c791c1d7deca9caad5472b422f263d9998ac961444a87d',
}
def setup(attempt):
    if not re.fullmatch(r'(?:[a-z][a-z0-9-]{2,47}|vesper-Z-[0-9]{2})',attempt):raise ValueError('Explicit fresh attempt required')
    dest=ROOT/'godot/tests/new_maps/botanical_post_x'/attempt
    if dest.resolve()!=dest.absolute() or dest.exists():raise FileExistsError('Existing/symlinked attempt refused')
    for path,digest in PINS.items():
        if sha((ROOT/path).read_bytes())!=digest:raise ValueError('Controller/WorldMap drift')
    pairs=preflight()
    config=json.loads(subprocess.check_output(['node',str(HERE/'native_cases.mjs')],cwd=ROOT))
    dest.mkdir()
    for variant,(authority,art,_) in pairs.items():
        (dest/(variant+'.json')).write_bytes(authority)
        (dest/(variant+'.glb')).write_bytes(art)
    for name in ['controller_journey.gd','art_binding.gd']:
        script=ROOT/'godot/tests/new_maps/botanical_post_x'/name
        (dest/name).write_bytes(script.read_bytes())
    res=lambda p:'res://'+str(p.relative_to(ROOT/'godot'))
    config['files']={res(ROOT/p):digest for p,digest in PINS.items()}
    config['files'].update({res(p):sha(p.read_bytes()) for p in dest.iterdir()})
    config['attempt']=attempt
    config['variants']={variant:{**record,'authorityPath':res(dest/(variant+'.json')),'artPath':res(dest/(variant+'.glb'))}
        for variant,(_,_,record) in pairs.items()}
    config['status']='exact JSON/art source pairs verified; import and runtime binding pending'
    config['scope']='60 walk-only direct Walker.step JSON/art diagnostics; no Binder/Weather, keyboard, network or map acceptance claim'
    write(dest/'source.json',config)
    print(json.dumps({'status':'SOURCE ONLY; future new grant required; no engine parsing performed',
        'commands':[{'timeoutSeconds':180,'argv':['GODOT_4_5_2','--headless','--path','godot','--script',res(dest/'controller_journey.gd'),
            '--','--fixture='+res(dest)+'/', '--case='+key]} for key in config['groups']]},indent=2))
    return dest

def pin_import(attempt):
    if not re.fullmatch(r'(?:[a-z][a-z0-9-]{2,47}|vesper-Z-[0-9]{2})',attempt):raise ValueError('Invalid attempt')
    dest=ROOT/'godot/tests/new_maps/botanical_post_x'/attempt
    if dest.resolve()!=dest.absolute():raise ValueError('Symlinked attempt')
    config=validate_prepared(dest);receipt=dest/'import-policy.json'
    if receipt.exists():raise FileExistsError('Import policy already pinned')
    changes=[];records={}
    for variant in SOURCE_PINS:
        # Validate exact selected bytes again, independent of editable manifest hashes.
        inspect_pair(variant,(dest/(variant+'.json')).read_bytes(),(dest/(variant+'.glb')).read_bytes())
        p=dest/(variant+'.glb.import');text=p.read_text()
        uid=re.search(r'^uid="(uid://[^"]+)"$',text,re.M)
        if not uid or 'source_file="'+config['variants'][variant]['artPath']+'"' not in text:raise ValueError('Actual import UID/source path required')
        imported=re.search(r'^path="(res://\.godot/imported/[^"]+)"$',text,re.M)
        if not imported or not (ROOT/'godot'/imported[1][6:]).is_file() or 'importer="scene"' not in text:raise ValueError('Actual imported scene cache required')
        changed=text
        for key,value in [('meshes/force_disable_compression','true'),('meshes/generate_lods','false')]:
            changed,count=re.subn(r'^'+re.escape(key)+r'=(true|false)$',key+'='+value,changed,flags=re.M)
            if count!=1:raise ValueError('Unexpected actual import setting '+key)
        changes.append((p,changed));records[variant]={'uid':uid[1],'sourcePath':config['variants'][variant]['artPath'],
            'beforeSha256':sha(p.read_bytes()),'afterSha256':sha(changed.encode())}
    for p,text in changes:p.write_text(text)
    write(receipt,{'status':'actual import UID retained; reimport and native readback pending','variants':records})

def validate_prepared(dest):
    config=json.loads((dest/'source.json').read_text())
    for variant in SOURCE_PINS:
        record=inspect_pair(variant,(dest/(variant+'.json')).read_bytes(),(dest/(variant+'.glb')).read_bytes())
        for key,value in record.items():
            if config['variants'][variant].get(key)!=value:raise ValueError('Prepared variant identity/count drift: '+key)
        for kind,extension in [('authorityPath','.json'),('artPath','.glb')]:
            if config['variants'][variant][kind]!='res://'+str((dest/(variant+extension)).relative_to(ROOT/'godot')):raise ValueError('Prepared resource path substitution')
    for resource,digest in config['files'].items():
        if not resource.startswith('res://'):raise ValueError('Non-resource fixture path')
        path=(ROOT/'godot'/resource[6:]).resolve(strict=True)
        if not path.is_relative_to(ROOT/'godot') or sha(path.read_bytes())!=digest:raise ValueError('Prepared source file drift')
    return config
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('attempt');p.add_argument('--pin-import',action='store_true');a=p.parse_args()
    pin_import(a.attempt) if a.pin_import else setup(a.attempt)
