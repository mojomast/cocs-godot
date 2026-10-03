"""Supplemental post-J queue. Dry planning never invokes Godot or a server."""
import argparse
import ast
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools/godot-dev'))
from finish_runner import run_bounded, isolated_environment, dependency_inventory, COHORT_LOCK
from gate_runner import save_report

GODOT = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'
UI_MARKERS = ['HOME_SEARCH_OK', 'MENU_CONTRACTS checks=', 'INPUT_BINDINGS',
              'CAMPAIGN_JOURNAL_MODEL_OK', 'CAMPAIGN_JOURNAL_INPUT_OK',
              'FIGHTING_TRAINING_FEEDBACK', 'TRAINING_LAYOUT_OK']
CONTRACTS = [
    ('fp-lifecycle','first_person/lifecycle.gd','FIRST_PERSON_LIFECYCLE',120),
    ('fp-binding','first_person/binding.gd','FIRST_PERSON_BINDING',120),
    ('fp-ads','first_person/ads_contract.gd','NATIVE_ADS_CONTRACT',120),
    ('kick-chains','first_person/kick_chains.gd','KICK_CHAINS_OK',60),
    ('sports-controls','sports/test_controls.gd','SPORTS_SYNTHETIC_CHECKS',120),
    ('sports-lifecycle','sports/lifecycle_release.gd','SPORTS_LIFECYCLE_RELEASE failures=0',120),
    ('sports-polish','sports/test_polish.gd','SPORTS_POLISH_SYNTHETIC_CHECKS',120),
    ('vehicle-controls','combined_arms/test_controls.gd','COMBINED_SYNTHETIC_CHECKS',120),
    ('vehicle-views','combined_arms/vehicle_views.gd','VEHICLE VIEWS failures=0',120),
    ('operator-legacy','source_operators/check.gd','jointWorldMatricesCompared',240),
    ('operator-grips','source_operators/grips.gd','maximumGripWorldError',240),
    ('operator-nine','operator_motion/contracts.gd','operator-motion-native',1200),
    ('operator-melee','operator_motion/melee_contracts.gd','operator-world-melee',240),
    ('operator-reduced-settings','operator_motion/reduced_settings.gd','OPERATOR_REDUCED_SETTINGS',120),
    ('operator-finish','operator_motion/finish_lifecycle.gd','OPERATOR_FINISH_LIFECYCLE_OK',120),
    ('biomes','biomes/contracts.gd','biome-model-animation',240),
    ('animation-actors','animation_pass/actors.gd','ACTOR_ANIMATION_OK',240),
    ('world-motion','world_motion/unit.gd','WORLD_MOTION_UNIT_OK',60),
    ('ordinary-motion','world_motion/ordinary_modes.gd','ORDINARY_MOTION_OK',60),
    ('campaign-motion','campaign/feel_motion.gd','CAMPAIGN_FEEL_MOTION',60),
]

def ui_cases(root):
    # Reuse the existing seven case definitions without importing its CLI or
    # invoking its lock-owning execution path. A schema change fails explicitly.
    tree = ast.parse((root/'tools/ui-review/native_queue.py').read_text())
    cases = next(ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign)
                 and any(isinstance(t, ast.Name) and t.id == 'CASES' for t in n.targets))
    if len(cases) != len(UI_MARKERS): raise ValueError('Review changed UI queue semantics')
    return [('ui-'+name, script, marker, limit) for (name, script, limit), marker in zip(cases, UI_MARKERS)]

def plan(root=ROOT, godot=GODOT, output=Path('/tmp/opencode/motion-native'), scope='contracts', grant='NEW-GRANT'):
    output = output.resolve()
    jobs = []
    def add(name, argv, timeout, marker, sources, **extra):
        jobs.append(dict(id=name, argv=argv, timeout=timeout, marker=marker,
                         requires=sources, lock_owner='queue', **extra))
    if scope == 'vehicle-live':
        add('vehicle-live',['node','tools/motion-review/vehicle_live.mjs',godot,str(output/'vehicle-live'/'evidence')],120,
            'VEHICLE_VIEW_LIVE_OK',['tools/motion-review/vehicle_live.mjs','godot/tests/sports/view_live.gd'])
        return jobs
    if scope == 'live-kick':
        add('live-kick',[sys.executable,'tools/godot-weapons/kick-live.py','--execute-native','--xvfb-tcp',
            '--grant',grant,'--godot',godot,'--output',str(output/'live-kick'/'producer')],1800,
            'passed', ['tools/godot-weapons/kick-live.py','tools/godot-weapons/kick-live-server.mjs','godot/tests/first_person/kick_live.gd'])
        jobs[-1]['lock_owner']='child'
        return jobs
    add('native-import',[godot,'--headless','--path','godot','--editor','--import','--quit'],600,None,['godot/project.godot'])
    cases = ui_cases(root)+CONTRACTS
    if scope == 'graphics':
        cases = [('operator-gallery','operator_motion/gallery.gd','OPERATOR_MOTION_GALLERY_OK captures=216',1200),
                 ('operator-melee-gallery','operator_motion/melee_gallery.gd','OPERATOR_MELEE_GALLERY',600),
                 ('kick-captures','first_person/kick_capture.gd','KICK_CAPTURE_OK captures=135',600),
                 ('kick-reduced-ads','first_person/kick_capture.gd','KICK_CAPTURE_OK captures=135',600),
                 ('ads-projection','first_person/ads.gd','NATIVE_ADS',600),
                 ('handling-captures','first_person/handling_capture.gd','FIRST_PERSON_HANDLING_CAPTURE',600)]
    for name, script, marker, timeout in cases:
        source = 'godot/tests/'+script
        args = [godot,'--headless','--path','godot','--script','res://tests/'+script]
        add('typecheck-'+name,args+['--check-only'],60,None,[source])
    for name, script, marker, timeout in cases:
        source = 'godot/tests/'+script
        args = [godot,'--headless','--path','godot','--script','res://tests/'+script]
        if name == 'fp-binding':
            args = [sys.executable,'tools/godot-dev/xvfb_run.py',godot,'--path','godot',
                    '--rendering-method','gl_compatibility','--audio-driver','Dummy','--script','res://tests/'+script]
        if scope == 'graphics':
            args = [sys.executable,'tools/godot-dev/xvfb_run.py',godot,'--path','godot',
                    '--rendering-method','gl_compatibility','--audio-driver','Dummy','--script','res://tests/'+script,
                    '--',('--motion-capture=' if name=='operator-gallery' else '--evidence-out=')+str(output/name)]
            if name=='kick-reduced-ads': args.append('--reduced-ads')
        add(name,args,timeout,marker,[source])
    return jobs

def anchor(root, jobs):
    files = {'tools/motion-review/native_queue.py','tools/ui-review/native_queue.py',
             'tools/godot-dev/finish_runner.py','tools/godot-dev/gate_runner.py'}
    missing = set()
    for job in jobs:
        inventory = dependency_inventory(root,job)
        files.update(inventory['files']); missing.update(inventory['missing'])
    # Dynamic imported anatomy and roster inputs; literal preload scan alone
    # cannot close ResourceLoader/FileAccess dependencies.
    for folder in ['godot/source_operators/generated','godot/fighting/data']:
        files.update(str(p.relative_to(root)) for p in (root/folder).glob('*') if p.is_file() and p.suffix in ['.glb','.gd','.json'])
    files.update(str(p.relative_to(root)) for p in (root/'godot/content/generated').rglob('*.json'))
    files.update(str(p.relative_to(root)) for p in (root/'godot/source_operators/moth_finish').rglob('*') if p.is_file() and p.suffix in ['.json','.png','.gd'])
    hashes = {p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in sorted(files) if (root/p).is_file()}
    return {'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
            'sha256':hashlib.sha256(json.dumps(hashes,sort_keys=True).encode()).hexdigest(),
            'files':hashes,'missing':sorted(missing)}

def assess(result, text, job):
    if result['status']=='passed' and job['marker'] and job['marker'] not in text:
        result.update(status='failed',failure_reason='missing-success-marker')
    if re.search(r'instances leaked|resources still in use|RID[^\n]*leak',text,re.I):
        result.update(status='failed',failure_reason='native-resource-leak')
    if re.search(r'failures=[1-9][0-9]*',text):
        result.update(status='failed',failure_reason='fixture-failures')
    for line in text.splitlines():
        if '{' not in line: continue
        try: payload=json.loads(line[line.index('{'):])
        except json.JSONDecodeError: continue
        if isinstance(payload,dict) and (payload.get('passed') is False or payload.get('failures')):
            result.update(status='failed',failure_reason='fixture-failures')
    return result

def execute_job(job, output, env):
    directory = output/job['id']
    directory.mkdir(parents=True,exist_ok=False)
    log = directory/'native.log'
    local = {**env,'OPERATOR_EVIDENCE':str(directory)}
    # The live producer takes the SAME lock internally. Never wrap it in a
    # second flock. run_bounded still audits/reaps all our descendant processes.
    def run():
        result = run_bounded(job['argv'],ROOT,local,log,job['timeout'])
        return assess(result,log.read_text(),job)
    if job['lock_owner']=='child': return run()
    with COHORT_LOCK.open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        return run()

def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scope',choices=['contracts','graphics','live-kick','vehicle-live'],default='contracts')
    parser.add_argument('--godot',default=GODOT)
    parser.add_argument('--output',type=Path,default=Path('/tmp/opencode/motion-native'))
    parser.add_argument('--execute',action='store_true')
    parser.add_argument('--grant',default='')
    parser.add_argument('--candidate',default='',help='Exact merged/runtime-reviewed HEAD, including operator overlay')
    parser.add_argument('--only',action='append',default=[],help='Explicit gate IDs for a bounded failure retry; no implicit import')
    parser.add_argument('--keep-going',action='store_true',help='Run independent selected gates serially after behavioral failures')
    args=parser.parse_args(argv)
    jobs=plan(godot=args.godot,output=args.output,scope=args.scope,grant=args.grant or 'NEW-GRANT')
    if args.only:
        if set(args.only)-{j['id'] for j in jobs}: parser.error('Unknown --only gate')
        jobs=[j for j in jobs if j['id'] in args.only]
    identity=anchor(ROOT,jobs)
    report={'executed':False,'scope':args.scope,'sourceAnchor':identity,'jobs':jobs,
            'runtimeCandidateNeedsOperatorOverlayMerge':not (ROOT/'godot/source_operators/melee_events.gd').exists(),'attempts':[]}
    if not args.execute:
        print(json.dumps(report,indent=2));return 0
    if not args.grant or args.candidate!=identity['head']: parser.error('New explicit grant and exact reviewed --candidate HEAD required')
    if identity['missing']: parser.error('Missing fixture dependencies')
    args.output=args.output.resolve();args.output.mkdir(parents=True,exist_ok=True)
    env={**isolated_environment(args.output),'LP_NUM_THREADS':'1'}
    report.update(executed=True,grant=args.grant,candidate=args.candidate)
    for job in jobs:
        try: result=execute_job(job,args.output,env)
        except Exception as error:
            result={'status':'failed','failure_reason':str(error)}
        report['attempts'].append({'id':job['id'],**result})
        save_report(args.output/'queue.json',report)
        if result['status']!='passed' and (not args.keep_going or result.get('cleanup',{}).get('remaining') or result.get('failure_reason') in ['interrupted','descendants-survived']): return 1
    return int(any(a['status']!='passed' for a in report['attempts']))

if __name__=='__main__': raise SystemExit(main())
