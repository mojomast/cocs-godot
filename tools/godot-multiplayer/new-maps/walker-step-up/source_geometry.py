"""Independent Euclidean capsule/triangle oracle. NOT Godot, recovery or a controller.

Minimizes finite segment/triangle distance along a translation; convexity gives
a bounded scalar minimization for each triangle. Used to test whether proposed
paths really need all three volume sweeps, not to predict native passes.
"""
import math
import sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'botanical-correction'))
from capsule import segment_triangle
GUARD=.0001

def add(a,b):return tuple(x+y for x,y in zip(a,b))
def scale(a,s):return tuple(x*s for x in a)
def rect(x0,x1,z0,z1,y):
    a,b,c,d=(x0,y,z0),(x0,y,z1),(x1,y,z1),(x1,y,z0)
    return [(a,b,c),(a,c,d)]
def distance(foot,radius,height,tri):
    return segment_triangle(add(foot,(0,radius,0)),add(foot,(0,height-radius,0)),tri)
def swept_clearance(foot,motion,triangles,radius=.35,height=1.8,margin=.02):
    smallest=math.inf
    for tri in triangles:
        f=lambda t:distance(add(foot,scale(motion,t)),radius,height,tri)
        lo,hi=0.,1.
        for _ in range(70):
            a=lo+(hi-lo)/3;b=hi-(hi-lo)/3
            if f(a)<f(b):hi=b
            else:lo=a
        smallest=min(smallest,f(0),f(1),f((lo+hi)/2))
    return smallest-radius-margin
def first_down_hit(foot,drop,triangles,radius=.35,height=1.8,margin=.02):
    f=lambda t:min(distance(add(foot,(0,-drop*t,0)),radius,height,tri) for tri in triangles)-radius-margin
    if f(0)<=0 or f(1)>0:return None
    lo,hi=0.,1.
    for _ in range(70):
        mid=(lo+hi)/2
        if f(mid)>0:lo=mid
        else:hi=mid
    return add(foot,(0,-drop*hi,0))

def strict_rise(base,surface):return surface-base>GUARD and surface-base+GUARD<.25 and surface-base+GUARD<.3
def eligibility(*,grounded=True,vy=0.,jump=False,input_length=1.,moving=False,approach_cosine=1.,attempts=0):
    return grounded and abs(vy)<=GUARD and not jump and input_length>1e-6 and not moving and approach_cosine>=.98 and attempts==0
def floor_normal_valid(normal):return normal[1]>=math.cos(math.radians(46))
def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
def hull(points):
    points=sorted(set(points));lower=[];upper=[]
    for chain,source in [(lower,points),(upper,list(reversed(points)))]:
        for point in source:
            while len(chain)>=2 and cross(chain[-2],chain[-1],point)<=0:chain.pop()
            chain.append(point)
    return lower[:-1]+upper[:-1]
def certified_patch(triangles):
    if not 1<=len(triangles)<=32:return None
    points={p for t in triangles for p in t}
    if len({p[1] for p in points})!=1:return None
    poly=hull([(p[0],p[2]) for p in points]);edges=set()
    if len(poly)<3:return None
    for triangle in triangles:
        t=[(p[0],p[2]) for p in triangle];area=cross(*t)
        if area==0:return None
        if area<0:t.reverse()
        for i in range(3):
            edge=(t[i],t[(i+1)%3])
            if edge in edges:return None
            edges.add(edge)
    boundary=[(a,b) for a,b in edges if (b,a) not in edges];assigned=0
    for i,a in enumerate(poly):
        b=poly[(i+1)%len(poly)];delta=(b[0]-a[0],b[1]-a[1]);denom=sum(v*v for v in delta);intervals=[]
        for p,q in boundary:
            if cross(a,b,p)!=0 or cross(a,b,q)!=0:continue
            lo=sum((p[k]-a[k])*delta[k] for k in range(2))/denom
            hi=sum((q[k]-a[k])*delta[k] for k in range(2))/denom
            if 0<=lo<hi<=1:intervals.append((lo,hi));assigned+=1
        covered=0
        for lo,hi in sorted(intervals):
            if lo!=covered:return None
            covered=hi
        if covered!=1:return None
    if assigned!=len(boundary):return None
    return poly
def support_patch(triangles,contact,radius=.35,margin=.02):
    poly=certified_patch(triangles)
    if poly is None:return False
    corners=[(contact[0]+x,contact[2]+z) for x in [-radius-margin,radius+margin] for z in [margin+GUARD,radius+3*margin+GUARD]]
    return all(all(cross(poly[i],poly[(i+1)%4],p)>=0 for i in range(4)) for p in corners)
