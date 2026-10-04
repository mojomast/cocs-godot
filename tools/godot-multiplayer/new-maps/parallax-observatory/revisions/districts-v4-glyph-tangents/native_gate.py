"""Complete mesh-local native proof. Geometry keys never depend on tangents."""
from successor import *

def check_streams(artifact,report,raw):
    expected,_=compile_art(frozen())
    if artifact!=expected or report['artHash']!=sha(artifact):raise ValueError('Native artifact identity changed')
    if report['triangles']!=155553 or report['meshNodes']!=39 or len(report['surfaces'])!=39:raise ValueError('Native inventory changed')
    source,_,_=census.source_faces(aa.EmbeddedGlb(artifact))
    native,inventory=census.native_faces(report,raw)
    result=census.compare(source,native);counts=result['counts']
    if counts.get('strictEquivalentFaces')!=155553 or counts['missingGeometryGroups'] or counts['ambiguousBasisGroups']:
        raise ValueError('Complete oriented native basis multiset failed: '+str(counts))
    if inventory.get('zeroT') or inventory.get('nonunitT'):raise ValueError('Invalid native tangent')
    mapped=[];parallel=0
    repaired=approved_policy.EXPECTED|{(48,v) for v in aa.VERTICES}
    for key,rows in source.items():
        pairs=census.maximum_matching(rows,native[key],lambda a,b:census.strict(a['corners'],b['corners']))
        for i,j in pairs:
            a,b=rows[i],native[key][j]
            for ca,cb in zip(a['corners'],b['corners']):
                length=census.norm(census.cross(cb['N'],cb['T'][:3]));parallel+=length<1e-12
                if cb['T'][3] not in (-1,1):raise ValueError('Non-sign native handedness')
                if (a['accessor'],ca['vertex']) in repaired:
                    if abs(census.dot(cb['N'],cb['T'][:3]))>.001 or abs(length-1)>.001:raise ValueError('Repaired native frame not orthonormal')
                    mapped.append({'accessor':a['accessor'],'vertex':ca['vertex'],'sourceFace':a['face'],'nativeNode':b['node'],'nativeFace':b['face'],'nativeVertex':cb['vertex'],'nativeT':cb['T']})
    if parallel or len(mapped)!=51 or {(r['accessor'],r['vertex']) for r in mapped}!=repaired:raise ValueError('Repaired coverage or parallel frame failure')
    return {'counts':counts,'maxLocalPNUVTError':result['maxStrictMatchedErrorsPNUVT'],'repairedMappings':mapped,'parallelNativeCorners':parallel,
        'scope':'Mesh-local only; native world transforms not recorded','universalUVBasisValidity':False,'manualAcceptance':'pending'}

def check(artifact,report,streams,stage):
    from stage import check_sidecar
    check_sidecar(stage/'candidate.glb.import')
    proof=check_streams(artifact,report,streams)
    from material_contract import verify_native_materials,pixel_identity
    g=aa.EmbeddedGlb(artifact);proof['materialFieldSets']=verify_native_materials(g,report);channels=0
    prefix='res://'+str(stage.relative_to(ROOT/'godot'))+'/'
    for mat in g.doc['materials']:
        p=mat.get('pbrMetallicRoughness',{})
        for channel,slot,components in (('albedo',p.get('baseColorTexture'),(0,1,2,3)),('normal',mat.get('normalTexture'),(0,1,2)),('roughness',p.get('metallicRoughnessTexture'),(1,2))):
            if slot is None:continue
            image=report['materials'][mat['name']]['images'][channel];path=image['path']
            if not path.startswith(prefix) or '..' in Path(path).parts:raise ValueError('Pixel path outside stage')
            data=(ROOT/'godot'/path.removeprefix('res://')).read_bytes()
            if sha(data)!=image['sha256'] or pixel_identity(g.image_bytes(slot),components)!=pixel_identity(data,components):raise ValueError('Native material pixels differ')
            channels+=1
    if proof['materialFieldSets']!=14 or channels!=39:raise ValueError('Material coverage changed')
    proof['materialChannels']=channels
    return proof
