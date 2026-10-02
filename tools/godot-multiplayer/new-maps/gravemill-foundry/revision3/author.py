"""Grant-gated candidate exporter. Writes only revision3 assets; syntax-check now.

Reuses the checkpoint batching/terrain inlay implementation with strict,
asserted substitutions; accepted author, master, GLB and receipts stay intact.
"""
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
BASE = HERE.parent / 'blender.py'
source = BASE.read_text()
def replace(old, new):
    global source
    assert old in source, 'Checkpoint author contract changed: ' + old
    source = source.replace(old, new)

replace("raw = (ROOT / 'port/native-multiplayer-worlds/worlds' / (ID + '.json')).read_bytes()", "raw = pathlib.Path(" + repr(str(HERE / 'arena.json')) + ").read_bytes()")
replace("derived = json.loads((ROOT / 'godot/multiplayer_worlds/generated' / (ID + '.json')).read_text())", "derived = json.loads(pathlib.Path(" + repr(str(HERE / 'candidate.json')) + ").read_text())")
replace("master = pathlib.Path(__file__).parent / (ID + '.blend')", "master = pathlib.Path(" + repr(str(HERE / 'gravemill-foundry.blend')) + ")")
# Redirect every runtime art destination before any bpy export can execute.
replace("art = ROOT / 'godot/multiplayer_worlds/art/worlds'", "art = pathlib.Path(" + repr(str(HERE / 'art')) + ")")
replace("/cocs-new-map-foundry-evidence-20261002/blender'", "/cocs-new-map-foundry-evidence-20261002/revision3-blender'")
replace("for hall in data['structures']:", "for hall in data['structures']:\n    if hall['id'] == 'assay-vault':\n        continue")
start=source.index('# Fractured exterior escarpment.')
end=source.index('# Batched export keeps', start)
source=source[:start]+'''# Broad unequal geological benches rather than repeated tooth silhouettes.
for side in (-1, 1):
    for j, (x, width, depth, rise) in enumerate([(-153,78,34,31),(-63,109,52,39),(62,137,41,27),(167,63,65,46)]):
        for layer in range(3):
            z=side*(180+layer*9)
            box('outer-fault-bed-%d-%d-%d' % (side,j,layer), x+layer*4, layer*rise/3, z, width-layer*7, rise/3, depth-layer*4, 'mineral' if layer!=1 else 'ore', shear=0)
# Assay triangular frames follow its steep asymmetric roof, never the old vault.
for x in range(42,93,10):
    beam('assay-rafter-long', (x,20,26+.14*x), (x,31,40+.14*x), .22, 'soot')
    beam('assay-rafter-short', (x,31,40+.14*x), (x,21,46+.14*x), .22, 'soot')
''' +source[end:]
exec(compile(source, str(BASE), 'exec'), {'__file__': str(BASE), '__name__': '__main__'})
