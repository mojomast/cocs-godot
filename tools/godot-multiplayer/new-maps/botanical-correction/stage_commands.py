"""Print bounded future command specifications. Does not execute/queue them."""
import argparse
import json
from stage_config import paths,res,ROOT,BLENDER,GODOT,MAPS
SCRIPT='tools/godot-multiplayer/new-maps/botanical-correction/'
def commands(attempt,ident):
    _,dest=paths(attempt,ident);prefix=res(dest)+'/'
    jobs=[]
    def add(seconds,*argv):jobs.append({'timeoutSeconds':seconds,'cwd':str(ROOT),'environment':{'LP_NUM_THREADS':'1','OMP_NUM_THREADS':'1'},'argv':list(argv)})
    for action,seconds in [('build',1800),('reopen-export',900),('measure',900)]:
        add(seconds,BLENDER,'-b','-t','1','--python-exit-code','1','--python',SCRIPT+'attempt_job.py','--',action,attempt,ident)
    add(180,'python3','-B',SCRIPT+'stage_bridge.py','stage',attempt,ident)
    add(900,GODOT,'--headless','--single-threaded-scene','--path','godot','--editor','--import','--quit')
    add(60,'python3','-B',SCRIPT+'stage_bridge.py','pin-import',attempt,ident)
    add(900,GODOT,'--headless','--single-threaded-scene','--path','godot','--editor','--import','--quit')
    for script,seconds in [('import',120),('physics',180)]:
        add(seconds,GODOT,'--headless','--path','godot','--script',prefix+script+'.gd','--','--map='+ident)
    # The future supervisor owns the entire process group, including Xvfb.
    add(300,'python3','-B',SCRIPT+'stage_capture.py',attempt,ident)
    add(180,'python3','-B',SCRIPT+'stage_collect.py',attempt,ident)
    return jobs
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('attempt');p.add_argument('map',choices=MAPS);a=p.parse_args()
    print(json.dumps({'status':'unexecuted commands; NEW EXPLICIT GRANT AND OWNED SUPERVISOR REQUIRED','commands':commands(a.attempt,a.map)},indent=2))
