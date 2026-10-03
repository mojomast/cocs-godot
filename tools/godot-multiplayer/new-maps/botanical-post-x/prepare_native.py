"""Source-only write-once future controller fixtures. Never starts an engine."""
import argparse
import json
import re
import subprocess
from fixture_inputs import ROOT,HERE,SOURCE_PINS,source,sha,write
PINS={
 'godot/exploration/walker.gd':'3015de90c925eb86093bb41086fe0725c3f6be9dbb23e3abdfb8b5d43dc440d8',
 'godot/multiplayer_worlds/map.gd':'42f7a343947a43f8de328d6b7fedc031824432d73655cc488d42c167cddac543',
}
def setup(attempt):
    if not re.fullmatch(r'[a-z][a-z0-9-]{2,47}',attempt):raise ValueError('Explicit fresh lowercase attempt required')
    dest=ROOT/'godot/tests/new_maps/botanical_post_x'/attempt
    if dest.resolve()!=dest.absolute() or dest.exists():raise FileExistsError('Existing/symlinked attempt refused')
    for path,digest in PINS.items():
        if sha((ROOT/path).read_bytes())!=digest:raise ValueError('Controller/WorldMap drift')
    for variant in SOURCE_PINS:source(variant)
    config=json.loads(subprocess.check_output(['node',str(HERE/'native_cases.mjs')],cwd=ROOT))
    dest.mkdir()
    for variant,(path,_) in SOURCE_PINS.items():(dest/(variant+'.json')).write_bytes((ROOT/path).read_bytes())
    script=ROOT/'godot/tests/new_maps/botanical_post_x/controller_journey.gd'
    (dest/'controller_journey.gd').write_bytes(script.read_bytes())
    res=lambda p:'res://'+str(p.relative_to(ROOT/'godot'))
    config['files']={res(ROOT/p):digest for p,digest in PINS.items()}
    config['files'].update({res(p):sha(p.read_bytes()) for p in dest.iterdir()})
    config['attempt']=attempt
    write(dest/'source.json',config)
    print(json.dumps({'status':'SOURCE ONLY; future new grant required; no engine parsing performed',
        'commands':[{'timeoutSeconds':180,'argv':['GODOT_4_5_2','--headless','--path','godot','--script',res(dest/'controller_journey.gd'),
            '--','--fixture='+res(dest)+'/', '--case='+key]} for key in config['groups']]},indent=2))
    return dest
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('attempt');setup(p.parse_args().attempt)
