"""Run real Kit construction methods against a pure mesh sink, never bpy.

This is also the collision/visual lineage source for solid kit forms. The same
ops and rigid transforms are used by the editable Blender builder.
"""
import json
import math
import sys
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'tools/map-variety-pipeline'))
from blender_kit import Kit
import kit_build
import kit_expander

SOLIDS = {'grotto_arch','stepped_terrace','facade_bays','tower','scientific_room',
          'stall_row','roof_run','arch_bridge','retaining_wall','framed_bay','greenhouse_frame'}


class MeshObject:
    pass


class CaptureKit(Kit):
    def __init__(self):
        self.source = SimpleNamespace(objects=[])

    def mesh(self,name,vertices,faces,material,**kwargs):
        obj=MeshObject()
        obj.name,obj.vertices,obj.faces=name,vertices,kit_expander.outward_faces(vertices,faces)
        obj.material,obj.location,obj.rotation_euler=material,(0,0,0),(0,0,0)
        self.source.objects.append(obj)
        return obj


def world_vertices(obj):
    tilt,_,heading=obj.rotation_euler
    ct,st,c,s=math.cos(tilt),math.sin(tilt),math.cos(heading),math.sin(heading)
    out=[]
    for x,y,z in obj.vertices:
        y,z=ct*y-st*z,st*y+ct*z
        bx,by,bz=obj.location[0]+c*x-s*y,obj.location[1]+s*x+c*y,obj.location[2]+z
        out.append([bx,bz,-by])
    return out


def solid_geometry(arena):
    surfaces,walls=[],[]
    allowed={d['material'] for d in arena['art']['kit']}
    for d in arena['art']['kit']:
        allowed.update(d['params'].get(k) for k in ('trimMaterial','capMaterial','glazingMaterial') if d['params'].get(k))
    for directive in arena['art']['kit']:
        if directive['class'] not in SOLIDS:continue
        kit=CaptureKit()
        for op in kit_expander.expand_kit([directive],allowed):kit_build.create_assembly(kit,op)
        for obj in kit.source.objects:
            vertices=world_vertices(obj)
            for face in obj.faces:
                for i in range(1,len(face)-1):
                    triangle=[vertices[k] for k in (face[0],face[i],face[i+1])]
                    a,b,c=triangle
                    u,v=[b[k]-a[k] for k in range(3)],[c[k]-a[k] for k in range(3)]
                    normal=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                    area=math.sqrt(sum(n*n for n in normal))
                    if area<1e-8:continue
                    entry={'id':'kit:'+obj.name,'material':obj.material,'vertices':triangle,'renderSource':'kit'}
                    if abs(normal[1])/area > .5:
                        surfaces.append(dict(entry,triangles=[[0,1,2]],walkable=False))
                    else:walls.append(entry)
    return {'surfaces':surfaces,'walls':walls}


if __name__=='__main__':
    print(json.dumps(solid_geometry(json.load(sys.stdin))))
