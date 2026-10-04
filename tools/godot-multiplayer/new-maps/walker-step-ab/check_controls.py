"""Read-only post-controls admission gate. No engine calls or receipt edits."""
import json,math,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent/'walker-step-up'))
from prepare_v2 import digest,write
from test_overhang_v3 import clearance,box_from_fixture
from response_oracle import budget
def main():
    p=ROOT/'godot/tests/walker_step_up/walker-step-AB-01'
    d=json.loads((p/'controls-result.json').read_text());g=json.loads((p/'grant.json').read_text())
    assert d['sourceSha256']==digest(p/'source.json') and d['grantReceiptSha256']==digest(p/'grant.json')
    assert d['grantId']==g['grantId']=='MOTH-BLENDER-20261004-AB'
    assert d['failed'] is False and d['passed']==d['attempted']==34 and d['failedTrials']==d['unrun']==0
    supervisor=json.loads((p/'controls-supervisor.json').read_text());assert supervisor['returnCode']==0 and supervisor['releasedCleanly']
    rows=[];responses=0;settles=0;max_difference=0
    for row in d['records']:
        assert row['passed'] and len(row['profiles'])==2
        a,b=row['profiles'];assert not a['experimental'] and b['experimental']
        radius=row['radius']
        for profile in [a,b]:
            shape=profile['parameters']['shape']
            assert abs(shape['radius']-radius)<1e-6 and abs(shape['height']-1.8)<1e-6
            samples=profile['settle']+([profile['launch']] if 'launch' in profile else [])+[profile['response']]
            frames=[s['clock']['frame'] for s in samples]
            assert all(y==x+1 for x,y in zip(frames,frames[1:]))
            for sample in samples:
                assert sample['clock']['physics'] and sample['clock']['hz']==60 and sample['clock']['scale']==1
                assert sample['resetCount']==1 and not sample['candidateFault']
                assert not sample['proposal'].get('accepted',False)
            responses+=1;settles+=len(profile['settle'])
            plan=profile['response']['proposal'] if profile['experimental'] else profile['observer']
            assert plan['accepted'] is False
            if row['id']=='overhang-forward':
                assert plan['reason']=='raised_path_blocked'
                stages={s['name']:s for s in plan['stages']}
                up,forward=stages['up'],stages['forward'];foot=up['from']['origin'];raised=forward['from']['origin']
                z=-.32-(radius-.35)*.6
                assert abs(foot[0])<=.0001 and 0<=foot[1]<=.0201 and abs(foot[2]-z)<=.0001
                assert .1700<=raised[1]<=.1902 and abs(raised[0])<=.0001 and abs(raised[2]-z)<=.0001
                recovery=up['travel'][1]-up['motion'][1];assert 0<=recovery<=.0201
                assert not up['hit'] and forward['hit'] and forward['validResult']
                assert all(c['collider'].endswith('/ForwardOverhang') for c in forward['contacts'])
                assert abs(forward['motion'][2]-.1)<=.0001
                values=[clearance(foot,(0,0,0),radius,box_from_fixture()),clearance(foot,up['travel'],radius,box_from_fixture()),clearance(raised,forward['motion'],radius,box_from_fixture())]
                assert values[0]>0 and values[1]>0 and values[2]<-.025
                rows.append({'radius':radius,'experimental':profile['experimental'],'foot':foot,'raisedQueryOrigin':raised,'recovery':recovery,'analyticClearancesAtNativePoses':values,'nativeUpHit':up['hit'],'nativeForwardHit':forward['hit'],'nativeContact':forward['contacts']})
        epsilon=budget(a['response']['after'],b['response']['after']);assert epsilon is not None
        error=math.dist(a['response']['after'],b['response']['after']);max_difference=max(max_difference,error)
        assert error<=epsilon and math.dist(a['response']['velocity'],b['response']['velocity'])<=epsilon
        assert a['response']['groundedAfter']==b['response']['groundedAfter']
    write(HERE/'evidence/controls-gate.json',{'passed':True,'controls':34,'profileResponses':responses,'settlingResponses':settles,'maximumPairPositionDifference':max_difference,'overhangChecks':rows,'sourceSha256':d['sourceSha256'],'resultSha256':digest(p/'controls-result.json'),'scope':'negative-response controls only; no positive step-up admission','traceLimitation':'KinematicCollision3D get_collider_shape returns an Object; serialized legacy slide shape field is Freed Object after teardown, not a shape index. PhysicsTestMotion contact colliderShape indices remain numeric.'})
    print('Controls gate passed; 34 pairs, all overhang envelopes and consecutive response clocks verified')
if __name__=='__main__':main()
