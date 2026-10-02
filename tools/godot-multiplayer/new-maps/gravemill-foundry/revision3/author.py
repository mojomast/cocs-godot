"""Grant-gated candidate exporter. Writes only revision3 assets; syntax-check now.

Reuses the checkpoint batching/terrain inlay implementation with strict,
asserted substitutions; accepted author, master, GLB and receipts stay intact.
"""
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
BASE = HERE.parent / 'checkpoint-blender.py'
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
replace("'ore': (.12, .07, .04, 1)", "'ore': (.24, .12, .065, 1)")
replace("scene.world.color = (.12, .15, .17)", "scene.world.use_nodes = True\nscene.world.node_tree.nodes.get('Background').inputs['Color'].default_value = (.42,.48,.52,1)\nscene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value = .7")
replace("('03-crusher-throat-eye', (-117, 1.65, -60), (-59, 14, -10), 25)", "('03-crusher-throat-eye', (-94, 1.65, -51.16), (-49, 8, -27), 25)")
replace("('04-cooling-nave-eye', (-95, 13.65, 22.7), (-45, 17, 29.7), 24)", "('04-cooling-nave-eye', (-82, 13.65, 24.52), (-46, 16, 29.56), 26)")
replace("('05-assay-vault-eye', (37, 13.65, 41.18), (86, 17, 48.04), 24)", "('05-assay-vault-eye', (48, 13.65, 42.72), (85, 17, 47.9), 26)")
replace("('07-furnace-apron-eye', (113, 1.65, -22.18), (65, 20, 1.1), 24)", "('07-furnace-apron-eye', (88, 1.65, -25.68), (64, 10, -10), 26)")
start=source.index('# Fractured exterior escarpment.')
end=source.index('# Batched export keeps', start)
source=source[:start]+'''# Unequal fractured benches with oblique joints and terraced ledges.
# All vertices stay outside the traversable rectangle, unlike false rock cover.
for side in (-1, 1):
    for j, (x, width, depth, rise) in enumerate([(-153,78,34,31),(-63,109,52,39),(62,137,41,27),(167,63,65,46)]):
        for layer in range(3):
            y=layer*rise/3-5
            front=147+layer*5
            footprint=[(x-width*.5+layer*3,front+3),(x-width*.25,front),(x+width*.15,front+7),(x+width*.47-layer*2,front+2),(x+width*.54,front+depth*.7),(x+width*.2,front+depth),(x-width*.48,front+depth*.9)]
            lower=[(xx,y,side*zz) for xx,zz in footprint]
            upper=[(xx+2,y+rise/3+(i%3)*1.1,side*(zz+2)) for i,(xx,zz) in enumerate(footprint)]
            verts=lower+upper
            faces=[(i,(i+1)%7,(i+1)%7+7,i+7) for i in range(7)]+[(7,7+i,8+i) for i in range(1,6)]
            emit('fault-bench-%d-%d-%d'%(side,j,layer),verts,faces,'mineral' if layer!=1 else 'ore')
            for i in range(4):
                a,b=upper[i],upper[(i+1)%7]
                beam('fault-sediment',a,b,.12,'chalk')
# Clear-span crusher roof frames. Their lowest chord is well above standing
# actors and freight; the collision roof itself remains the exact source mesh.
for x in [-97,-84,-70,-56,-41]:
    ridge=[(-52,17),(-25,25),(-15,22),(2,32),(9,28),(23,30)]
    for (qa,ya),(qb,yb) in zip(ridge,ridge[1:]):
        beam('crusher-fold-rafter',(x,ya-.2,qa+.14*x),(x,yb-.2,qb+.14*x),.38,'soot')
        beam('crusher-truss-chord',(x,ya-1.8,qa+.14*x),(x,yb-1.8,qb+.14*x),.22,'brass')
        beam('crusher-truss-diagonal',(x,ya-.2,qa+.14*x),(x,yb-1.8,qb+.14*x),.2,'soot')
    for q,t in [(-52,17),(23,30)]:
        beam('crusher-wall-stanchion',(x,floor_y(x,q+.14*x),q+.14*x),(x,t,q+.14*x),.22,'brass')
# Kiln arch voussoirs and restrained masonry courses follow solid source faces.
for a,b in [(44,80),(80,104)]:
    for i in range(17):
        t=i/16; x=a+(b-a)*t; y=8+7*math.sin(t*math.pi)
        beam('kiln-arch-joint',(x,y,-19.035+.14*x),(x,y+.75,-19.035+.14*x),.07,'brass')
    for y in [16,18,20]:
        beam('kiln-course',(a,y,-19.04+.14*a),(b,y,-19.04+.14*b),.04,'brass')
# Assay triangular frames follow its steep asymmetric roof, never the old vault.
for x in range(42,93,10):
    beam('assay-rafter-long', (x,20,26+.14*x), (x,31,40+.14*x), .22, 'soot')
    beam('assay-rafter-short', (x,31,40+.14*x), (x,21,46+.14*x), .22, 'soot')
for x in [48,66,84]:
    for q in [32,40]:
        # Flush inspection instruments on existing lintels; not floating desks
        # or new collision-free obstructions inside the walkable rooms.
        box('assay-instrument-panel',x,16.8,q+.14*x,2.6,1.1,.035,'brass')
        box('assay-instrument-face',x,16.8,q+.14*x-.03,2.2,.7,.025,'copper')
        box('assay-status-lamp',x-.85,16.8,q+.14*x-.05,.12,.28,.02,'orange')
''' +source[end:]
exec(compile(source, str(BASE), 'exec'), {'__file__': str(BASE), '__name__': '__main__'})
