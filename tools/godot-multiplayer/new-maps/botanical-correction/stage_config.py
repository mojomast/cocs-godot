"""Closed successor source boundary; import is inert, no artifact discovery."""
import hashlib
import json
import re
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
NATIVE=ROOT/'godot/tests/new_maps/botanical_correction'
MAPS={
 'helix-conservatory':('revision-4','f5a3d0d7b2872fa7c7fa6bb2727ee31915a717ffbc160343acf491fe3b9bc49e','87ea1588103afb516bffa5bec9ab51601eb89109ec034ac10f2947ccacf6d2e2','1e5847c04d1a18165333a900e77db33ff24017d87eb87e5efed779d59d52d2bb'),
 'parallax-observatory':('districts-v4','3a5800e89876ebcc741381802def24415d5050651c0d3b831ea8b9ec3b77b4f9','1ab621ab38da21dda40e987c5b0478f5bc3a3e9b58950ab589180ebf353b1fc2','cd62bdf5c2eafa8dfb25ef29691226c43eef0bb40ca67492110a7bc8c68f6aeb'),
 'vesper-viaduct':('urban-v3','fd8e7134c8933e908336d7b0409c66bdc90f4adc03fcfc6e596d5b4579f1c740','f22b863cab4caec974602b81548b11e7fd60e221d441e136c47c35df144220e2','397cedc8f5583a229bb3f65ed94d9a8c74c30fd4132b57bd4e754299a47c67ec'),
}
TEMPLATES={'staged':'0c1de1f61deabdb9e5d02dbeef253a667379fa87f1f584e100bea9218b8e047c',
 'import':'0b7794f4e11ffe9653b67a9b575d96964369eedb1a506705d91536d419970b3f',
 'physics':'18f4c3b5a8f85b4466c3a937a94ae50c0fb86182a04b204e18da28f106028634',
 'capture':'c930ee078e7561f14bfdc58f9d9bc93b3e0bad02862d5246545ef1e9b3932f71',
 'profile_schema':'0038fcbca5b019cde985f277a06abcb6b80a9ce30f1f20f00480a51e4c006479'}
BINDINGS={'helix-conservatory':'760122242dbf875974b4bec1646da2a60f2c5ee41bb89d3fb496896f4afbc7c2',
 'parallax-observatory':'14f7baa4fffb03cd9979eefe2bae660530ad8ac33e625a9e39a19787a66564c7',
 'vesper-viaduct':'b57feb9ee8042e57294e82ca15bac9a3c5dcbcbd0e2a9f99429ab333b670dda2'}
BLENDER='/home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender'
GODOT='/tmp/opencode/cocs-horde-e353522a-package/toolchain/Godot_v4.5.2-stable_linux.x86_64'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def write(p,data):
    with Path(p).open('x') as f:f.write(json.dumps(data,indent=2,allow_nan=False)+'\n')
def paths(attempt,ident):
    if not re.fullmatch(r'[a-z][a-z0-9-]{2,47}',attempt):raise ValueError('Attempt must be 3–48 lowercase letters/digits/hyphens, starting with a letter')
    if ident not in MAPS:raise ValueError('Unknown successor map')
    result=HERE/'runs'/attempt/ident,NATIVE/attempt/ident
    for p in result:
        if p.resolve()!=p.absolute():raise ValueError('Attempt paths must not contain symlinks')
    return result
def source(ident):
    revision,geometry,recipe,digest=MAPS[ident]
    out=ROOT/f'port/new-maps/{ident}/variety/{revision}';authority=out/'authority.json'
    if sha(authority)!=digest:raise ValueError('Reviewed authority bytes changed')
    if sha(out/'bindings.json')!=BINDINGS[ident]:raise ValueError('Reviewed material bindings changed')
    data=read(authority)
    if data['id']!=ident or data['geometryHash']!=geometry or data['recipeHash']!=recipe:raise ValueError('Wrong successor source identity')
    return out,data
def res(p):return 'res://'+str(Path(p).relative_to(ROOT/'godot'))
