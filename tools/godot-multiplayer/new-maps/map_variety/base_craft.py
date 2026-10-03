"""Pure capture of pinned accepted architectural craft, without importing bpy.

Execute ONLY reviewed geometry functions/loops from the accepted source AST.
Scene setup, imports, files, exporters and render code are never executed.
Authority geometry is already emitted by the candidate shell and is excluded.
Pinning the entire author prevents an upstream edit silently extending this
small execution boundary. Captured parts remain material/lineage editable.
"""
import ast
import copy
import hashlib
import json
import math
import random
from pathlib import Path

import kit_expander as k

PINS = {
    'parallax-observatory': ('blender_author.py','9cec1edaab54477d9999eb7888c921d527f0ee3f1248f2adf9c2a6a7cf5897cc'),
    'vesper-viaduct': ('author_blender.py','f540161e4ec506f7ce3098bd1533d6d321a2aa806cd7c0180db8f0b8278ac4c6'),
}


class Vector(list):
    def __init__(self, values):super().__init__(float(v) for v in values)
    def __add__(self, other):return Vector(a+b for a,b in zip(self,other))
    def __sub__(self, other):return Vector(a-b for a,b in zip(self,other))
    def __mul__(self, scalar):return Vector(a*scalar for a in self)
    __rmul__=__mul__
    def __truediv__(self, scalar):return self*(1/scalar)
    @property
    def length(self):return math.sqrt(sum(v*v for v in self))
    def normalized(self):return self/self.length
    def normalize(self):self[:]=self.normalized()
    def cross(self, b):return Vector((self[1]*b[2]-self[2]*b[1],self[2]*b[0]-self[0]*b[2],self[0]*b[1]-self[1]*b[0]))
    x=property(lambda s:s[0],lambda s,v:s.__setitem__(0,v))
    y=property(lambda s:s[1],lambda s,v:s.__setitem__(1,v))
    z=property(lambda s:s[2],lambda s,v:s.__setitem__(2,v))


def base_craft_plan(arena, root):
    ident=arena['id']
    if ident not in PINS:return {'buckets':{},'lineage':[],'labels':[],'triangles':0}
    filename,digest=PINS[ident]
    path=Path(root)/'tools/godot-multiplayer/new-maps'/ident/filename
    raw=path.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=digest:raise ValueError('Accepted craft author changed; review capture boundary: '+str(path))
    tree=ast.parse(raw,filename=str(path))
    buckets,lineage,labels,cut_lineage={ },[],[],[]
    def emit(name,vertices,faces,material='saltstone',authority=False):
        if authority:return
        for cut in arena.get('art',{}).get('baseCraft',{}).get('cutouts',[]):
            if all(max(v[i] for v in vertices)>cut['min'][i] and min(v[i] for v in vertices)<cut['max'][i] for i in range(3)):
                cut_lineage.append({'name':name,'cutout':cut['id']})
                return
        verts=[k.to_blender(v) for v in vertices]
        faces=k.outward_faces(verts,faces)
        # Dome poles can collapse an authored quad. Retain its real triangles
        # without handing zero-area polygons to Kit.mesh.
        triangles=[]
        for f in faces:
            for i in range(1,len(f)-1):
                tri=(f[0],f[i],f[i+1]);a,b,c=[Vector(verts[j]) for j in tri]
                if (b-a).cross(c-a).length>2e-8:triangles.append(tri)
        if not triangles:return
        k._add(buckets.setdefault(material,k._empty()),verts,triangles)
        lineage.append({'name':name,'material':material,'triangles':len(triangles)})
    def inscription(name,text,x,y,z,side,size=.45):
        labels.append({'id':name,'text':text,'x':x,'y':y,'z':z,'yaw':-side*math.pi/2,'size':size,'extrude':.006,'material':'ochre'})
    env={'math':math,'Vector':Vector,'emit':emit,'inscription':inscription}
    if ident=='parallax-observatory':
        data=json.loads((Path(root)/'godot/multiplayer_worlds/generated/parallax-observatory.json').read_text())
        env.update(DATA=data,A=data['arena'],ART=data['art'],random=random.Random(data['art']['seed']))
        nodes=[n for n in tree.body if (isinstance(n,ast.FunctionDef) and n.name in ('box','beam','ring','transform','ground')) or
               (isinstance(n,ast.For) and 139<=n.lineno<=428) or
               (isinstance(n,ast.Expr) and 424<=n.lineno<=428)]
    else:
        recipe=copy.deepcopy(arena)
        recipe['structures']=[s for s in recipe['structures'] if s.get('type')=='three-room-through-hall']
        env['recipe']=recipe
        def mesh(name,vertices,faces,material,collection,authority=False):return emit(name,vertices,faces,material,authority)
        def beam(name,a,b,width=.16,material='iron'):
            a,b=Vector(a),Vector(b);direction=(b-a).normalized()
            u=direction.cross(Vector((0,1,0)))
            if u.length<.01:u=direction.cross(Vector((1,0,0)))
            u=u.normalized();v=direction.cross(u).normalized()
            vertices=[tuple(p+(u*math.cos(i*math.tau/6)+v*math.sin(i*math.tau/6))*width) for p in (a,b) for i in range(6)]
            faces=[tuple(reversed(range(6))),tuple(range(6,12))]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
            emit(name,vertices,faces,material)
        env.update(mesh=mesh,beam=beam)
        nodes=[]
        for n in ast.walk(tree):
            if isinstance(n,ast.FunctionDef) and n.name=='cube':nodes.append(n)
            if isinstance(n,ast.For) and n.lineno in (96,115,162,186,188,190,194,198):
                n=copy.deepcopy(n)
                if n.lineno==96:n.body=n.body[1:] # pieces already emitted; keep their reveals/sills
                nodes.append(n)
        nodes.sort(key=lambda n:n.lineno)
    forbidden={'bpy','open','Path','__import__','eval','exec'}
    if any(isinstance(n,ast.Name) and n.id in forbidden for root_node in nodes for n in ast.walk(root_node)):
        raise ValueError('Nongeometry operation in accepted craft capture')
    module=ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[]))
    exec(compile(module,str(path)+' [geometry-only capture]','exec'),env)
    return {'buckets':buckets,'lineage':lineage,'labels':labels,
            'triangles':sum(k._triangles(b['vertices'],b['faces']) for b in buckets.values()),
            'sourceSha256':digest,'candidateCutLineage':cut_lineage}
