"""Additive X exterior inspection pairs, retaining every original camera failure.

Views are labelled non-player exterior cameras. No physics points are changed.
"""
import sys
from stage_config import ROOT,HERE,res,read,write,sha,GODOT
from stage_bridge import validate_setup
VIEWS={
 'helix-conservatory': [('grounded-frame-exterior',[36,32,111],[12,20.5,85])],
 'parallax-observatory': [('east-landing-exterior',[68,27,-21],[47,14,-39])],
 'vesper-viaduct': [('roof-parapets-exterior',[45,39,29],[18,23,46]),
                    ('canal-arches-exterior',[64,14,-124],[30,3,-111]),
                    ('arcade-exterior',[-56,36,102],[-20,26,78])],
}
VIEWS_02={
 'helix-conservatory': [('grounded-frame-side',[35,22,107],[12,20,85])],
 'parallax-observatory': [('east-aperture-inspection',[51,13.45,-34],[43,13.45,-34])],
 'vesper-viaduct': [('canonical-parapet-inspection',[-65,39,-39],[-65,26,-60])],
}
def setup(attempt,ident,namespace='detail-01'):
    if namespace not in ('detail-01','detail-02'):raise ValueError('Unknown detail revision')
    out,dest,_=validate_setup(attempt,ident);detail=dest/namespace
    detail.mkdir() # write-once inspection namespace
    cameras=[{'id':name,'eye':eye,'beforeEye':eye,'target':target,'player':False,'fov':68,
        'comparison':'matched exterior inspection; not a player-height or supported-standing claim'} for name,eye,target in (VIEWS if namespace=='detail-01' else VIEWS_02)[ident]]
    write(detail/'probes.json',{'cameras':cameras,'scope':'additive exterior composition; all original probes and failed views retained'})
    text=(dest/'capture.gd').read_text().replace('Stage.directory(id)+"probes.json"','Stage.directory(id)+"detail-01/probes.json"')
    text=text.replace('Stage.directory(id)+"captures/"','Stage.directory(id)+"detail-01/captures/"')
    text=text.replace('Stage.directory(id)+("capture-report.json"','Stage.directory(id)+"detail-01/"+("capture-report.json"')
    text=text.replace('detail-01/',namespace+'/')
    (detail/'capture.gd').write_text(text)
    write(detail/'source.json',{'manifestSha256':sha(dest/'manifest.json'),'baseCaptureScriptSha256':sha(dest/'capture.gd'),
        'scriptSha256':sha(detail/'capture.gd'),'probesSha256':sha(detail/'probes.json'),'status':'capture pending'})
def render(attempt,ident,namespace='detail-01'):
    if namespace not in ('detail-01','detail-02'):raise ValueError('Unknown detail revision')
    out,dest,_=validate_setup(attempt,ident);detail=dest/namespace;record=read(detail/'source.json')
    for file,key in [(dest/'manifest.json','manifestSha256'),(detail/'capture.gd','scriptSha256'),(detail/'probes.json','probesSha256')]:
        if sha(file)!=record[key]:raise ValueError('Detail source drift')
    if (detail/'captures').exists():raise FileExistsError('Detail capture already attempted')
    wrapper=ROOT/'tools/godot-multiplayer/new-maps/gravemill-foundry/revision5/owned_capture.py';grant=wrapper.with_name('grant.py')
    if sha(wrapper)!='0c1b342c3c964a9f303da98b115beddd07914960477850d0a21b7d902b3f70b6' or sha(grant)!='8d919347092909d266ef1bca504e074a0b786e949dbb677c6f03847d59be916f':raise ValueError('Owned wrapper drift')
    kernel={'__name__':'detail_inventory','__file__':str(grant)}
    exec(compile(grant.read_text(),str(grant),'exec'),kernel)
    evidence=out/namespace;(evidence/'evidence/attempts').mkdir(parents=True)
    sys.argv=[str(wrapper),'xvfb-run','-a','-s','-screen 0 1280x720x24',GODOT,'--path','godot','--rendering-method','gl_compatibility',
        '--script',res(detail/'capture.gd'),'--','--map='+ident]
    env={'__name__':'__main__','__file__':str(wrapper),'HERE':evidence,**{k:kernel[k] for k in ['inventory','now','write']}}
    exec(compile(wrapper.read_text().replace('from grant import inventory,now,write,HERE',''),str(wrapper),'exec'),env)
if __name__=='__main__':{'source':setup,'render':render}[sys.argv[1]](*sys.argv[2:])
