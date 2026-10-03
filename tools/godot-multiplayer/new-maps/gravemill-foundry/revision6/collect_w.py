"""W closure from actual built artifacts, native arrays/pixels and fresh frames."""
import collections
import statistics
import struct
from finish import HERE,ROOT,R5,GLB,read,write,sha,glb_parts,primitives
from material_pack import linear_rgba
from verify import verify

out=HERE/'evidence/W';native=ROOT/'godot/tests/new_maps/gravemill_foundry/revision6'
art=ROOT/'godot/multiplayer_worlds/art/revisions/gravemill-foundry-r6.glb'
plan=read(HERE/'finish-plan.json');built=verify(art.read_bytes(),plan)
assert built==read(HERE/'built-verification.json')
doc,blob=glb_parts(art.read_bytes());old,oldblob=glb_parts(GLB.read_bytes())
stream_checks=[]
for node,pi,p,streams,faces in primitives(old,oldblob):
    for name in ('POSITION','NORMAL','TANGENT'):
        a=old['accessors'][p['attributes'][name]];v=old['bufferViews'][a['bufferView']];start=v.get('byteOffset',0)
        assert doc['accessors'][p['attributes'][name]]==a and doc['bufferViews'][a['bufferView']]==v
        raw=oldblob[start:start+v['byteLength']];assert raw==blob[start:start+v['byteLength']]
        stream_checks.append({'node':node['name'],'stream':name,'sha256':sha(raw),'bytes':len(raw)})
assert read(native/'art-identity.json')['artHash']==built['artHash']
assert sha((R5/'candidate.json').read_bytes())==plan['authoritySha256']
assert sha((R5/'gravemill-foundry-revision5.blend').read_bytes())==plan['sourceMasterSha256']
reopen=read(HERE/'reopen-report.json');assert reopen['masterSha256']==sha((HERE/'gravemill-foundry-revision6.blend').read_bytes())
images=[]
for image in doc['images']:
    view=doc['bufferViews'][image['bufferView']];start=view.get('byteOffset',0);raw=blob[start:start+view['byteLength']]
    path=art.parent/('gravemill-foundry-r6_'+image['name']+'.png')
    assert path.read_bytes()==raw
    sidecar=path.with_suffix(path.suffix+'.import');settings=sidecar.read_text()
    assert 'compress/mode=0' in settings and 'mipmaps/generate=true' in settings
    images.append({'path':str(path.relative_to(ROOT)),'sha256':sha(raw),'bytes':len(raw),'importSha256':sha(sidecar.read_bytes())})
captures=read(native/'capture-report.json')['captures'];assert len(captures)==22
screens=[];pairs=collections.defaultdict(dict)
for c in captures:
    path=ROOT/'godot'/c['path'].removeprefix('res://');raw=path.read_bytes()
    assert sha(raw)==c['sha256'] and struct.unpack_from('>II',raw,16)==(1280,720)
    assert c['geometryHash']==plan['geometryHash'] and not c['weatherLook']['capped'] and c['emissionPreserved']
    assert c['artHash']==(built['artHash'] if c['visualRevision']==6 else plan['sourceGLBSha256'])
    pairs[c['view']][c['visualRevision']]=c
    screens.append({'path':str(path.resolve().relative_to(ROOT)),'sha256':sha(raw),'bytes':len(raw),'view':c['view'],'visualRevision':c['visualRevision'],'artHash':c['artHash']})
for pair in pairs.values():
    assert pair[5]['eye']==pair[6]['eye'] and pair[5]['target']==pair[6]['target'] and pair[5]['fov']==pair[6]['fov']
    assert pair[5]['sha256']!=pair[6]['sha256']
timings={}
for revision in (5,6):
    rows=[c for c in captures if c['visualRevision']==revision];times=[c['staticViewMeanFrameMs'] for c in rows]
    timings[str(revision)]={'minMs':min(times),'medianMs':statistics.median(times),'maxMs':max(times),
        'drawCallsRange':[min(c['drawCalls'] for c in rows),max(c['drawCalls'] for c in rows)],
        'peakVideoMemoryBytes':max(c['videoMemoryBytes'] for c in rows),'peakStaticMemoryBytes':max(c['staticMemoryBytes'] for c in rows),
        'backend':sorted({c['renderer'] for c in rows})}
rays=read(native/'rays-report.json');assert len(rays['rays'])==8 and rays['artHash']==built['artHash']
proof=read(out/'native-proof.json');assert proof['artHash']==built['artHash'] and len(proof['pixelChecks'])==51
undefined=proof['inheritedUndefinedTangentCorners'];assert len(undefined)==7
native_import=read(out/'native-import.json')
result={'grant':'MOTH-BLENDER-20261003-W','status':'Actual R6 production and native evidence complete; manual art acceptance and seven inherited zero-tangent substitutions remain pending',
    'visualRevision':6,'artHash':built['artHash'],'geometryHash':plan['geometryHash'],'builtVerification':built,
    'master':{'path':str((HERE/'gravemill-foundry-revision6.blend').relative_to(ROOT)),'bytes':(HERE/'gravemill-foundry-revision6.blend').stat().st_size,'sha256':reopen['masterSha256']},
    'reopen':reopen,'exactR5StreamByteProof':stream_checks,'embeddedImages':len(images),'extractedImages':images,
    'nativeImport':{'loadInstantiateMicroseconds':native_import['loadInstantiateMicroseconds'],'meshNodes':native_import['meshNodes'],'surfaces':len(native_import['surfaces']),'triangles':native_import['triangles'],'materialPixelMatches':len(proof['pixelChecks']),
        'exactPositionsAndUV':True,'maxNormalError':proof['maxNormalTangentUVError'][0],'maxDefinedTangentError':proof['maxDefinedTangentError'],
        'undefinedTangentCorners':undefined,'tangentAcceptance':'Seven R5 zero vectors cannot preserve a native direction. GLB bytes remain exact; Godot substitutions are inventoried, not silently approved.'},
    'nativeRays':rays,'priorCapsules':{'path':'godot/tests/new_maps/gravemill_foundry/revision5/physics-report.json','status':'prior immutable same-geometry R5 evidence; not rerun for W'},
    'screenshots':screens,'performance':timings,'performanceScope':'Eight-frame static-view samples on software llvmpipe, one warmed-cache headless load; not hosted gameplay or dedicated-GPU performance',
    'budget':{'trianglePolicy':'150k advisory, useful detail retained','glbBytes':len(art.read_bytes()),'bytesDesignTarget':7000000,'overDesignTarget':max(0,len(art.read_bytes())-7000000),
        'explanation':'Original streams retained with material-specific indices/UV accessors, packed material textures; no detail reduction or quantization.'},
    'manualArtAcceptance':'pending user review','publicPromotion':False,'packagesExported':False,'hostedSixModeMatrix':'not executed',
    'shipping':'R6 staged revision needs a separate explicit parent inventory transaction; package policy unchanged'}
write(out/'production-report.json',result)
print('R6_W_CLOSURE',built['artHash'],built['triangles'],'triangles',built['primitives'],'primitives',len(images),'embedded PNGs',len(screens),'native frames')
