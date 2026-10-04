"""Independent post-exit lifecycle ledger check. No physics or controller oracle.

Use only on an error-free, completed instrumented trace; runtime/parse failures
can make even apparent post-return counters incomplete and must remain failed.
"""
import math
def lift_limit(radius):
    if radius not in (.35,.42):raise ValueError('fixed radii only')
    return math.ceil(2*radius/.1)+2
def check_lifecycle(rows,radius,positive):
    applied=verified=parents=attempts=0;last=None;terminal=False
    for row in rows:
        if terminal:raise ValueError('response after fault')
        if last is not None and row['frame']!=last+1:raise ValueError('duplicate or skipped physics frame')
        last=row['frame'];life=row['lifecycle']
        if row.get('returned') is not True or life.get('returned') is not True:raise ValueError('partial counters unknown')
        up=row['appliedUpCount'];parent=life['parentCalls'];fault=bool(row['candidateFault'])
        if type(up) is not int or up not in (0,1) or type(parent) is not int or parent not in (0,1):raise ValueError('per-response budget')
        if not life['originalProof']['accepted']:
            if up or parent!=1 or not life['ordinary']:raise ValueError('rejection must use exactly one ordinary response')
        elif not fault:
            if not positive or up!=1 or parent!=1 or not row['responseGuardPassed'] or not row['proposal']['accepted']:raise ValueError('unguarded accepted response')
            verified+=1
        elif not positive and (up or parent):raise ValueError('negative eligibility must stop before application')
        if life['totalAttempts']<attempts or life['totalAttempts']-attempts not in (0,1):raise ValueError('attempt accounting')
        attempts=life['totalAttempts'];applied+=up;parents+=parent
        if applied>lift_limit(radius):raise ValueError('profile lift bound')
        if life['totalApplied']!=applied or life['totalVerified']!=verified or life['totalParentCalls']!=parents:raise ValueError('cumulative accounting drift')
        terminal=fault
    return {'applied':applied,'verified':verified,'parentCalls':parents,'attempts':attempts,'terminalFault':terminal}
