"""Separate single-response grant; AF compare-only grants are not accepted."""
import math,re
PHASE='parity-response-only-v1'
MODE='single-response'
GROUP='parity-response'
KEYS={'phase','mode','allowedGroups','grantId','authorized','expiresUnix','sourceSha256','engineSha256'}
def validate(grant,*,group,mode,grant_id,source_hash,engine_hash,now):
    if not isinstance(grant,dict) or set(grant)!=KEYS:raise ValueError('exact single-response grant fields required')
    if (group,mode,grant['phase'],grant['mode'])!=(GROUP,MODE,PHASE,MODE):raise ValueError('single-response phase/mode/group required')
    if grant['allowedGroups']!=[GROUP]:raise ValueError('only singleton parity-response allowed')
    if grant['authorized'] is not True or not isinstance(grant['grantId'],str) or not grant_id or grant['grantId']!=grant_id:raise ValueError('explicit authorized grant identity required')
    expiry=grant['expiresUnix']
    if isinstance(expiry,bool) or not isinstance(expiry,(float,int)) or not math.isfinite(expiry) or expiry<=now:raise ValueError('grant expired/invalid')
    for actual,expected in [(grant['sourceSha256'],source_hash),(grant['engineSha256'],engine_hash)]:
        if not isinstance(actual,str) or not re.fullmatch('[a-f0-9]{64}',actual) or actual!=expected:raise ValueError('exact source/binary hash required')
