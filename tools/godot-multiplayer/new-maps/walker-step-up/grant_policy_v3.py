"""Current source-admitted phase only; never creates or grants authorization."""
PHASE='controls-reference-only-v3'
ALLOWED=frozenset(['controls','reference-accepted-civic-r035'])
def validate_phase(grant,group,continuation=False):
    allowed=grant.get('allowedGroups')
    if grant.get('phase')!=PHASE:raise ValueError('controls/reference-only phase required')
    if not isinstance(allowed,list) or not allowed or any(not isinstance(v,str) for v in allowed):raise ValueError('explicit allowedGroups required')
    if len(set(allowed))!=len(allowed) or not set(allowed)<=ALLOWED or group not in allowed:raise ValueError('group outside controls/reference-only admission')
    if 'groups' in grant:raise ValueError('ambiguous legacy groups field')
    if continuation or grant.get('continueAfterKnownBaselineFailure',False):raise ValueError('candidate continuation not source-admitted in this phase')
    return True
