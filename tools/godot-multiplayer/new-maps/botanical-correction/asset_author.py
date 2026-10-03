"""Successor-only author. `plan` is pure; build/reopen require a FUTURE grant.

No supervisor or queue submission is performed by this entrypoint.
"""
import argparse
import json
from source_scene import ROOT,k
MAPS={'parallax-observatory':'districts-v4','vesper-viaduct':'urban-v3'}

def paths(ident):
    revision=MAPS[ident]
    out=ROOT/f'port/new-maps/{ident}/variety/{revision}'
    master=ROOT/f'tools/godot-multiplayer/new-maps/{ident}/revisions/{revision}/masters/{ident}.blend'
    return out,master

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('map',choices=MAPS)
    p.add_argument('action',choices=['plan','build','reopen-export']);a=p.parse_args()
    out,master=paths(a.map);authority=out/'authority.json';bindings=out/'bindings.json'
    if a.action=='plan':
        data=json.loads(authority.read_text());b=json.loads(bindings.read_text())
        result=k.scene_summary(data['arena'],set(b['materials']))
        result.update(geometryHash=data['geometryHash'],master=str(master.relative_to(ROOT)),
            export=str((out/(a.map+'.glb')).relative_to(ROOT)),nativeStatus='pending-new-grant')
    else:
        import kit_build
        if a.action=='build':
            if master.exists() or (out/(a.map+'.glb')).exists():raise ValueError('Archive the prior successor attempt before build')
            result=kit_build.build(ROOT,authority,bindings,master,out/(a.map+'.glb'),out/'build-report.json')
        else:
            result=kit_build.reopen_export(ROOT,master,out/(a.map+'.glb'),out/'reopen-report.json',authority)
    print(json.dumps(result,indent=2))

if __name__=='__main__':
    import sys
    if '--' in sys.argv:sys.argv=[sys.argv[0]]+sys.argv[sys.argv.index('--')+1:]
    main()
