"""Future readback collection: reject stale/partial native receipts and images."""
import sys
from stage_config import ROOT,read,sha,write
from stage_bridge import validate_setup
def main(attempt,ident):
    out,dest,_=validate_setup(attempt,ident)
    if (out/'native-report.json').exists():raise FileExistsError('Collection already exists')
    from source_scene import load # initializes pure export-audit import path
    from export_audit import png_pixels
    manifest=read(dest/'manifest.json');digest=sha(dest/'manifest.json')
    if sha(out/f'{ident}.glb')!=manifest['glbSha256'] or sha(out/'masters'/f'{ident}.blend')!=manifest['masterSha256']:raise ValueError('Built artifact changed after staging')
    for filename,key in [('build-report.json','buildReceiptSha256'),('reopen-report.json','reopenReceiptSha256'),('evaluated-proof.json','measurementSha256')]:
        if sha(out/filename)!=manifest[key]:raise ValueError('Actual artifact receipt changed')
    for path,expected in manifest['files'].items():
        if sha(ROOT/'godot'/path[6:])!=expected:raise ValueError('Stage bytes changed')
    reports={name:read(dest/(name+'-report.json')) for name in ['import','physics','capture']}
    for r in reports.values():
        if r['manifestSha256']!=digest:raise ValueError('Native report belongs to another attempt')
    physics=reports['physics']
    if physics['errors'] or physics['expected']!=physics['finiteCapsules']:raise ValueError('Native physics failed')
    views=read(dest/'probes.json')['cameras'];captures=reports['capture']['captures']
    if len(captures)!=2*len(views):raise ValueError('Incomplete capture pairs')
    for view in views:
        images=[]
        for variant in ['accepted-runtime-before','candidate-runtime-after']:
            rows=[r for r in captures if r['view']==view['id'] and r['variant']==variant]
            if len(rows)!=1:raise ValueError('Missing/duplicate view')
            row=rows[0];p=dest/'captures'/f'{view["id"]}-{variant}.png'
            identity=manifest['geometryHash'] if variant=='candidate-runtime-after' else manifest['source']['acceptedGeometryHash']
            if row['geometryHash']!=identity or sha(p)!=row['sha256']:raise ValueError('Image identity mismatch')
            size,pixels=png_pixels(p.read_bytes())
            if size!=(1280,720):raise ValueError('Wrong native capture size')
            images.append(pixels)
        if images[0]==images[1]:raise ValueError('Identical before/after pixels')
    write(out/'native-report.json',{'attempt':attempt,'map':ident,'geometryHash':manifest['geometryHash'],'manifestSha256':digest,
        'nativeReports':{name:sha(dest/(name+'-report.json')) for name in reports},'pairs':len(views),'finiteCapsules':physics['finiteCapsules'],
        'hostedModes':'pending','manualVisualAcceptance':'pending','performance':'static backend measurements only; not gameplay FPS'})
if __name__=='__main__':main(*sys.argv[1:])
