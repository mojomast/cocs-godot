"""Explicit, pinned read-only X fixtures. Never discover or fall back to U."""
import hashlib
import json
import os
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
X_PINS={
 'godot/tests/new_maps/botanical_correction/x-03/vesper-viaduct/stair-diagnostic.json':'25942eb5b958bcf78a779f32a47f2621c31f354588adfbb356ff0ec2a157e146',
 'godot/tests/new_maps/botanical_correction/x-03/vesper-viaduct/physics-report.json':'ecb42d0cce67ba7dfc3e802f96acc8f80dd61f1a31c9ca9ba4f858b19caa123a',
 'godot/tests/new_maps/botanical_correction/x-03/vesper-viaduct/probes.json':'e8848dfbddff815cedcf0b2b6bca88a35328973ab7c1b57cf615cdc828560c73',
 'tools/godot-multiplayer/new-maps/botanical-correction/runs/x-03/parallax-observatory/parallax-observatory.glb':'6356cf895c65cec181e1c6c077118b98f3ee80cb567955b37835433971342422',
}
SOURCE_PINS={
 # 'accepted' re-pinned 2026-10-05 by the reviewed Vesper stair bevel rebuild
 # (VESPER_BEVEL_REBUILD_20261005.md). Same path, new reviewed content hash:
 # 80 civic treads pulled back by STAIR_BEVEL at their ascent edge plus 80
 # non-walkable -bevel chamfer surfaces. geometryHash
 # 27c71cc8... -> d8f7b6bb...; wall collider indices shift by +160 because the
 # bevel adds 160 surface triangles ahead of them in WorldMap.build order.
 'accepted':('godot/multiplayer_worlds/generated/vesper-viaduct.json','cafb93e54b61c223e62279abdb36e606a1d157682071264dd3753143dc56c172'),
 'candidate':('port/new-maps/vesper-viaduct/variety/urban-v3/authority.json','397cedc8f5583a229bb3f65ed94d9a8c74c30fd4132b57bd4e754299a47c67ec'),
}
def sha(raw):return hashlib.sha256(raw).hexdigest()
def x_bytes(path):
    if path not in X_PINS:raise ValueError('Unpinned X fixture')
    configured=os.environ.get('COCS_BOTANICAL_X_FIXTURE_ROOT')
    if not configured:raise ValueError('Explicit COCS_BOTANICAL_X_FIXTURE_ROOT repository root required')
    root=Path(configured).resolve(strict=True);p=(root/path).resolve(strict=True)
    if not p.is_relative_to(root):raise ValueError('Fixture escapes root')
    raw=p.read_bytes()
    if sha(raw)!=X_PINS[path]:raise ValueError('Frozen X fixture hash mismatch')
    return raw
def source(variant):
    path,digest=SOURCE_PINS[variant];raw=(ROOT/path).read_bytes()
    if sha(raw)!=digest:raise ValueError('Reviewed source authority drift')
    return json.loads(raw)
def write(path,value):
    with Path(path).open('x') as f:json.dump(value,f,indent=2,allow_nan=False);f.write('\n')
