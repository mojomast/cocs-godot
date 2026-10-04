"""Synthetic groups only; no native grant is supplied by this source package."""
import math,re
from evidence import campaign
PHASE='parity-admission-synthetic-v1';MODE='synthetic-controls'
GROUPS=['negative-controls','inclined-landing-rejections','positive-step-admission']
COUNTS=dict(zip(GROUPS,[34,4,4]))
KEYS={'phase','mode','allowedGroups','grantId','authorized','expiresUnix','sourceSha256','engineSha256'}
def validate(g,*,group,mode,grant_id,source_hash,engine_hash,now):
    if not isinstance(g,dict) or set(g)!=KEYS:raise ValueError('exact grant schema required')
    if g['phase']!=PHASE or g['mode']!=MODE or mode!=MODE or group not in GROUPS:raise ValueError('synthetic phase/mode/group required')
    allowed=g['allowedGroups']
    if not isinstance(allowed,list) or not allowed or any(not isinstance(x,str) or x not in GROUPS for x in allowed) or len(set(allowed))!=len(allowed) or group not in allowed:raise ValueError('explicit unique synthetic subset required')
    if allowed!=[x for x in GROUPS if x in allowed]:raise ValueError('canonical group order required')
    if g['authorized'] is not True or not isinstance(g['grantId'],str) or not grant_id or g['grantId']!=grant_id:raise ValueError('grant identity')
    if type(g['expiresUnix']) not in (int,float) or not math.isfinite(g['expiresUnix']) or g['expiresUnix']<=now:raise ValueError('expiry')
    for actual,expected in [(g['sourceSha256'],source_hash),(g['engineSha256'],engine_hash)]:
        if not isinstance(actual,str) or not re.fullmatch('[a-f0-9]{64}',actual) or actual!=expected:raise ValueError('hash binding')
def count(value,n):return type(value) in (int,float) and value==n
def successful(r,group,source_hash,grant_hash,engine_hash):
    if group not in GROUPS:return False
    if not isinstance(r,dict) or r.get('phase')!=PHASE or r.get('mode')!=MODE or r.get('group')!=group or r.get('scope')!='synthetic-admission':return False
    if r.get('sourceSha256')!=source_hash or r.get('grantSha256')!=grant_hash or r.get('engineSha256')!=engine_hash:return False
    if r.get('failed') is not False or r.get('passed') is not True or r.get('nativeStepAdmission') is not False or r.get('productionPromotion') is not False:return False
    n=COUNTS[group]
    required={'attemptedPairs':n,'completedPairs':n,'passedPairs':n,'failedPairs':0,'interruptedPairs':0,'unrunPairs':0,'attemptedProfiles':2*n,'completedProfiles':2*n,'failedProfiles':0,'interruptedProfiles':0,'unrunProfiles':0,'candidateMapWalks':0}
    if any(not count(r.get(k),v) for k,v in required.items()):return False
    if r.get('positiveAdmission') is not (group==GROUPS[2]):return False
    rows=r.get('records')
    if not isinstance(rows,list) or len(rows)!=n:return False
    for i,row in enumerate(rows):
        if not isinstance(row,dict) or not count(row.get('caseIndex'),i) or row.get('status')!='passed' or not isinstance(row.get('profiles'),list) or len(row['profiles'])!=2:return False
        for j,p in enumerate(row['profiles']):
            if not isinstance(p,dict) or p.get('status')!='completed' or p.get('experimental') is not bool(j):return False
            if group!=GROUPS[2] and (not count(p.get('appliedUpCount'),0) or not count(p.get('verifiedLifts'),0)):return False
            if group==GROUPS[2]:
                if j==0 and (p.get('outcome')!='expected_baseline_blocked' or p.get('reached') is not False or not count(p.get('appliedUpCount'),0) or not count(p.get('verifiedLifts'),0)):return False
                if j==1 and (p.get('outcome')!='full_tread_guarded_arrival' or p.get('reached') is not True or type(p.get('verifiedLifts')) not in (int,float) or p['verifiedLifts']<1 or p.get('appliedUpCount')!=p['verifiedLifts']):return False
    return campaign(r,group)
