"""Diagnostic collection contract only; never campaign acceptance."""
import math,re
PHASE='policy-receipt-probe-v1';MODE='frozen-receipt';GROUP='numeric-membership'
ENGINE='5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae'
RECEIPT='708fda878f694b46c0ae1968aca653a206ac7b39e9f3af61e0807154cf2922f4'
AI_SOURCE='59b3d7fefd040fc006f6c8d2067ae35f56d583d2a603a14534d726b5b6cf088d'
AI_GRANT='3750e6dba14af411547f9880343bb72813ea5b35275d7e4db4c7737866e561f5'
POLICY='6fab2f142b3b849b3902a506a54c95d31f19a7dfecbab0202acb1896572f757f'
EVIDENCE='acbab472c5042bbe5d3d996fe45e9d71f1114dd24bc8f6316ba891bbaacdb96f'
DIAGNOSTIC='0a73ac7874798181bfa47bcb9e99509552391577f22b60fffcc60a71eb868bab'
AI_MANIFEST='e9f57119b10ac400430573e59253d78e714832743855094013ecba57797abd96'
GRANT_KEYS={'phase','mode','allowedGroups','grantId','authorized','expiresUnix','sourceSha256','engineSha256'}
CONTROL_NAMES=['int0','int1','json0','json1','minus1','two','half','false','true','string0','string1','null','nan','inf','minus_inf']
CONTROL_TYPES=[2,2,3,3,2,2,3,1,1,4,4,0,3,3,3]
MUTANTS=['minus1','half','false','missing_record','duplicate_case','wrong_hash','wrong_outcome']
def digest(v):return isinstance(v,str) and re.fullmatch('[0-9a-f]{64}',v) is not None
def validate_grant(g,group,mode,grant_id,source_hash,engine_hash,now):
    if not isinstance(g,dict) or set(g)!=GRANT_KEYS:raise ValueError('grant schema')
    if group!=GROUP or mode!=MODE or g['phase']!=PHASE or g['mode']!=MODE or g['allowedGroups']!=[GROUP]:raise ValueError('probe scope')
    if g['authorized'] is not True or not isinstance(grant_id,str) or not grant_id or g['grantId']!=grant_id:raise ValueError('explicit grant')
    if type(g['expiresUnix']) not in (int,float) or not math.isfinite(g['expiresUnix']) or g['expiresUnix']<=now:raise ValueError('expiry')
    if not digest(source_hash) or g['sourceSha256']!=source_hash or engine_hash!=ENGINE or g['engineSha256']!=ENGINE:raise ValueError('binding')
def conclusions(r):
    controls=r['controls']
    agreement=all(c['type']==CONTROL_TYPES[i] and c['integerGuard']==(i<6) and c['originalMembership']==(i<2) and c['numericDomain']==(i<4) for i,c in enumerate(controls))
    mutants=all(not x['correctedPolicyResult'] for x in r['mutants'])
    confirmed=(not r['originalPolicyResult'] and r['correctedPolicyResult'] and agreement and mutants and r['candidateRecords']==678 and r['membershipFailures']==678)
    return agreement,mutants,confirmed
def collected(r,source_hash,grant_hash,engine_hash,clone_policy,clone_evidence):
    try:
        keys={'phase','mode','group','sourceSha256','grantSha256','engineSha256','receiptSha256','originalSourceSha256','originalGrantSha256','originalPolicySha256','originalEvidenceSha256','clonePolicySha256','cloneEvidenceSha256','probeCollected','originalPolicyResult','correctedPolicyResult','controls','mutants','candidateRecords','membershipFailures','variantAgreementPass','mutantRejectionsPass','hypothesisConfirmed','diagnostic','positiveAdmission','nativeStepAdmission','productionPromotion','candidateMapWalks'}
        if not isinstance(r,dict) or set(r)!=keys:return False
        bindings={'phase':PHASE,'mode':MODE,'group':GROUP,'sourceSha256':source_hash,'grantSha256':grant_hash,'engineSha256':engine_hash,'receiptSha256':RECEIPT,'originalSourceSha256':AI_SOURCE,'originalGrantSha256':AI_GRANT,'originalPolicySha256':POLICY,'originalEvidenceSha256':EVIDENCE,'clonePolicySha256':clone_policy,'cloneEvidenceSha256':clone_evidence}
        if engine_hash!=ENGINE or any(r.get(k)!=v for k,v in bindings.items()):return False
        if r['probeCollected'] is not True or any(r[k] is not False for k in ['positiveAdmission','nativeStepAdmission','productionPromotion']):return False
        for k in ['originalPolicyResult','correctedPolicyResult','variantAgreementPass','mutantRejectionsPass','hypothesisConfirmed']:
            if type(r[k]) is not bool:return False
        for k in ['candidateRecords','membershipFailures','candidateMapWalks']:
            if type(r[k]) is not int or r[k]<0:return False
        if r['candidateRecords']!=678 or r['membershipFailures']>678 or r['candidateMapWalks']!=0:return False
        if not isinstance(r['controls'],list) or len(r['controls'])!=len(CONTROL_NAMES):return False
        for i,c in enumerate(r['controls']):
            if not isinstance(c,dict) or set(c)!={'name','type','integerGuard','originalMembership','numericDomain'} or c['name']!=CONTROL_NAMES[i] or type(c['type']) is not int:return False
            if any(type(c[k]) is not bool for k in ['integerGuard','originalMembership','numericDomain']):return False
        if not isinstance(r['mutants'],list) or len(r['mutants'])!=len(MUTANTS):return False
        for i,m in enumerate(r['mutants']):
            if not isinstance(m,dict) or set(m)!={'name','correctedPolicyResult'} or m['name']!=MUTANTS[i] or type(m['correctedPolicyResult']) is not bool:return False
        if not valid_diagnostic(r['diagnostic'],r['originalPolicyResult']):return False
        return conclusions(r)==(r['variantAgreementPass'],r['mutantRejectionsPass'],r['hypothesisConfirmed'])
    except (KeyError,TypeError,ValueError):return False
def valid_diagnostic(d,original):
    base={'schema','originalPolicyResult','location','nativeCountersKnown','physicalCallCounts'}
    if not isinstance(d,dict) or not base<=set(d) or d['schema']!='ai-policy-source-diagnostic-v1' or d['originalPolicyResult'] is not original or d['nativeCountersKnown'] is not False or d['physicalCallCounts'] is not None:return False
    if d['location']=='undetermined':return set(d)==base
    if original:return False
    context={'caseIndex','profileIndex'}
    if type(d.get('caseIndex')) is not int or not 0<=d['caseIndex']<34 or type(d.get('profileIndex')) is not int or d['profileIndex'] not in [0,1]:return False
    if d['location']=='Evidence.profile.undetermined':return set(d)==base|context
    extra={'sourceLine','recordSection','recordIndex','checks','checkOrder','up','allowed','numericAlternative'}
    if d['location']!='Evidence.profile.lifecycle_invariant' or set(d)!=base|context|extra:return False
    if d['profileIndex']!=1 or d['sourceLine']!=139 or d['recordSection'] not in ['settle','frames'] or type(d['recordIndex']) is not int or not 0<=d['recordIndex']<(20 if d['recordSection']=='settle' else 2):return False
    if d['checkOrder']!=['returned','frame','integer_up','up_membership','parent_calls','accepted_type'] or not isinstance(d['checks'],list) or len(d['checks'])!=6 or any(type(x) is not bool for x in d['checks']) or type(d['numericAlternative']) is not bool:return False
    if all(d['checks']):return False
    def operand(o):return isinstance(o,dict) and set(o)=={'type','number'} and type(o['type']) is int and 0<=o['type']<39 and (o['number'] is None or o['type'] in [2,3] and type(o['number']) in (int,float) and math.isfinite(o['number']))
    return operand(d['up']) and isinstance(d['allowed'],list) and len(d['allowed'])==2 and all(operand(x) for x in d['allowed']) and d['allowed']==[{'type':2,'number':0},{'type':2,'number':1}]
