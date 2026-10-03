"""Prepare R6-only runtime source. Safe now; exact art identity added after build."""
from finish import HERE,ROOT,R5,read,write,sha

def prepare():
    base=ROOT/'godot/tests/new_maps/gravemill_foundry/revision5'
    dest=ROOT/'godot/tests/new_maps/gravemill_foundry/revision6';dest.mkdir(parents=True,exist_ok=True)
    profile=read(base/'profile.json');profile['preserve_materials']+=list(read(HERE/'bindings.json'))
    write(dest/'profile.json',profile)
    for filename in ('profile_schema.gd','lights.json','probes.json'):
        (dest/filename).write_bytes((base/filename).read_bytes())
    lineage=read(base/'profile-lineage.json')
    lineage.update({'candidateProfileSha256':sha((dest/'profile.json').read_bytes()),'candidateSchemaSha256':sha((dest/'profile_schema.gd').read_bytes()),
        'visualRevision':6,'policy':'Same R5 authority; distinct exact R6 art identity required in addition to geometryHash. Native visual approval pending.'})
    write(dest/'profile-lineage.json',lineage)
    stage=(base/'staged.gd').read_text().replace('R5','R6').replace('/revision5/','/revision6/')
    stage=stage.replace('art/revisions/gravemill-foundry-r5.glb','art/revisions/gravemill-foundry-r6.glb')
    stage=stage.replace('binder._diagnostics.preserved.size() == 11','binder._diagnostics.preserved.size() == 18')
    marker='\tvar data := read_json(AUTHORITY)'
    assert marker in stage
    stage=stage.replace(marker,marker+'\n\tvar identity := read_json(DIR + "art-identity.json")\n\tassert(identity.visualRevision == 6 and identity.geometryHash == data.geometryHash)\n\tassert(identity.artHash is String and identity.artHash.length() == 64)\n\tassert(FileAccess.get_sha256(ART) == identity.artHash)')
    stage=stage.replace('\treturn world','\tworld.set_meta("visualRevision", 6)\n\tworld.set_meta("artHash", identity.artHash)\n\treturn world')
    (dest/'staged.gd').write_text(stage)
    capture=(base/'capture.gd').read_text().replace('/revision5/','/revision6/').replace('candidate-runtime-r5','candidate-runtime-r6').replace('R5','R6')
    capture=capture.replace('const Weather =','const StageR5 = preload("res://tests/new_maps/gravemill_foundry/revision5/staged.gd")\nconst Weather =')
    capture=capture.replace('accepted-finish-before','staged-r5-before')
    before='\t\t\tdata = Stage.read_json("res://multiplayer_worlds/generated/gravemill-foundry.json")\n\t\t\tworld = Stage.WorldMap.new()\n\t\t\tholder.add_child(world)\n\t\t\tassert(world.build(data))'
    assert before in capture
    capture=capture.replace(before,'\t\t\tdata = Stage.read_json(StageR5.AUTHORITY)\n\t\t\tworld = StageR5.make_world(holder)')
    capture=capture.replace('"geometryHash":data.geometryHash,','"geometryHash":data.geometryHash,\n\t\t\t\t"visualRevision":6 if variant == "candidate-runtime-r6" else 5,"artHash":FileAccess.get_sha256(Stage.ART if variant == "candidate-runtime-r6" else StageR5.ART),')
    # A fresh complete run is required; no reuse of R5 capture records.
    (dest/'capture.gd').write_text(capture)
    print('R6 staged sources prepared; art-identity.json requires the future actual build')

if __name__=='__main__':prepare()
