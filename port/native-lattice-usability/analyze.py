#!/usr/bin/env python3
"""Read-only checks of recorded public wire, native observer and X11 receipts."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]

def load(path):
    return json.loads(path.read_text())

def neutral(frame):
    c = frame['input']
    return c['x'] == c['z'] == 0 and not any(c.get(k,False) for k in ['fire','jump','reload','sprint','crouch','interact','mobility']) and 'weapon' not in c

result = {}
for scenario in sorted((HERE / 'evidence').iterdir()):
    if not scenario.is_dir(): continue
    actions = {a['action']:a for a in load(scenario / 'actions.json') if a['revision'] == 'after'}
    log = (scenario / 'after/runtime.log').read_text()
    obs = [json.loads(s[18:]) for s in log.splitlines() if s.startswith('USABILITY_OBSERVE ')]
    wire = [json.loads(s) for s in (scenario / 'after/wire.jsonl').read_text().splitlines()]
    manifest = load(scenario / 'after/manifest.json')
    inputs = [w for w in wire if w['type'] == 'input']
    recipients = [w for w in wire if w['type'] == 'recipient']
    checks = {}
    checks['bounded'] = load(scenario / 'scenario.json')['duration_seconds'] <= 100
    checks['native_error_free'] = not any(s in log for s in ['SCRIPT ERROR','ERROR:'])
    checks['ordinary_host'] = any(w['type'] == 'start' and w['config']['botCount'] == 2 for w in wire)
    for shot, grab in [('01-released',0),('02-engaged',1),('03-commands',0),('06-close-released',0),('07-held-key-click-blocked',0),('08-fresh-click-engaged',1),('09-focus-lost',0),('10-focus-return-released',0),('11-escape-released',0)]:
        checks[shot] = actions[shot]['x11']['competing_grab_status'] == grab
    checks['held_key_really_down'] = actions['07-held-key-click-blocked']['x11']['keys_down'] == ['w']
    checks['focus_transfer'] = actions['09-focus-lost']['x11']['focus'] != actions['10-focus-return-released']['x11']['focus']
    checks['native_engaged_label'] = any('\nENGAGED · LIVE' in o['label'] and o['captured'] and o['eligible'] for o in obs)
    checks['native_unfocused_label'] = any('RELEASED · UNFOCUSED' in o['label'] and not o['focused'] and not o['captured'] and not o['goal'] for o in obs)
    checks['panel_yields_hud_space'] = any(o['panel'] and not o['hud_visible'] for o in obs)
    for low, high in [('06-close-released','07-held-key-click-blocked'),('09-focus-lost','10-focus-return-released')]:
        start, end = (actions[k]['time']*1000 for k in [low, high])
        # Logger retains every input change plus periodic identical receipts.
        previous = [i for i in inputs if i['time'] <= start]
        interval = [i for i in inputs if start < i['time'] <= end]
        checks['neutral_'+low] = bool(previous) and all(neutral(i) for i in previous[-1:] + interval)
        poses = [w['own'] for w in recipients if start <= w['time'] <= end]
        checks['stationary_'+low] = len(poses) > 1 and max(((a['x']-poses[0]['x'])**2+(a['z']-poses[0]['z'])**2)**.5 for a in poses) < .01
    checks['source_movement'] = max(((w['own']['x']-recipients[0]['own']['x'])**2+(w['own']['z']-recipients[0]['own']['z'])**2)**.5 for w in recipients) > 3
    orders = [w for w in wire if w['type'] in ['order','economy']]
    checks['explicit_orders_have_source_receipts'] = bool(orders) and all(any(c['id'] == order['cardId'] and c['state'] == 'done' and c.get('ok') is True for w in recipients for c in w.get('cards',[])) for order in orders)
    checks['hashes_intact'] = all(hashlib.sha256((scenario/name).read_bytes()).hexdigest() == digest for name,digest in load(scenario/'sha256.json').items())
    checks['source_unchanged'] = all(hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == digest for name,digest in manifest['sourceHashes'].items())
    checks['cleanup'] = load(scenario/'scenario.json')['xvfb_absent'] and all(load(scenario/revision/'cleanup.json')['port_closed'] and all(load(scenario/revision/'cleanup.json')['pids_absent'].values()) and load(scenario/revision/'cleanup.json')['xdg_removed'] for revision in ['before','after'])
    final_runtime = all(hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == digest for name,digest in manifest['hashes'].items())
    item = dict(main_flow_passed=all(checks.values()),checks=checks,final_runtime=final_runtime,explicit_actions=[{k:w[k] for k in ['type','cardId','verb','target','action','role'] if k in w} for w in orders])
    if '13-small-engaged' in actions:
        item['supplemental_small_engagement_passed'] = actions['13-small-engaged']['x11']['competing_grab_status'] == 1
        item['supplemental_limit'] = 'Resize retained Python click default arguments (1220,730): outside 960x640. Image 13 is RELEASED, not ENGAGED. No retry beyond two scenarios.'
    result[scenario.name] = item
(HERE / 'analysis.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
assert all(r['main_flow_passed'] for r in result.values())
