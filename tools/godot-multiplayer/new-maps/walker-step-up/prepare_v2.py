"""Explicit write-once source staging. No engine execution or scheduling."""
import argparse,hashlib,json,re,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent/'botanical-post-x'))
from art_binding import preflight
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,value):
    with p.open('x') as f:json.dump(value,f,indent=2);f.write('\n')
def prepare(attempt):
    if not re.fullmatch(r'walker-step-[a-z0-9-]{1,40}',attempt):raise ValueError('fresh namespace required')
    dest=ROOT/'godot/tests/walker_step_up'/attempt
    if dest.exists() or dest.resolve()!=dest.absolute():raise ValueError('existing/symlink path')
    pins=json.loads((HERE/'post-response-provenance.json').read_text())['original15DependenciesMatchParent']
    for path,h in pins.items():
        if digest(ROOT/path)!=h:raise ValueError(path)
    pairs=preflight()
    plan=json.loads((HERE/'acceptance-plan.json').read_text())
    groups={'controls':{'trials':[]}}
    groups.update({g['id']:g for g in plan['groups']})
    res=lambda p:'res://'+str(p.relative_to(ROOT/'godot'))
    scripts=list((ROOT/'godot/tests/walker_step_up').glob('*.gd'))
    binding=ROOT/'godot/tests/new_maps/botanical_post_x/art_binding.gd'
    if digest(binding)!=hashlib.sha256(__import__('subprocess').check_output(['git','show','525b9fbe:godot/tests/new_maps/botanical_post_x/art_binding.gd'],cwd=ROOT)).hexdigest():raise ValueError('reviewed binding drift')
    dest.mkdir()
    for variant,(authority,art,_) in pairs.items():
        for suffix,data in [('.json',authority),('.glb',art)]:
            with (dest/(variant+suffix)).open('xb') as f:f.write(data)
    files={res(p):digest(p) for p in scripts+[binding]+list(dest.iterdir())}
    files.update({res(ROOT/p):h for p,h in pins.items() if p.startswith('godot/')})
    config={'version':'walker-step-driver-v2','grant':None,'autoStart':False,'queued':False,'groups':groups,'order':list(groups),
        'files':files,'productionDependencies':pins,'variants':{v:{**r,'authorityPath':res(dest/(v+'.json')),'artPath':res(dest/(v+'.glb'))} for v,(_,_,r) in pairs.items()}}
    write(dest/'source.json',config)
    print(dest)
def pin_import(dest):
    dest=Path(dest).resolve(strict=True)
    if dest.parent!=ROOT/'godot/tests/walker_step_up':raise ValueError('namespace')
    config=json.loads((dest/'source.json').read_text());records={};changes=[]
    for variant in ['accepted','candidate']:
        p=dest/(variant+'.glb.import');text=p.read_text()
        uid=re.search(r'^uid="(uid://[^"]+)"$',text,re.M)
        if not uid or 'source_file="'+config['variants'][variant]['artPath']+'"' not in text:raise ValueError('actual UID/source required')
        changed=text
        for key,value in [('meshes/force_disable_compression','true'),('meshes/generate_lods','false')]:
            changed,n=re.subn(r'^'+re.escape(key)+r'=(true|false)$',key+'='+value,changed,flags=re.M)
            if n!=1:raise ValueError(key)
        records[variant]={'uid':uid[1],'beforeSha256':digest(p),'afterSha256':hashlib.sha256(changed.encode()).hexdigest()}
        changes.append((p,changed))
    if (dest/'import-policy.json').exists():raise FileExistsError('write-once import policy')
    for p,text in changes:p.write_text(text)
    write(dest/'import-policy.json',{'status':'retained actual UIDs; authorized reimport still required','variants':records})
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('operation',choices=['prepare','pin-import']);p.add_argument('value');a=p.parse_args()
    (prepare if a.operation=='prepare' else pin_import)(a.value)
