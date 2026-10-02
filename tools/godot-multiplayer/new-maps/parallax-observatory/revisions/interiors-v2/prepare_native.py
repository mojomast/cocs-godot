"""Source-only preparation of candidate-specific copies of accepted probes."""
from pathlib import Path
import json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
OUT=HERE/'output'
OUT.mkdir(exist_ok=True)
candidate=str(OUT/'parallax-observatory.glb')
insert='''
 var old_art := world.get_node("BlenderArtNoGameplayCollision")
 world.remove_child(old_art)
 old_art.free()
 var document := GLTFDocument.new()
 var state := GLTFState.new()
 assert(document.append_from_file(CANDIDATE_GLB,state)==OK)
 var candidate_art := document.generate_scene(state)
 assert(candidate_art!=null)
 world.add_child(candidate_art)
 world.metrics["art"]=CANDIDATE_GLB
 world.metrics["candidateHash"]=JSON.parse_string(FileAccess.get_file_as_string(CANDIDATE_GLB.get_base_dir().path_join("asset-manifest.json"))).candidateHash
'''
for name in ['physics','inspection']:
    source=(ROOT/f'godot/tests/new_maps/parallax_observatory/{name}.gd').read_text()
    needle=' check(world.build(data),"production map build")' if name=='physics' else ' assert(world.build(data))'
    assert source.count(needle)==1
    source=source.replace(needle,needle+insert)
    source=source.replace('extends SceneTree','extends SceneTree\nconst CANDIDATE_GLB = '+json.dumps(candidate))
    old='res://multiplayer_worlds/art/parallax-observatory/'
    source=source.replace(old+'parallax-observatory.glb',candidate)
    source=source.replace(old+'asset-manifest.json',str(OUT/'asset-manifest.json'))
    source=source.replace('/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002/native-review',str(OUT/'native-review'))
    source=source.replace('/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002',str(OUT))
    (OUT/(name+'.gd')).write_text(source)
audit=(ROOT/'port/new-maps/parallax-observatory/audit-art.mjs').read_text()
audit=audit.replace("const root=new URL('../../../',import.meta.url)","const root=new URL("+json.dumps(ROOT.as_uri()+'/')+")")
audit=audit.replace('const dir=`godot/multiplayer_worlds/art/${id}/`', 'const dir='+json.dumps(str(OUT)+'/'))
audit=audit.replace('read(`tools/godot-multiplayer/new-maps/${id}/${id}.blend`)', 'read('+json.dumps(str(OUT/'parallax-observatory.blend'))+')')
revision=json.loads((HERE/'source-check.json').read_text())['candidateHash']
audit += '\nassert.equal(manifest.candidateHash,'+json.dumps(revision)+');\nfor(const node of gltf.nodes.filter(n=>n.mesh!==undefined)) assert.equal(node.extras.candidateHash,manifest.candidateHash);\n'
(OUT/'audit-art.mjs').write_text(audit)
print('Prepared candidate-only native probes; no Godot/import/render execution.')
