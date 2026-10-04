"""Read-only complete historical inventory replay; no stage creation or execution."""
from pathlib import Path
from prepare import ROOT,HERE,files,load,sha,lineage,verify_inputs
def verify():
    h=ROOT/'tools/godot-multiplayer/new-maps';old=load(h/'walker-parity-admission/source-provenance.json')
    paths={'AG':'walker-parity-response-ag/evidence/artifact-inventory.json','AF':'walker-snap-compare-af/evidence/artifact-inventory.json','AE':'walker-admission-ae/evidence/artifact-inventory.json','AD':'walker-admission-ad/evidence/artifact-inventory.json','AB':'walker-step-ab/evidence/artifact-inventory.json','Z':'botanical-native-z/evidence/artifact-inventory.json','AA':'parallax-observatory/revisions/districts-v4-tangent/native/AA_MANIFEST.json','AC':'parallax-observatory/revisions/districts-v4-glyph-tangents/native/AC_MANIFEST.json'}
    result={}
    for label,row in old['archives'].items():
        files.verify_archive(row['root'],'tools/godot-multiplayer/new-maps/'+paths[label],row['manifestSha256'],row['filesVerified']);result[label]=row['filesVerified']
    for label,count,digest in [('AH',42,'2eb06da778a5e7218451067592f7293180212eaedabada19885460d8c3f6f495'),('AI',40,'e9f57119b10ac400430573e59253d78e714832743855094013ecba57797abd96'),('AJ',23,'dc49cc762bb1eab492e480c429c3528d982154943f32332f9e0d35029d5a030f')]:
        namespace='walker-policy-receipt-probe-aj' if label=='AJ' else 'walker-parity-admission-'+label.lower()
        files.verify_archive(ROOT.parent/('cocs-'+namespace),'tools/godot-multiplayer/new-maps/'+namespace+'/evidence/artifact-inventory.json',digest,count);result[label]=count
    lineage(ROOT.parent/'cocs-walker-parity-admission-ak');result['AK']=51
    for label,dirname,path,digest,count in [
        ('X','cocs-botanical-source-correction','botanical-correction/x-evidence/artifact-inventory.json','440a1291201eaa3ee55f9c0218503ac4588028bfae7fee5c46364673bf94bd78',600),
        ('U','cocs-map-variety-botanical-astra','botanical-stage/evidence/artifact-inventory.json','ce0dd0ec8a87340cc31bfcb88cdfc7b11fb5aad1ce6efd317b9bb43ec22289ef',264)]:
        files.verify_archive(ROOT.parent/dirname,'tools/godot-multiplayer/new-maps/'+path,digest,count);result[label]=count
    prior=load(h/'walker-parity-admission/review-pins.json')
    for group in ['stageInputs','hostInputs','productionDependencies']:
        for n,digest in prior[group].items():
            if sha(ROOT/n)!=digest:raise ValueError('original source drift: '+n)
    for n,digest in {**old['historicalProvenanceUnchanged'],**old['frozenInputsMatchParent']}.items():
        if sha(ROOT/n)!=digest:raise ValueError('historical provenance drift: '+n)
    verify_inputs(ROOT,load(HERE/'review-pins.json'))
    return {'archives':result,'productionDependencies':len(prior['productionDependencies']),'approvedDesignUnchanged':True,'historicalProvenanceUnchanged':True}
if __name__=='__main__':
    import json
    print(json.dumps(verify(),indent=2))
