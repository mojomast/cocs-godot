"""Source-only numeric/path-observer policy; no native simulation claim."""
import math
def budget(*points):
    if not all(math.isfinite(v) for p in points for v in p):return None
    value=max(1.,*(abs(v) for p in points for v in p))
    epsilon=8*2**(math.floor(math.log2(value))-23)
    return max(1e-6,epsilon) if epsilon<=.0001 else None
def agrees(expected,actual,motion,last_motion,expected_support,actual_support,slides=0,platform=False):
    epsilon=budget(expected,actual)
    return epsilon is not None and math.dist(expected,actual)<=epsilon and math.dist(motion,last_motion)<=epsilon and expected_support==actual_support and slides==0 and not platform
