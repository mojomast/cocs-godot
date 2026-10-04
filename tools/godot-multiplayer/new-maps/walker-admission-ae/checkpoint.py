"""AE read-only inclined checkpoint; reuse AD physical checks without raw edits."""
import datetime,hashlib,json
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
def main():
    analyzer=HERE.parent/'walker-admission-ad/analyze_ad.py'
    code=analyzer.read_text()
    # Routing and grant metadata only: every physical/count/shape/clock/response
    # assertion remains exactly the reviewed AD analyzer's assertion.
    replacements={
        "godot/tests/walker_admission/admission-AD-01":"godot/tests/walker_admission/admission-ae-01",
        "grant['allowedGroups']==['inclined-landing-rejections']":"grant['allowedGroups']==['inclined-landing-rejections','positive-step-admission']",
        "evidence/trace-analysis.json":"evidence/inclined-replay.json"}
    for old,new in replacements.items():
        assert code.count(old)==1,old
        code=code.replace(old,new)
    scope={'__file__':str(HERE/'adapted_analyzer.py'),'__name__':'ae_checkpoint_replay'}
    exec(compile(code,str(analyzer),'exec'),scope)
    scope['main']()
    p=ROOT/'godot/tests/walker_admission/admission-ae-01'
    sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
    d=json.loads((p/'inclined-landing-rejections-result.json').read_text())
    g=json.loads((p/'grant.json').read_text());s=json.loads((p/'source.json').read_text())
    assert d['grantId']==g['grantId']=='MOTH-BLENDER-20261004-AE'
    assert d['grantReceiptSha256']==sha(p/'grant.json') and d['sourceSha256']==sha(p/'source.json')==g['sourceSha256']
    log=(p/'inclined-landing-rejections-supervisor.log').read_text()
    assert log.strip()=='Godot Engine v4.5.2.stable.official.6ce3de25a - https://godotengine.org'
    assert not (p/'positive-step-admission-result.json').exists()
    receipt={'status':'PASS: fresh AE inclined evidence reviewed before positive invocation',
        'reviewUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'grantId':g['grantId'],'grantSha256':sha(p/'grant.json'),'sourceSha256':sha(p/'source.json'),
        'nativeResultSha256':sha(p/'inclined-landing-rejections-result.json'),'replaySha256':sha(HERE/'evidence/inclined-replay.json'),
        'reviewedADAnalyzerSha256':sha(analyzer),'adaptations':replacements,'ABLineage':s['abLineage'],
        'observations':['4/4 pairs; 8 completed profiles','1012 input responses and160 settling responses',
          '960 exact no_continuous_flat_landing low-band/head-on target shape0 witnesses',
          'All eight profiles end with120 stalls; no accepted proposal, applied lift, fault or reset',
          'Native47-degree geometry; numeric RID/shape data; consecutive60Hz frames and timeScale1',
          'Compared baseline/candidate positions, velocity, ground state, inputs and deltas agree exactly',
          'Log contains only engine banner; no parser/runtime errors','Positive group absent at checkpoint'],
        'positiveInvocationConditionSatisfied':True,'mapWalksAuthorized':False}
    with (HERE/'evidence/inclined-checkpoint.json').open('x') as f:json.dump(receipt,f,indent=2);f.write('\n')
    print('AE inclined checkpoint PASS; positive invocation may proceed under sealed AE grant')
if __name__=='__main__':main()
