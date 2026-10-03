"""Test-only world-space GLB triangle and precision checks for this producer."""
import itertools
import math
import sys
from collections import defaultdict
from config import ROOT
sys.path.insert(0,str(ROOT/'tools/godot-multiplayer/new-maps/map_variety'))
from glb_geometry import EmbeddedGlb

PRECISION = .0001
BEVEL = .04
def sub(a,b):return [x-y for x,y in zip(a,b)]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def length(a):return math.sqrt(dot(a,a))
def center(t):return [sum(p[k] for p in t)/3 for k in range(3)]
def normal(t):
    n=cross(sub(t[1],t[0]),sub(t[2],t[0]));size=length(n)
    if size<1e-10:raise ValueError('Degenerate proof triangle')
    return [v/size for v in n]
def volume(triangles):
    origin=triangles[0][0]
    return sum(dot(sub(t[0],origin),cross(sub(t[1],origin),sub(t[2],origin)))/6 for t in triangles)

IDENTITY=[1.,0,0,0,0,1.,0,0,0,0,1.,0,0,0,0,1.]
def multiply(a,b):return [sum(a[k*4+r]*b[c*4+k] for k in range(4)) for c in range(4) for r in range(4)]
def transform(matrix,p):return [sum(matrix[k*4+r]*p[k] for k in range(3))+matrix[12+r] for r in range(3)]
def node_matrix(node):
    if 'matrix' in node:return node['matrix']
    x,y,z,w=node.get('rotation',[0,0,0,1]);s=node.get('scale',[1,1,1]);t=node.get('translation',[0,0,0])
    return [(1-2*y*y-2*z*z)*s[0],(2*x*y+2*w*z)*s[0],(2*x*z-2*w*y)*s[0],0,
            (2*x*y-2*w*z)*s[1],(1-2*x*x-2*z*z)*s[1],(2*y*z+2*w*x)*s[1],0,
            (2*x*z+2*w*y)*s[2],(2*y*z-2*w*x)*s[2],(1-2*x*x-2*y*y)*s[2],0,*t,1]

def glb_triangles(raw):
    glb=EmbeddedGlb(raw);glb.geometry();doc=glb.doc;rows=[]
    pending=[(i,IDENTITY) for i in doc['scenes'][doc['scene']]['nodes']]
    while pending:
        index,parent=pending.pop();node=doc['nodes'][index];matrix=multiply(parent,node_matrix(node))
        pending.extend((i,matrix) for i in node.get('children',[]))
        if 'mesh' not in node:continue
        for primitive in doc['meshes'][node['mesh']]['primitives']:
            _,count,layout=glb.accessor(primitive['attributes']['POSITION'],'VEC3',(5126,),'POSITION')
            vertices=[transform(matrix,p) for p in glb.values(count,layout)]
            if 'indices' in primitive:
                _,count,layout=glb.accessor(primitive['indices'],'SCALAR',(5121,5123,5125),'index')
                indices=[v[0] for v in glb.values(count,layout)]
            else:indices=list(range(len(vertices)))
            for i in range(0,len(indices),3):
                rows.append({'material':doc['materials'][primitive['material']]['name'],
                             'vertices':[vertices[k] for k in indices[i:i+3]],'node':node.get('name','')})
    return rows

class TriangleInventory:
    """Multiplicity-preserving oriented match; grid is only a search accelerator."""
    def __init__(self,rows):
        self.rows=rows;self.used=set();self.grid=defaultdict(list)
        for i,row in enumerate(rows):self.grid[(row['material'],*self.cell(row['vertices']))].append(i)
    @staticmethod
    def cell(t):return tuple(math.floor(v/.001) for v in center(t))
    def consume(self,row):
        cell=self.cell(row['vertices']);expected=row['vertices']
        for delta in itertools.product((-1,0,1),repeat=3):
            key=(row['material'],*(a+b for a,b in zip(cell,delta)))
            for index in self.grid.get(key,[]):
                if index in self.used:continue
                actual=self.rows[index]['vertices']
                for shift in range(3):
                    if all(max(abs(a-b) for a,b in zip(expected[k],actual[(k+shift)%3]))<=PRECISION for k in range(3)):
                        self.used.add(index);return index
        raise ValueError('Missing/moved/reversed exported triangle: '+str(row)[:240])
    def match(self,expected,complete=False):
        indices=[self.consume(row) for row in expected]
        if complete and len(self.used)!=len(self.rows):raise ValueError('Unaccounted exported triangles')
        return indices

def ray_distance(triangles,origin,direction,maximum):
    if len(origin)!=3 or len(direction)!=3 or not all(math.isfinite(v) for v in [*origin,*direction,maximum]) or abs(length(direction)-1)>1e-6 or maximum<=0:
        raise ValueError('Invalid finite unit ray')
    best=maximum
    for t in triangles:
        a,b,c=t;e1,e2=sub(b,a),sub(c,a);p=cross(direction,e2);det=dot(e1,p)
        if abs(det)<1e-10:continue
        s=sub(origin,a);u=dot(s,p)/det
        if u< -1e-8 or u>1+1e-8:continue
        q=cross(s,e1);v=dot(direction,q)/det
        if v< -1e-8 or u+v>1+1e-8:continue
        d=dot(e2,q)/det
        if 0<=d<best:best=d
    return best

class RayIndex:
    def __init__(self,triangles):
        self.triangles=triangles;self.grid=defaultdict(list)
        for i,t in enumerate(triangles):
            for x in range(math.floor(min(p[0] for p in t)/8),math.floor(max(p[0] for p in t)/8)+1):
                for z in range(math.floor(min(p[2] for p in t)/8),math.floor(max(p[2] for p in t)/8)+1):self.grid[x,z].append(i)
    def ray(self,origin,direction,maximum):
        end=[p+d*maximum for p,d in zip(origin,direction)];ids=set()
        for x in range(math.floor(min(origin[0],end[0])/8),math.floor(max(origin[0],end[0])/8)+1):
            for z in range(math.floor(min(origin[2],end[2])/8),math.floor(max(origin[2],end[2])/8)+1):ids.update(self.grid.get((x,z),[]))
        return ray_distance((self.triangles[i] for i in ids),origin,direction,maximum)

def authority_triangles(arena):
    result=[]
    for surface in arena['terrain']['surfaces']:
        result.extend([[surface['vertices'][i] for i in f] for f in surface['triangles']])
    for wall in arena['terrain']['walls']:
        v=wall['vertices'];result.extend([[v[0],v[i],v[i+1]] for i in range(1,len(v)-1)])
    for b in arena.get('blocks',[]):
        x,z,w,d,y,h=b['x'],b['z'],b['w']/2,b['d']/2,b.get('baseY',0),b['h']
        v=[[x+dx,yy,z+dz] for yy in (y,h) for dz in (-d,d) for dx in (-w,w)]
        for face in [(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]:
            result.extend([[v[face[0]],v[face[i]],v[face[i+1]]] for i in (1,2)])
    return result
