"""Collect actual Y proofs; no engine launch, no changes to historical evidence."""
import datetime
import statistics
import subprocess
from tangents import *
from production import linear_rgba

OUT=HERE/'evidence/Y'
STAGE=ROOT/'godot/tests/new_maps/gravemill_foundry/revision7'
def load(path):return json.loads(path.read_text())
def write(path,obj):path.write_text(json.dumps(obj,indent=2)+'\n')

def main():
    art=ROOT/'godot/multiplayer_worlds/art/revisions/gravemill-foundry-r7.glb'
    raw=art.read_bytes();actual=gate(raw);baseline=gate(SOURCE.read_bytes());proof=verify(SOURCE.read_bytes(),raw)
    changes=proof['changes'];allowed={i for c in changes for i in range(c['binOffset'],c['binOffset']+16)}
    differing={i for i,(a,b) in enumerate(zip(baseline.binary,actual.binary)) if a!=b}
    assert len(differing)==59 and len(allowed)==112 and differing<=allowed
    native_dir=HERE/'evidence/native-import';native=load(native_dir/'native-import.json');stream=(native_dir/'native-streams.bin').read_bytes()
    for c in changes:
        incident=c['incidents'][0];matches=[]
        for s in native['surfaces']:
            if s['material']!=incident['material']:continue
            count=s['vertices'];offset=s['offset']
            # Coincident position/normal/UV can legitimately have different w.
            # Match the actual incident oriented triangle, not just its vertex.
            indices=struct.unpack_from('<'+'I'*s['indices'],stream,offset+count*48)
            incident_vertices=[]
            for f in range(0,len(indices),3):
                face=list(reversed(indices[f:f+3]))
                for rotation in range(3):
                    oriented=face[rotation:]+face[:rotation]
                    ps=[struct.unpack_from('<3f',stream,offset+i*12) for i in oriented]
                    uvs=[struct.unpack_from('<2f',stream,offset+count*24+i*8) for i in oriented]
                    if ps==[tuple(p) for p in incident['trianglePositions']] and uvs==[tuple(u) for u in incident['triangleUV']]:
                        incident_vertices.append((oriented[incident['corner']],f//3,(2-(rotation+incident['corner'])%3)))
            for i,native_face,native_corner in incident_vertices:
                position=struct.unpack_from('<3f',stream,offset+i*12)
                if position!=tuple(incident['position']):continue
                normal=struct.unpack_from('<3f',stream,offset+count*12+i*12)
                uv=struct.unpack_from('<2f',stream,offset+count*24+i*8)
                if uv!=tuple(incident['uv']) or max(abs(a-b) for a,b in zip(normal,incident['normal']))>.0002:continue
                tangent=struct.unpack_from('<4f',stream,offset+count*32+i*16)
                matches.append({'node':s['node'],'surface':s['surface'],'face':native_face,'corner':native_corner,'vertex':i,'position':position,'normal':normal,'uv':uv,'tangent':tangent})
        assert len(matches)==1,(c,matches)
        t=matches[0]['tangent'];assert max(abs(a-b) for a,b in zip(t,c['tangent']))<=.0002 and t[3]==c['tangent'][3]
        c['native']=matches[0];c['nativeMaxTangentError']=max(abs(a-b) for a,b in zip(t,c['tangent']))
    write(OUT/'seven-corner-native-map.json',{'artHash':sha(raw),'scope':'Actual Y native readback mapped by material and full oriented incident triangle position/UV, then bounded normal','changes':changes})
    captures=load(STAGE/'capture-report.json')['captures'];targeted=load(STAGE/'targeted-capture-report.json')['captures']
    assert len(captures)==22 and len(targeted)==4
    for r in captures+targeted:
        path=ROOT/'godot'/r['path'].removeprefix('res://');image=path.read_bytes()
        assert sha(image)==r['sha256'] and struct.unpack_from('>II',image,16)==(1280,720)
        assert r['geometryHash']==AUTHORITY and r['artHash']==(sha(raw) if r['visualRevision']==7 else SOURCE_SHA)
        assert r['emissionPreserved'] and not r['weatherLook']['capped'] and not r['dressing']['errors']
    pairs=[]
    for rows in (captures,targeted):
        for old in [r for r in rows if r['visualRevision']==6]:
            new=next(r for r in rows if r['visualRevision']==7 and r['view']==old['view'])
            assert all(old[k]==new[k] for k in ('eye','target','fov','geometryHash','captureScriptSha256','weather'))
            pixels=[]
            for row in (old,new):pixels.append(linear_rgba((ROOT/'godot'/row['path'].removeprefix('res://')).read_bytes())[2])
            changed=sum(pixels[0][i:i+4]!=pixels[1][i:i+4] for i in range(0,len(pixels[0]),4))
            pairs.append({'view':old['view'],'before':old['path'],'after':new['path'],'beforeStatus':'Fresh staged R6 comparison, not accepted-original art',
                'changedPixels':changed,'totalPixels':1280*720,'meaning':'Numeric image differences may include render/resource-order effects; per-corner native readback is the tangent correctness proof'})
    extracted=[]
    for image in actual.doc['images']:
        view=actual.doc['bufferViews'][image['bufferView']];offset=view.get('byteOffset',0)
        payload=actual.binary[offset:offset+view['byteLength']]
        path=art.parent/('gravemill-foundry-r7_'+image['name']+'.png');assert path.read_bytes()==payload
        extracted.append({'path':str(path.relative_to(ROOT)),'sha256':sha(payload)})
    assert len(extracted)==36
    performance={}
    for variant in ('staged-r6-before','candidate-runtime-r7'):
        rows=[r for r in captures if r['variant']==variant];ms=[r['staticViewMeanFrameMs'] for r in rows]
        performance[variant]={'backend':sorted({r['renderer'] for r in rows}),'staticViewMsMinMedianMax':[min(ms),statistics.median(ms),max(ms)],
            'drawCallsMinMax':[min(r['drawCalls'] for r in rows),max(r['drawCalls'] for r in rows)],
            'peakVideoMemoryBytes':max(r['videoMemoryBytes'] for r in rows),'peakStaticMemoryBytes':max(r['staticMemoryBytes'] for r in rows)}
    immutable=load(R6/'evidence/W/final-manifest.json')['files']
    for path,row in immutable.items():assert sha((ROOT/path).read_bytes())==row['sha256'],path
    historical={}
    for name in ('source-report.json','source-tests.json','corrective-validation.json','queue.json'):
        p=HERE/name;assert p.read_bytes()==subprocess.check_output(['git','show','10d9938f:'+str(p.relative_to(ROOT))],cwd=ROOT)
        historical[name]=sha(p.read_bytes())
    write(OUT/'production-report.json',{'grant':'MOTH-BLENDER-20261003-Y','time':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'artHash':sha(raw),'artBytes':len(raw),'masterSha256':sha((HERE/'gravemill-foundry-revision7.blend').read_bytes()),'masterBytes':(HERE/'gravemill-foundry-revision7.blend').stat().st_size,
        'sourceR6ArtHash':SOURCE_SHA,'geometryHash':AUTHORITY,'triangles':87566,'meshNodes':16,'primitives':32,'materials':18,'embeddedImages':36,
        'BINChangedBytes':len(differing),'BINPermittedBytePositions':len(allowed),'allOtherBINBytesIdentical':True,'JSONSuccessorMetadataAndContainerLengthChanged':True,
        'actualBuild':load(HERE/'build-report.json'),'freshMasterReopen':load(HERE/'reopen-report.json'),'masterInventory':load(OUT/'master-inventory.json'),
        'nativeProof':load(native_dir/'native-proof.json'),'extractedImagesByteExact':extracted,'freshNativeRays':load(STAGE/'rays-report.json'),
        'screenshotPairs':pairs,'screenshotsOriginal1280x720':26,'lifecycle':'Actual captures completed Off/Low/Full and WeatherService emission/restoration assertions; traversal uncapped',
        'warmedHeadlessLoadInstantiateMs':native['loadInstantiateMicroseconds']/1000,'performance':performance,
        'performanceScope':'Eleven short eight-frame static-view llvmpipe samples; not hosted cadence or dedicated-GPU FPS; targeted views excluded from summary',
        'imageInspection':'All 26 originals examined. No broad visual change evident. High-copper view shows subtle narrow-edge shading changes; ground sliver is not visually isolated in close field view. Pale expanses and repetitive ribbing remain prior manual-art concerns.',
        'nativeLimits':'Sampler/alpha/occlusion state not recorded by native probe; source semantic equivalence only. Full hosted mode journeys and manual art acceptance pending.',
        'frozenWFilesVerified':len(immutable),'historicalR7Hashes':historical,'shipping':'No package policy or accepted binding change; separate parent transaction required'})
    print(json.dumps({'artHash':sha(raw),'nativeProof':load(native_dir/'native-proof.json'),'performance':performance,'pairs':pairs},indent=2))

if __name__=='__main__':main()
