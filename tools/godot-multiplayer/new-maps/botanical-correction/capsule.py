"""Independent finite segment/triangle distances for source capsule fixtures.

No footprint-only test, no collider inflation or relaxed bevel tolerance.
"""
import math
def sub(a,b):return [x-y for x,y in zip(a,b)]
def add(a,b):return [x+y for x,y in zip(a,b)]
def mul(a,t):return [x*t for x in a]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def norm(a):return math.sqrt(dot(a,a))
def clamp(t):return max(0,min(1,t))
def point_segment(p,a,b):
    d=sub(b,a);t=clamp(dot(sub(p,a),d)/dot(d,d)) if dot(d,d)>1e-20 else 0
    return norm(sub(p,add(a,mul(d,t))))
def segment_segment(a,b,c,d):
    u,v,w=sub(b,a),sub(d,c),sub(a,c)
    aa,bb,cc,dd,ee=dot(u,u),dot(u,v),dot(v,v),dot(u,w),dot(v,w)
    denom=aa*cc-bb*bb
    distances=[point_segment(a,c,d),point_segment(b,c,d),point_segment(c,a,b),point_segment(d,a,b)]
    if denom>1e-20:
        s,t=(bb*ee-cc*dd)/denom,(aa*ee-bb*dd)/denom
        if 0<=s<=1 and 0<=t<=1:distances.append(norm(sub(add(a,mul(u,s)),add(c,mul(v,t)))))
    return min(distances)
def inside(p,t,n):
    return all(dot(cross(sub(t[(i+1)%3],t[i]),sub(p,t[i])),n)>=-1e-10 for i in range(3))
def segment_triangle(a,b,t):
    n=cross(sub(t[1],t[0]),sub(t[2],t[0]));nn=dot(n,n)
    best=min(segment_segment(a,b,t[i],t[(i+1)%3]) for i in range(3))
    if nn<1e-20:return best
    for p in (a,b):
        signed=dot(sub(p,t[0]),n);q=sub(p,mul(n,signed/nn))
        if inside(q,t,n):best=min(best,abs(signed)/math.sqrt(nn))
    da,db=dot(sub(a,t[0]),n),dot(sub(b,t[0]),n)
    if da*db<=0 and abs(da-db)>1e-20:
        p=add(a,mul(sub(b,a),da/(da-db)))
        if inside(p,t,n):return 0
    return best

class Capsules:
    def __init__(self,triangles):
        self.cells={}
        for t in triangles:
            for x in range(math.floor(min(v[0] for v in t)/4),math.floor(max(v[0] for v in t)/4)+1):
                for z in range(math.floor(min(v[2] for v in t)/4),math.floor(max(v[2] for v in t)/4)+1):
                    self.cells.setdefault((x,z),[]).append(t)
    def overlaps(self,x,y,z,radius=.42,height=1.8):
        a,b=[x,y+radius,z],[x,y+height-radius,z]
        for cx in range(math.floor((x-radius)/4),math.floor((x+radius)/4)+1):
            for cz in range(math.floor((z-radius)/4),math.floor((z+radius)/4)+1):
                for t in self.cells.get((cx,cz),[]):
                    if any(max(v[k] for v in t)<min(a[k],b[k])-radius or min(v[k] for v in t)>max(a[k],b[k])+radius for k in range(3)):continue
                    if segment_triangle(a,b,t)<radius-1e-7:return t
        return None
