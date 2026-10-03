"""Pin real Godot-generated staged sidecars, retaining their actual native UID."""
import argparse
from config import DEST, MAPS, HERE, sha, write

def pin(map_id):
    path=DEST/'artifacts'/map_id/'candidate.glb.import'
    text=path.read_text();before=sha(path)
    for key,old,new in [('meshes/force_disable_compression','false','true'),('meshes/generate_lods','true','false')]:
        if key+'='+old not in text and key+'='+new not in text:raise ValueError('Unexpected native import setting '+key)
        text=text.replace(key+'='+old,key+'='+new)
    path.write_text(text)
    write(HERE/'evidence'/map_id/'import-policy.json',{'beforeSha256':before,'afterSha256':sha(path),
        'policy':'Actual Godot-generated UID retained; full-precision geometry, no generated LOD substitution; embedded PNG readback checked natively'})

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('map',choices=MAPS);pin(parser.parse_args().map)
