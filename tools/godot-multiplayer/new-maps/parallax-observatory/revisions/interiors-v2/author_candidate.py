"""Prepare without Blender, or execute ONLY inside a future granted Blender job.

Accepted author/assets are read-only. The pinned author is adapted in memory;
all outputs go to this revision's output/, outside the Godot project.
"""
import hashlib
import json
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
BASE=HERE.parents[1]
OUT=HERE/'output'


def skip(name, owners):
    if name in {'SOURCE.block.'+k for k in owners}: return True
    if name in {'SOURCE.floor.'+k+'-underside' for k in owners if k.endswith('-ceiling')}: return True
    for district in ['ephemeris','pump']:
        if name.startswith(tuple(district+'.'+n for n in ['ceiling-coffer.','conduit','datum-tile.','ceiling-beam.','archive-panel.','instrument-slot.','luminaire.'])): return True
    if name.startswith(('cistern-pressure-pipe','cistern-pressure-dial','cistern-needle')): return True
    if name.startswith(tuple(d+'.'+n for d in ['archive','pump'] for n in ['engaged-pier-','pier-capital-','wall-dado-'])): return True
    return name.startswith('cabinet-rib.') and 'vault-console' in name


def prepare():
    payload=json.loads((HERE/'candidate-meshes.json').read_text())
    check=json.loads((HERE/'source-check.json').read_text())
    raw=json.dumps(payload,separators=(',',':')).encode()
    assert hashlib.sha256(raw).hexdigest()==check['candidateHash']
    source=(BASE/'blender_author.py').read_text()
    assert hashlib.sha256(source.encode()).hexdigest()==check['acceptedAuthorSha256']
    for path,key in [(ROOT/'godot/multiplayer_worlds/generated/parallax-observatory.json','generatedSourceSha256'),
                     (ROOT/'godot/multiplayer_worlds/art/parallax-observatory/parallax-observatory.glb','acceptedGlbSha256'),
                     (BASE/'parallax-observatory.blend','acceptedMasterSha256'),(HERE/'build_recipe.py','generatorSha256'),
                     (HERE/'author_candidate.py','adapterSha256'),(HERE/'prepare_native.py','nativeProbeAdapterSha256')]:
        assert hashlib.sha256(path.read_bytes()).hexdigest()==check[key],str(path)
    def replace(old,new):
        nonlocal source
        assert source.count(old)==1,old
        source=source.replace(old,new)
    replace('ROOT = Path(__file__).resolve().parents[4]',f'ROOT = Path({str(ROOT)!r})')
    replace("OUT = ROOT / 'godot/multiplayer_worlds/art' / ID",f'OUT = Path({str(OUT)!r})')
    replace("MASTER = Path(__file__).parent / (ID + '.blend')",f"MASTER = Path({str(OUT/'parallax-observatory.blend')!r})")
    replace("evidence=Path('/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002/blender-review')",f"evidence=Path({str(OUT/'blender-review')!r})")
    replace("def emit(name, vertices, faces, material='saltstone', authority=False):",
            "def emit(name, vertices, faces, material='saltstone', authority=False):\n    if REVISION_SKIP(name): return None")
    replace('triangles=sum(sum(len(f)-2 for f in faces) for verts,faces in groups.values())',
            "for part in REVISION_MESHES:\n    emit(part['name'],part['vertices'],part['triangles'],part['material'])\n"+
            "scene['candidateHash']=REVISION_HASH\ntriangles=sum(sum(len(f)-2 for f in faces) for verts,faces in groups.values())")
    replace("    obj['recipeHash']=DATA['recipeHash']","    obj['recipeHash']=DATA['recipeHash']\n    obj['candidateHash']=REVISION_HASH")
    replace("(OUT/'asset-manifest.json').write_text", "report['candidateHash']=REVISION_HASH\nreport['nativeAcceptance']='pending bounded visual pass'\n(OUT/'asset-manifest.json').write_text")
    # The prepared script remains slot-gated even when invoked directly.
    preamble=f"import sys, json\nfrom pathlib import Path\nif '--slot-granted' not in sys.argv: raise SystemExit('No heavy-slot grant')\n"
    preamble+=f"sys.path.insert(0,{str(HERE)!r})\nfrom author_candidate import skip\n"
    preamble+=f"_revision=json.loads(Path({str(HERE/'candidate-meshes.json')!r}).read_text())\n"
    preamble+=f"REVISION_MESHES=_revision['meshes']\nREVISION_HASH={check['candidateHash']!r}\nREVISION_SKIP=lambda name: skip(name,_revision['owners'])\n"
    source=preamble+source
    compile(source,'interiors-v2-prepared','exec')
    OUT.mkdir(exist_ok=True)
    (OUT/'prepared_author.py').write_text(source)
    return source


if __name__=='__main__':
    if '--prepare-only' in sys.argv:
        prepare()
        print('Prepared and compiled candidate adapter; no Blender imported or executed.')
    elif '--slot-granted' in sys.argv:
        exec(compile(prepare(),'interiors-v2-prepared','exec'),{'__name__':'__main__'})
    else:
        raise SystemExit('Use --prepare-only for source checks; Blender execution requires --slot-granted.')
