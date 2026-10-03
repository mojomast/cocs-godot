"""FUTURE GRANT ONLY Blender adapter. No process launch or lock acquisition."""
import sys
from pathlib import Path
# Blender --python does not add the script directory to sys.path like Python's
# CLI. Resolve only this checked-in adapter directory before sibling imports.
sys.path.insert(0,str(Path(__file__).resolve().parent))
from stage_bridge import validate_setup
def run(action,attempt,ident):
    out,_,_=validate_setup(attempt,ident);master=out/'masters'/f'{ident}.blend'
    import bpy
    if tuple(bpy.app.version)!=(4,5,14):raise ValueError('Pinned Blender 4.5.14 required')
    def confined(m):
        if m!=ident:raise ValueError('Wrong successor map')
        return out,master
    if action=='measure':
        import measure_future
        measure_future.paths=confined;measure_future.main(ident)
    else:
        if action not in ('build','reopen-export'):raise ValueError('Unknown job')
        report=out/('build-report.json' if action=='build' else 'reopen-report.json')
        if report.exists():raise FileExistsError('Attempt receipt exists')
        import asset_author
        asset_author.paths=confined
        sys.argv=[sys.argv[0],ident,action];asset_author.main()
if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:]
    if len(args)!=3:raise ValueError('Expected ACTION ATTEMPT MAP')
    run(*args)
