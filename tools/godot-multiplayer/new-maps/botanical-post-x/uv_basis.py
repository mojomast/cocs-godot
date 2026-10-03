"""Pure corner basis semantics from reviewed R7 (10d9938f tangents.py).

Only reusable mathematics is carried here; no Foundry identities, IO, encoder,
material policy or seven-entry inventory. This is not full MikkTSpace.
"""
import math
import struct
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def mul(a,s):return tuple(x*s for x in a)
def cross(a,b):return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def norm(a):return math.sqrt(dot(a,a))
def unit(a):
    size=norm(a)
    if not math.isfinite(size) or size<=1e-20:raise ValueError('Undefined direction')
    return mul(a,1/size)
def projected(t,n):return unit(sub(t,mul(n,dot(n,t))))
def basis(points,uv,normal,corner):
    e1,e2=sub(points[1],points[0]),sub(points[2],points[0])
    u1,u2=sub(uv[1],uv[0]),sub(uv[2],uv[0]);det=u1[0]*u2[1]-u1[1]*u2[0]
    area=norm(cross(e1,e2))/2
    if area<=1e-12 or abs(det)<=1e-15:raise ValueError('Degenerate geometry or UV Jacobian')
    t=mul(sub(mul(e1,u2[1]),mul(e2,u1[1])),1/det)
    b=mul(sub(mul(e2,u1[0]),mul(e1,u2[0])),1/det)
    n=unit(normal);pt=projected(t,n);hand=dot(cross(n,pt),b)
    if abs(hand)<=1e-15:raise ValueError('Undefined UV handedness')
    a=sub(points[(corner+1)%3],points[corner]);c=sub(points[(corner+2)%3],points[corner])
    angle=math.atan2(norm(cross(a,c)),dot(a,c))
    if angle<=0:raise ValueError('Zero corner angle')
    return {'t':unit(t),'b':unit(b),'projected':pt,'sign':1.0 if hand>0 else -1.0,
        'weight':angle,'area':area,'uvJacobian':det,'normal':n,'dPdu':t,'dPdv':b}
def solve(incidents):
    if not incidents:raise ValueError('No incident corners')
    first=incidents[0];n=first['normal']
    if any(norm(sub(i['normal'],n))>1e-7 or i['sign']!=first['sign'] for i in incidents):
        raise ValueError('Conflicting shared normals/UV handedness; split required')
    t=projected(tuple(sum(i['t'][k]*i['weight'] for i in incidents) for k in range(3)),n)
    b=tuple(sum(i['b'][k]*i['weight'] for i in incidents) for k in range(3))
    if any(dot(t,i['projected'])<1-1e-8 for i in incidents):raise ValueError('Conflicting shared directions; split required')
    sign=1.0 if dot(cross(n,t),b)>0 else -1.0
    if sign!=first['sign']:raise ValueError('Accumulated handedness conflict')
    result=struct.unpack('<4f',struct.pack('<4f',*t,sign))
    if abs(norm(result[:3])-1)>1e-6 or abs(dot(result[:3],n))>1e-6:raise ValueError('Invalid basis')
    return result
