"""Future owned capture adapter; no lock/grant acquisition. Never run source-only."""
import sys
from stage_config import ROOT,res,GODOT
from stage_bridge import validate_setup
def main(attempt,ident):
    out,dest,_=validate_setup(attempt,ident)
    if (dest/'captures').exists() or (dest/'capture-report.json').exists():raise FileExistsError('Capture attempt exists')
    # Reuse pinned reviewed R5 child inventory/reaping with evidence in this
    # attempt only. Executed inside the future grant supervisor's owned PGID.
    from stage_config import sha
    path=ROOT/'tools/godot-multiplayer/new-maps/gravemill-foundry/revision5/owned_capture.py'
    if sha(path)!='0c1b342c3c964a9f303da98b115beddd07914960477850d0a21b7d902b3f70b6':raise ValueError('Reviewed capture wrapper drift')
    sys.argv=[str(dest/'owned_capture.py'),'xvfb-run','-a','-s','-screen 0 1280x720x24',GODOT,'--path','godot',
        '--rendering-method','gl_compatibility','--script',res(dest/'capture.gd'),'--','--map='+ident]
    grant=path.with_name('grant.py')
    if sha(grant)!='8d919347092909d266ef1bca504e074a0b786e949dbb677c6f03847d59be916f':raise ValueError('Reviewed process inventory drift')
    kernel={'__name__':'successor_capture_inventory','__file__':str(grant)}
    exec(compile(grant.read_text(),str(grant),'exec'),kernel) # definitions only; never serve
    (out/'evidence/attempts').mkdir(parents=True,exist_ok=True)
    text=path.read_text().replace('from grant import inventory,now,write,HERE','')
    env={'__name__':'__main__','__file__':str(path),'HERE':out,**{k:kernel[k] for k in ['inventory','now','write']}}
    exec(compile(text,str(path),'exec'),env)
if __name__=='__main__':main(*sys.argv[1:])
