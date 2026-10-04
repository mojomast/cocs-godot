"""Read-only reference trace checks. Expected failure remains failed."""
import json,math,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent/'walker-step-up'))
from prepare_v2 import write,digest
def main():
    p=ROOT/'godot/tests/walker_step_up/walker-step-AB-01'
    d=json.loads((p/'reference-accepted-civic-r035-result.json').read_text())
    assert d['failed'] and d['referenceExpected'] and d['attempted']==10 and d['passed']==d['failedTrials']==5 and d['unrun']==0
    assert d['sourceSha256']==digest(p/'source.json') and d['grantReceiptSha256']==digest(p/'grant.json')
    sup=json.loads((p/'reference-accepted-civic-r035-supervisor.json').read_text());assert sup['returnCode']==1 and sup['releasedCleanly']
    binding=d['binding'];assert binding['selectedVariant']=='accepted' and binding['bothVariantsRuntimeVerified']
    for variant,triangles,meshes in [('accepted',54804,11),('candidate',64311,29)]:
        b=binding['variants'][variant]
        assert b['triangles']==triangles and b['meshInstances']==meshes
        assert b['artSha256']==digest(p/(variant+'.glb')) and b['importSidecarSha256']==digest(p/(variant+'.glb.import'))
        assert b['compressionDisabled'] and b['lodsDisabled']
        assert b['importedResourceSha256']==digest(ROOT/'godot'/b['importedResourcePath'][6:])
    total=settles=air=0;trials=[]
    for row in d['records']:
        frames=row['frames'];s=row['settle'];settles+=len(s);total+=len(frames)
        sequence=s+frames
        assert all(b['clock']['frame']==a['clock']['frame']+1 for a,b in zip(sequence,sequence[1:]))
        for sample in sequence:
            c=sample['clock'];assert c['physics'] and c['hz']==60 and c['scale']==1
            assert sample['resetCount']==1 and not sample['candidateFault'] and not sample['proposal']
        uphill=row['trial']['goal'][2]>row['trial']['start'][2]
        if uphill:
            assert not row['reached'] and row['stalled']==120 and len(frames)==127
            for sample in frames[-120:]:
                assert math.dist(sample['after'],[row['trial']['start'][0],12.0166673660278,24.7000026702881])<.0001
                assert any(c['collider']=='civic-stair-0Collider' for c in sample['collisions'])
        else:
            assert row['reached'] and frames[-1]['groundedAfter']
            assert math.dist([frames[-1]['after'][i] for i in [0,2]],[row['trial']['goal'][i] for i in [0,2]])<.15
            air+=sum(not sample['groundedAfter'] for sample in frames)
        trials.append({'id':row['trial']['id'],'passedLanding':row['reached'],'responses':len(frames),'stalled':row['stalled'],'final':frames[-1]['after']})
    write(HERE/'evidence/reference-analysis.json',{'status':'verified expected FAILED reference; no traversal promotion','responseCount':total,'settlingResponses':settles,'downhillNongroundedResponses':air,'trials':trials,'bothImportsVerified':True,'candidateMapWalksRun':0,'candidateMapWalksUnrun':60,'traceLimitation':'slide shape field stores get_collider_shape Object, not index; first-tread collider name and RID retained; no postguard success claimed'})
    print('Reference verified:',total,'responses +',settles,'settles;',air,'downhill airborne responses; remains FAILED')
if __name__=='__main__':main()
