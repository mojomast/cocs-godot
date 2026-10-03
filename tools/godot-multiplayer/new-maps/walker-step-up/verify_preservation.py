"""Read-only explicit Z/X/U preservation audit; no fallback, engine or art staging."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent/'botanical-post-x'))
from verify_frozen import verify
from fixture_inputs import write
def sha(raw):return hashlib.sha256(raw).hexdigest()
def main(zroot):
    zroot=Path(zroot).resolve(strict=True)
    index='tools/godot-multiplayer/new-maps/botanical-native-z/evidence/artifact-inventory.json'
    raw=(zroot/index).read_bytes()
    assert sha(raw)=='288aaa809d4d655bd5037bec5eee7b6ea7dd8c824cb57d5382534a736cc89b38'
    files=json.loads(raw)['files'];assert len(files)==253
    for name,record in files.items():
        p=(zroot/name).resolve(strict=True);assert p.is_relative_to(zroot)
        data=p.read_bytes();assert sha(data)==record['sha256'] and len(data)==record['bytes'],name
    frozen=verify()
    old=json.loads((HERE.parent/'botanical-post-x/source-provenance.json').read_bytes())
    for name,digest in old['dependencies'].items():assert sha((ROOT/name).read_bytes())==digest,name
    write(HERE/'preservation.json',{'Z':{'explicitRoot':str(zroot),'inventorySha256':sha(raw),'files':253,'mismatches':0},
        'frozen':frozen,'original15Dependencies':old['dependencies'],'scope':'read-only source work; original Walker and all movement globals preserved'})
    print('Preserved Z253, X600, U264 and original 15 production dependencies')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('zroot');main(p.parse_args().zroot)
