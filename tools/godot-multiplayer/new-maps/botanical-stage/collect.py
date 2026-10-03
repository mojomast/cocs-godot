"""Collect only actual artifact/native receipts; never manufacture acceptance."""
import argparse
from config import HERE, ROOT, DEST, MAPS, entry, read, write, sha, res

def collect(map_id):
    from export_audit import png_pixels
    stage=DEST/'artifacts'/map_id;manifest=read(stage/'manifest.json')
    identity=manifest['geometryHash'];manifest_sha=sha(stage/'manifest.json')
    for path,digest in manifest['files'].items():
        if sha(ROOT/'godot'/path[6:])!=digest:raise ValueError('Stale stage '+path)
    reports={name:read(stage/(name+'-report.json')) for name in ('import','physics','capture')}
    for report in reports.values():
        if report['manifestSha256']!=manifest_sha:raise ValueError('Native receipt belongs to another stage')
    physics=reports['physics']
    if physics['errors'] or physics['finiteCapsules']!=physics['expected']:raise ValueError('Native physics failed')
    views=read(DEST/(map_id+'-cameras.json'))['cameras'];images=[];pairs=[]
    captures=reports['capture']['captures']
    if len(captures)!=len(views)*2:raise ValueError('Incomplete capture pairs')
    for view in views:
        decoded=[]
        for variant in ('accepted-runtime-before','candidate-runtime-after'):
            found=[r for r in captures if r['view']==view['id'] and r['variant']==variant]
            if len(found)!=1:raise ValueError('Missing/duplicate native image')
            row=found[0];path=ROOT/'godot'/row['path'][6:]
            expected=identity if variant=='candidate-runtime-after' else manifest['source']['acceptedGeometryHash']
            if row['geometryHash']!=expected or sha(path)!=row['sha256']:raise ValueError('Image identity mismatch')
            w,h,pixels=png_pixels(path.read_bytes())
            if (w,h)!=(1280,720):raise ValueError('Wrong native dimensions')
            decoded.append(pixels);images.append({**row,'bytes':path.stat().st_size,'width':w,'height':h})
        different=sum(a!=b for a,b in zip(*decoded))
        if different==0:raise ValueError('Before/after pixels are identical')
        pairs.append({'view':view['id'],'comparison':view['comparison'],'differentPixels':different})
    author,_,_,_,_=entry(map_id)
    proof=read(stage/'geometry-proof.json')
    result={'map':map_id,'geometryHash':identity,'master':str(author.MASTER.relative_to(ROOT)),
        'masterSha256':sha(author.MASTER),'glb':str(author.EXPORT.relative_to(ROOT)),'glbSha256':sha(author.EXPORT),
        'manifestSha256':manifest_sha,'actualTriangles':proof['evaluatedExportTriangles'],
        'triangleAdvisory':proof['exportAudit']['triangleAdvisory'],'images':images,'pairs':pairs,
        'nativeReports':{name:{'path':res(stage/(name+'-report.json')),'sha256':sha(stage/(name+'-report.json'))} for name in reports},
        'finiteCapsules':physics['finiteCapsules'],'actualGeometryRays':len(physics['rays']),
        'hostedModes':'pending','humanVisualAcceptance':'pending','publicPromotion':'not performed',
        'performanceScope':'Recorded backend static views only, not dedicated-GPU or gameplay FPS'}
    write(HERE/'evidence'/map_id/'production-report.json',result)
    print(map_id,'actual triangles',result['actualTriangles'],'capsules',result['finiteCapsules'],'pairs',len(pairs))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('map',choices=MAPS);collect(parser.parse_args().map)
