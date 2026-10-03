"""Shared editable mechanism shells: game XYZ metres, closed outward winding.

Both Blender and source collision consume these same polygon shells. No filled
portal proxies. R3 terrain remains the authoritative graded walking surface.
"""
import json
import math
from pathlib import Path
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
sys.path.insert(0,str(ROOT/'tools/map-variety-pipeline'))
from blender_kit import Kit

def add(a,b):return [x+y for x,y in zip(a,b)]
def sub(a,b):return [x-y for x,y in zip(a,b)]
def mul(a,s):return [x*s for x in a]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def unit(a):return mul(a,1/math.sqrt(dot(a,a)))
FACES=[[0,2,3,1],[4,5,7,6],[0,1,5,4],[2,6,7,3],[0,4,6,2],[1,3,7,5]]
def cube(size):return [[sx*size[0]/2,sy*size[1]/2,sz*size[2]/2] for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
def volume(v,faces):return sum(dot(v[f[0]],cross(v[f[i]],v[f[i+1]]))/6 for f in faces for i in range(1,len(f)-1))

def build():
    shapes=[];anchors=[]
    accepted=json.loads((ROOT/'godot/multiplayer_worlds/generated/gravemill-foundry.json').read_text())['arena']
    def put(name,v,f,mat,**extra):
        assert volume(v,f)>1e-7,(name,volume(v,f))
        item={'id':name,'vertices':v,'faces':f,'material':mat,**extra}
        shapes.append(item);return item
    def box(name,center,size,mat,shear=False):
        v=[add(center,p) for p in cube(size)]
        if shear:v=[[p[0],p[1],p[2]+.14*(p[0]-center[0])] for p in v]
        return put(name,v,FACES,mat,kind='box')
    def strut(name,a,b,width,mat):
        # Local zero-centred Z extrusion, rigid basis then world midpoint.
        delta=sub(b,a);length=math.sqrt(dot(delta,delta));z=unit(delta)
        x=unit(cross([0,1,0] if abs(z[1])<.99 else [1,0,0],z));y=cross(z,x)
        basis=[x,y,z];center=mul(add(a,b),.5);local=cube([width,width,length])
        v=[add(center,[sum(p[j]*basis[j][k] for j in range(3)) for k in range(3)]) for p in local]
        return put(name,v,FACES,mat,kind='strut',localVertices=local,basis=basis,center=center,endpoints=[a,b],width=width)
    def drum(name,center,radius,length,mat,axis='Y',sides=20):
        # All bases right-handed: u cross v points along the requested axis.
        axis,u,v={'Y':([0,1,0],[1,0,0],[0,0,-1]),'X':([1,0,0],[0,1,0],[0,0,1]),
                  'Z':([0,0,1],[1,0,0],[0,1,0])}[axis]
        vertices=[add(center,add(mul(axis,end*length/2),add(mul(u,radius*math.cos(i*math.tau/sides)),mul(v,radius*math.sin(i*math.tau/sides))))) for end in (-1,1) for i in range(sides)]
        faces=[list(reversed(range(sides))),list(range(sides,2*sides))]+[[i,(i+1)%sides,(i+1)%sides+sides,i+sides] for i in range(sides)]
        return put(name,vertices,faces,mat,kind='drum',center=center,axis=axis,radius=radius,length=length)
    def roof_at(x,z):
        hits=[]
        for s in accepted['terrain']['surfaces']:
            if not s['id'].startswith('crusher-process-roof'):continue
            for tri in s['triangles']:
                a,b,c=[s['vertices'][i] for i in tri];den=(b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
                u=((b[2]-c[2])*(x-c[0])+(c[0]-b[0])*(z-c[2]))/den
                v=((c[2]-a[2])*(x-c[0])+(a[0]-c[0])*(z-c[2]))/den
                if min(u,v,1-u-v)>=-1e-8:hits.append((u*a[1]+v*b[1]+(1-u-v)*c[1],s['id']))
        assert hits,('G1 anchor outside roof',x,z)
        return max(hits)
    for index,(x,z,top) in enumerate([(-86,-35,44),(-53,-20,49)]):
        label=f'G1.headframe.{index}'
        for sx in (-1,1):
            for sz in (-1,1):
                px,pz=x+sx*5,z+sz*2.6;y,roof=roof_at(px,pz)
                anchors.append({'id':f'{label}.{sx}.{sz}','position':[px,y,pz],'roof':roof})
                box(f'{label}.shoe.{sx}.{sz}',[px,y+.08,pz],[1,.24,1],'GM / brass')
                strut(f'{label}.leg.{sx}.{sz}',[px,y,pz],[x+sx*1.8,top,z+sz*1.2],.48,'GM / soot')
        for level in (top-6,top-1):strut(f'{label}.crossrail.{level}',[x-2.5,level,z],[x+2.5,level,z],.32,'G4 / ribbed')
        drum(label+'.sheave',[x,top,z],1.6,.65,'GM / brass',axis='X')
        strut(label+'.cable',[x,top-.8,z],[x,top-7,z],.08,'GM / soot')
        box(label+'.hookblock',[x,top-7,z],[.9,1.5,.8],'GM / brass')
    for index,(x,z,ground,radius) in enumerate([(64,.96,1.44,11),(94,21.16,6,8)]):
        label=f'G2.furnace.{index}'
        for tier,(height,scale) in enumerate([(3,1.05),(9,.94),(15,.78)]):drum(f'{label}.casing.{tier}',[x,ground+height,z],radius*scale,1.1,'GM / copper',sides=20+index*4)
        for i in range(9+index*2):
            a=i*math.tau/(9+index*2);px=x+radius*.95*math.cos(a);pz=z+radius*.95*math.sin(a)
            strut(f'{label}.rib.{i}',[px,ground+2,pz],[px,ground+17,pz],.22,'G4 / ribbed')
        drum(label+'.chimney',[x+radius*.38,ground+34+index*4,z],2.4,19,'GM / soot',sides=16)
        for rim in (ground+26+index*3,ground+39+index*4):drum(f'{label}.band.{rim}',[x+radius*.38,rim,z],2.65,.42,'GM / brass',sides=16)
        box(label+'.tap-platform',[x,ground+8,z-radius*.7],[7,.45,2.8],'G4 / grating')
        box(label+'.launder',[x,ground+6.8,z-radius*1.3],[2.2,.35,8],'GM / brass')
    class Recorder:
        def mesh(self,name,vertices,faces,mat,**kw):return put(name,[[x,h,-y] for x,y,h in vertices],[list(f) for f in faces],mat,kind='arch')
    for x,z,width in [(51,-30,12),(82,-32,15)]:
        label=f'G3.tipple.{x}';spring=11-width/2
        for side in (-1,1):
            box(f'{label}.jamb.{side}',[x+side*(width/2-.11),spring/2,z],[.22,spring,1.1],'GM / mineral')
            box(f'{label}.roof-eave.{side}',[x+side*width*.28,12,z],[width*.56,.38,10],'G4 / ribbed')
            # Flush guides remain very low; no fictitious filled portal slab.
            box(f'{label}.guide.{side}',[x+side*width*.34,-.075,z-4],[.24,.16,11],'GM / brass')
        Kit.curved_rib(Recorder(),label+'.arch',(x,-z,spring),width/2-.22,width/2,1.1,0,math.pi,'GM / mineral',segments=20)
        box(label+'.grain-deck',[x,9,z+3],[width*.8,.4,2],'G4 / timber')
    for index,(x,z,y,length,axis) in enumerate([(-24,-71.36,13,54,'z'),(24,37.36,25,92,'z'),(-122,66.92,32.90909,36,'z'),(122,101.08,32.90909,36,'z'),(0,-4,33,100,'x'),(0,80,44,90,'x')]):
        label=f'G4.conveyor.{index}'
        for j in range(int(length)//12+1):
            along=-length/2+min(j*12,length);cx=x+(along if axis=='x' else 0);cz=z+(along if axis=='z' else .14*along)
            for side in (-1,1):
                dx=side*(0 if axis=='x' else 1.7);dz=side*(1.7 if axis=='x' else 0)+.14*dx
                strut(f'{label}.trestle.{j}.{side}',[cx+dx*1.4,y-6,cz+dz*1.4],[cx+dx,y,cz+dz],.18,'GM / soot')
            drum(f'{label}.roller.{j}',[cx,y+.12,cz],.34,3.2,'GM / brass',axis='X' if axis=='z' else 'Z',sides=10)
        box(label+'.belt',[x,y,z],[length if axis=='x' else 3.4,.18,3.4 if axis=='x' else length],'G4 / ribbed',shear=True)
    for index,(x,z) in enumerate([(-132,-112.48),(-94,-107.16),(-50,-101),(22,-90.92),(96,-80.56),(134,-75.24)]):
        label=f'G5.bunker.{index}';span=11+(index%2)*1.3
        box(label+'.foot',[x,1.2,z],[span,2.1,9.4],'GM / mineral')
        if index%3==0:drum(label+'.surge',[x,5.5,z],span*.36,6.2,'GM / ore',sides=11)
        elif index%3==1:
            for sx in (-1,1):strut(f'{label}.hopper.{sx}',[x+sx*span*.42,2.3,z],[x+sx*span*.17,7.5,z],.48,'GM / copper')
            box(label+'.grate',[x,7.2,z],[span,.26,5],'G4 / grating')
        else:
            drum(label+'.live-bottom',[x,4,z],span*.39,4.1,'GM / ore',sides=14)
            strut(label+'.discharge',[x,4,z],[x+3,2,z-1],.55,'GM / soot')
        for j in range(2+index%3):box(f'{label}.cap.{j}',[x+(j-1)*1.1,7.4+j*.4,z],[span-j*.9,.23,5-j*.6],'GM / brass')
    for index,(x,z,y) in enumerate([(-72,-17.08,13.4),(-48,-6.72,15.08)]):
        label=f'G6.crusher.{index}'
        drum(label+'.toothed-drum',[x,y+6,z],5.2-index*.6,10,'G4 / ribbed',axis='X',sides=22)
        for tooth in range(12):
            a=tooth*math.tau/12
            box(f'{label}.tooth.{tooth}',[x,y+6+5.15*math.cos(a),z+5.15*math.sin(a)],[10,.38,.38],'GM / brass')
        for side in (-1,1):
            drum(f'{label}.gear.{side}',[x+side*6,y+5,z],2.8,.8,'GM / copper',axis='X')
            box(f'{label}.gearbox.{side}',[x+side*8,y+4,z+4],[3,4,3.5],'GM / soot')
        box(label+'.safety-house',[x,y+10,z+9],[12,.6,5],'GM / brass')
    return {'schema':1,'coordinates':'game XYZ metres; outward right-handed shells','shapes':shapes,'roofAnchors':anchors}

if __name__=='__main__':
    result=build();(HERE/'shapes.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
    print(json.dumps({'shapes':len(result['shapes']),'anchors':result['roofAnchors']}))
