"""Measured two-link IK used by recipes and source oracles, without Blender.

Robots keep rigid pieces; rotations articulate at the real source pivots. Limb
lengths are never stretched, and all floor targets refer to original foot origin.
"""
import math


def add(a,b): return [x+y for x,y in zip(a,b)]
def sub(a,b): return [x-y for x,y in zip(a,b)]
def mul(a,k): return [x*k for x in a]
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def norm(a): return math.sqrt(dot(a,a))
def unit(a):
    length = norm(a)
    if length < 1e-9: raise ValueError('degenerate direction')
    return mul(a,1/length)


def rotate(v, angles):
    # pitch around lateral X, yaw around up Z, roll around forward Y.
    pitch,yaw,roll = [math.radians(a) for a in angles]
    x,y,z = v
    y,z = y*math.cos(pitch)-z*math.sin(pitch),y*math.sin(pitch)+z*math.cos(pitch)
    x,z = x*math.cos(roll)+z*math.sin(roll),-x*math.sin(roll)+z*math.cos(roll)
    return [x*math.cos(yaw)-y*math.sin(yaw),x*math.sin(yaw)+y*math.cos(yaw),z]


def ik(start,target,l1,l2,pole):
    delta = sub(target,start)
    desired = norm(delta)
    direction = unit(delta)
    distance = max(abs(l1-l2)+.0001,min(l1+l2-.0001,desired))
    end = add(start,mul(direction,distance))
    along = (l1*l1-l2*l2+distance*distance)/(2*distance)
    normal = unit(sub(pole,mul(direction,dot(pole,direction))))
    middle = add(add(start,mul(direction,along)),mul(normal,math.sqrt(max(0,l1*l1-along*along))))
    return middle,end,abs(desired-distance)


def solve(rig,pose):
    rest = rig['heads']
    out = {k:v[:] for k,v in rest.items()}
    hips = pose['hips']
    out['Hips'] = add(rest['Hips'],[hips[2],hips[0],hips[1]])
    hip_angles = [pose['torso'][0]*-.18,pose['torso'][1]*-.32,pose['torso'][2]*-.2]
    out['Spine'] = add(out['Hips'],rotate(sub(rest['Spine'],rest['Hips']),hip_angles))
    for bone,parent in (('Chest','Spine'),('Neck','Chest'),('Head','Neck')):
        out[bone] = add(out[parent],rotate(sub(rest[bone],rest[parent]),pose['torso']))
    errors = {}
    for side,short,sign in (('Left','l',-1),('Right','r',1)):
        shoulder,upper,lower,hand = [side+x for x in ('Shoulder','UpperArm','LowerArm','Hand')]
        out[shoulder] = add(out['Chest'],rotate(sub(rest[shoulder],rest['Chest']),pose['torso']))
        out[upper] = add(out[shoulder],rotate(sub(rest[upper],rest[shoulder]),pose['torso']))
        a,b = math.dist(rest[upper],rest[lower]), math.dist(rest[lower],rest[hand])
        f,u,s = pose[short+'h']
        target = add(out[upper],[(s)*(a+b),f*(a+b),u*(a+b)])
        out[lower],out[hand],errors[hand] = ik(out[upper],target,a,b,[sign*.6,-.35,-1])
        upper,lower,foot = [side+x for x in ('UpperLeg','LowerLeg','Foot')]
        out[upper] = add(out['Hips'],rotate(sub(rest[upper],rest['Hips']),hip_angles))
        a,b = math.dist(rest[upper],rest[lower]), math.dist(rest[lower],rest[foot])
        f,u,s = pose[short+'f']
        target = [rest[foot][0]+s-sign*.15,rest[foot][1]+f,rest[foot][2]+u]
        out[lower],out[foot],errors[foot] = ik(out[upper],target,a,b,[0,1,.05])
    tails = {}
    for bone,parent in rig['parents'].items():
        children = [k for k,v in rig['parents'].items() if v==bone]
        match = next((k for k in children if math.dist(rig['heads'][k],rig['tails'][bone])<1e-6),None)
        if match:
            tails[bone] = out[match]
        else:
            delta = sub(rig['tails'][bone],rest[bone])
            angle = pose['head'] if bone=='Head' else [0,0,0]
            tails[bone] = add(out[bone],rotate(delta,angle))
    # The actor origin is immutable even when the hips compress.
    out['Root'],tails['Root'] = rest['Root'][:],rig['tails']['Root'][:]
    return out,tails,errors
