"""Strict compare-only authorization contract; no grant creation."""
import math,re
PHASE='snap-query-compare-only-v1'
MODE='compare-only'
GROUP='query-compare'
KEYS={'phase','mode','allowedGroups','grantId','authorized','expiresUnix','sourceSha256','engineSha256'}
def validate(grant,*,group,mode,grant_id,source_hash,engine_hash,now):
    if not isinstance(grant,dict) or set(grant)!=KEYS:raise ValueError('exact compare-only grant fields required')
    if (group,mode,grant['phase'],grant['mode'])!=(GROUP,MODE,PHASE,MODE):raise ValueError('compare-only phase/mode/group required')
    if grant['allowedGroups']!=[GROUP]:raise ValueError('only singleton query-compare allowed')
    if grant['authorized'] is not True or not isinstance(grant['grantId'],str) or not grant_id or grant['grantId']!=grant_id:raise ValueError('explicit authorized grant identity required')
    expiry=grant['expiresUnix']
    if isinstance(expiry,bool) or not isinstance(expiry,(float,int)) or not math.isfinite(expiry) or expiry<=now:raise ValueError('grant expired/invalid')
    for actual,expected in [(grant['sourceSha256'],source_hash),(grant['engineSha256'],engine_hash)]:
        if not isinstance(actual,str) or not re.fullmatch('[a-f0-9]{64}',actual) or actual!=expected:raise ValueError('exact source/binary hash required')
