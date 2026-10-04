PHASE='admission-controls-only-v4'
GROUPS=('inclined-landing-rejections','positive-step-admission')
def validate(grant,group):
    allowed=grant.get('allowedGroups')
    if grant.get('phase')!=PHASE or 'groups' in grant or 'continueAfterKnownBaselineFailure' in grant:raise ValueError('restricted admission-only phase required')
    if not isinstance(allowed,list) or not allowed or any(not isinstance(v,str) for v in allowed):raise ValueError('explicit allowedGroups required')
    if len(set(allowed))!=len(allowed) or not set(allowed)<=set(GROUPS) or group not in allowed:raise ValueError('unknown/map/duplicate group denied')
