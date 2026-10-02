"""Small read-only GLB oracle. No Blender, engine, numpy or import cache."""
import hashlib
import json
import math
import struct

IDENTITY = [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]


def multiply(a,b):
    return [sum(a[k*4+r]*b[c*4+k] for k in range(4)) for c in range(4) for r in range(4)]


def transform(m,p):
    return [sum(m[c*4+r]*p[c] for c in range(3))+m[12+r] for r in range(3)]


def matrix(node):
    if 'matrix' in node:
        return node['matrix']
    x,y,z,w = node.get('rotation',[0,0,0,1])
    sx,sy,sz = node.get('scale',[1,1,1])
    m = [(1-2*y*y-2*z*z)*sx,(2*x*y+2*z*w)*sx,(2*x*z-2*y*w)*sx,0,
         (2*x*y-2*z*w)*sy,(1-2*x*x-2*z*z)*sy,(2*y*z+2*x*w)*sy,0,
         (2*x*z+2*y*w)*sz,(2*y*z-2*x*w)*sz,(1-2*x*x-2*y*y)*sz,0]
    return m+node.get('translation',[0,0,0])+[1]


class GLB:
    def __init__(self,path):
        self.path = path
        raw = path.read_bytes()
        magic,version,length = struct.unpack_from('<4sII',raw)
        assert magic == b'glTF' and version == 2 and length == len(raw), path
        self.sha256 = hashlib.sha256(raw).hexdigest()
        self.binary = b''
        cursor = 12
        while cursor < len(raw):
            size,kind = struct.unpack_from('<II',raw,cursor)
            data = raw[cursor+8:cursor+8+size]
            if kind == 0x4e4f534a: self.doc = json.loads(data)
            elif kind == 0x004e4942: self.binary = data
            cursor += 8+size
        self.parents = {child:i for i,n in enumerate(self.doc['nodes']) for child in n.get('children',[])}
        self.names = {n.get('name',''):i for i,n in enumerate(self.doc['nodes'])}

    def world(self,i):
        m = matrix(self.doc['nodes'][i])
        return multiply(self.world(self.parents[i]),m) if i in self.parents else m

    def accessor(self,index):
        a = self.doc['accessors'][index]
        assert 'sparse' not in a, 'sparse accessor oracle not implemented'
        view = self.doc['bufferViews'][a['bufferView']]
        assert view.get('buffer',0) == 0
        fmt,size = {5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}[a['componentType']]
        count = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        offset = view.get('byteOffset',0)+a.get('byteOffset',0)
        stride = view.get('byteStride',size*count)
        out = [struct.unpack_from('<'+fmt*count,self.binary,offset+i*stride) for i in range(a['count'])]
        if a.get('normalized'):
            divisor = {5120:127,5121:255,5122:32767,5123:65535}[a['componentType']]
            out = [tuple(max(-1,v/divisor) for v in row) for row in out]
        assert all(math.isfinite(x) for row in out for x in row)
        return out

    def ancestors(self,i):
        while True:
            yield self.doc['nodes'][i].get('name','')
            if i not in self.parents: break
            i = self.parents[i]

    def bounds(self, remove_gun=True, lod=1):
        low,high = [math.inf]*3,[-math.inf]*3
        vertices = 0
        for i,n in enumerate(self.doc['nodes']):
            if 'mesh' not in n: continue
            if remove_gun and any(x in ('weapon','gunAnchor') for x in self.ancestors(i)): continue
            if not n.get('extras',{}).get('sourceLodMask',7)&lod: continue
            for primitive in self.doc['meshes'][n['mesh']]['primitives']:
                for p in self.accessor(primitive['attributes']['POSITION']):
                    p = transform(self.world(i),p)
                    low = [min(a,b) for a,b in zip(low,p)]
                    high = [max(a,b) for a,b in zip(high,p)]
                    vertices += 1
        return {'min':low,'max':high,'dimensions':[b-a for a,b in zip(low,high)],'vertices':vertices}


SOURCE_MAP = {'root':'Root','hips':'Hips','torso':'Spine','chest':'Chest','head':'Head',
    'armUpperL':'LeftUpperArm','forearmL':'LeftLowerArm','handL':'LeftHand',
    'armUpperR':'RightUpperArm','forearmR':'RightLowerArm','handR':'RightHand',
    'legUpperL':'LeftUpperLeg','legLowerL':'LeftLowerLeg','footL':'LeftFoot',
    'legUpperR':'RightUpperLeg','legLowerR':'RightLowerLeg','footR':'RightFoot'}
OWNER_MAP = dict(SOURCE_MAP,backpack='Chest',gripL='LeftHand',gripR='RightHand',
    rigPivot0='LeftUpperArm',rigPivot1='RightUpperArm',rigPivot2='LeftLowerArm',rigPivot3='RightLowerArm',
    rigPivot4='LeftUpperLeg',rigPivot5='RightUpperLeg',rigPivot6='LeftLowerLeg',rigPivot7='RightLowerLeg',
    TeamMark0='Spine',TeamMark1='Spine')


def source_rig(glb):
    # glTF X/Y/-Z -> Blender X/Z/+Y, preserving source metres.
    heads = {}
    for src,bone in SOURCE_MAP.items():
        x,y,z = transform(glb.world(glb.names[src]),[0,0,0])
        heads[bone] = [x,-z,y]
    parents = {'Root':None,'Hips':'Root','Spine':'Hips','Chest':'Spine','Neck':'Chest','Head':'Neck'}
    heads['Neck'] = [(a+b)*.5 for a,b in zip(heads['Chest'],heads['Head'])]
    for side in ('Left','Right'):
        shoulder = side+'Shoulder'
        heads[shoulder] = [heads['Chest'][0],heads['Chest'][1],heads[side+'UpperArm'][2]]
        parents.update({shoulder:'Chest',side+'UpperArm':shoulder,side+'LowerArm':side+'UpperArm',
                        side+'Hand':side+'LowerArm',side+'UpperLeg':'Hips',side+'LowerLeg':side+'UpperLeg',side+'Foot':side+'LowerLeg'})
    tails = {}
    preferred = {'Root':'Hips','Hips':'Spine','Spine':'Chest','Chest':'Neck','Neck':'Head'}
    for side in ('Left','Right'):
        preferred.update({side+'Shoulder':side+'UpperArm',side+'UpperArm':side+'LowerArm',
            side+'LowerArm':side+'Hand',side+'UpperLeg':side+'LowerLeg',side+'LowerLeg':side+'Foot'})
    for bone,head in heads.items():
        if bone in preferred: tails[bone] = heads[preferred[bone]][:]
        else:
            delta = [0,.13,0] if bone.endswith('Foot') else [0,0,-.09] if bone.endswith('Hand') else [0,0,.14]
            tails[bone] = [a+b for a,b in zip(head,delta)]
        assert math.dist(head,tails[bone]) > .025, (bone,head,tails[bone])
    return {'heads':heads,'tails':tails,'parents':parents}
