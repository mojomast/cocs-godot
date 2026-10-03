"""Strict embedded, static, non-instanced GLB contract for these map builders.

Bounds are checked against real bytes before iterating accessor counts. This is
not a general glTF loader: sparse/compressed/skinned/morphed geometry and external
resources are outside the producer contract and fail closed.
"""
import json
import math
import struct


def integer(value,label,minimum=0):
    if type(value) is not int or value<minimum:raise ValueError('Invalid '+label)
    return value


def item(items,index,label):
    integer(index,label)
    if not isinstance(items,list) or index>=len(items):raise ValueError('Out-of-range '+label)
    value=items[index]
    if not isinstance(value,dict):raise ValueError('Invalid '+label+' entry')
    return value


def finite_vector(value,length,label):
    if not isinstance(value,list) or len(value)!=length or any(type(v) not in (int,float) or not math.isfinite(v) for v in value):
        raise ValueError('Invalid '+label)
    return value


class EmbeddedGlb:
    def __init__(self,raw):
        if len(raw)<28:raise ValueError('Truncated GLB')
        magic,version,size=struct.unpack_from('<III',raw)
        if magic!=0x46546c67 or version!=2 or size!=len(raw):raise ValueError('Malformed GLB header')
        chunks=[];pos=12
        while pos<len(raw):
            if pos+8>len(raw):raise ValueError('Truncated GLB chunk header')
            length,kind=struct.unpack_from('<II',raw,pos);pos+=8
            if length%4 or pos+length>len(raw):raise ValueError('Invalid GLB chunk bounds/alignment')
            chunks.append((kind,raw[pos:pos+length]));pos+=length
        if [kind for kind,_ in chunks]!=[0x4e4f534a,0x004e4942]:
            raise ValueError('Expected one JSON chunk followed by one embedded BIN chunk')
        try:self.doc=json.loads(chunks[0][1])
        except (ValueError,UnicodeError) as error:raise ValueError('Invalid GLB JSON') from error
        if not isinstance(self.doc,dict) or not isinstance(self.doc.get('asset'),dict) or self.doc['asset'].get('version')!='2.0':raise ValueError('Expected glTF 2.0 asset')
        for name in ('bufferViews','accessors','nodes','meshes','scenes','materials','images','textures'):
            if name in self.doc and not isinstance(self.doc[name],list):raise ValueError('Invalid '+name+' table')
        self.binary=chunks[1][1]
        buffers=self.doc.get('buffers')
        if not isinstance(buffers,list) or len(buffers)!=1 or not isinstance(buffers[0],dict) or 'uri' in buffers[0]:raise ValueError('One embedded buffer required; external URIs are forbidden')
        self.length=integer(buffers[0].get('byteLength'),'buffer byteLength',1)
        if not 0<=len(self.binary)-self.length<=3 or any(self.binary[self.length:]):raise ValueError('BIN byteLength/padding mismatch')
        for view in self.doc.get('bufferViews',[]):self._view(view)
        for image in self.doc.get('images',[]):
            if not isinstance(image,dict) or 'uri' in image or image.get('mimeType')!='image/png':raise ValueError('Embedded PNG image required; external URIs are forbidden')
            if 'byteStride' in item(self.doc.get('bufferViews'),image.get('bufferView'),'image bufferView index'):
                raise ValueError('Image bufferView cannot have a vertex stride')
            self.view_bytes(image.get('bufferView'))

    def _view(self,view):
        if not isinstance(view,dict) or view.get('buffer')!=0 or type(view.get('buffer')) is not int:raise ValueError('Invalid bufferView buffer')
        offset=integer(view.get('byteOffset',0),'bufferView byteOffset')
        length=integer(view.get('byteLength'),'bufferView byteLength',1)
        if offset+length>self.length:raise ValueError('bufferView exceeds embedded buffer')
        if 'byteStride' in view:
            stride=integer(view['byteStride'],'bufferView byteStride',4)
            if stride>252 or stride%4:raise ValueError('Invalid vertex stride')
        return offset,length

    def view_bytes(self,index):
        view=item(self.doc.get('bufferViews'),index,'bufferView index')
        offset,length=self._view(view)
        return self.binary[offset:offset+length]

    def accessor(self,index,shape,components,label,expected_count=None):
        accessor=item(self.doc.get('accessors'),index,label+' accessor index')
        if 'sparse' in accessor or accessor.get('normalized',False) or accessor.get('type')!=shape:
            raise ValueError('Unsupported '+label+' accessor type/encoding')
        component=accessor.get('componentType')
        if type(component) is not int or component not in components:raise ValueError('Invalid '+label+' componentType')
        width,fmt={5121:(1,'B'),5123:(2,'H'),5125:(4,'I'),5126:(4,'f')}[component]
        dimensions={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[shape]
        count=integer(accessor.get('count'),label+' element count',1)
        if expected_count is not None and count!=expected_count:raise ValueError(label+' count differs from POSITION')
        view=item(self.doc.get('bufferViews'),accessor.get('bufferView'),label+' bufferView index')
        base,length=self._view(view)
        offset=integer(accessor.get('byteOffset',0),label+' byteOffset')
        size=width*dimensions;stride=view.get('byteStride',size)
        if label=='index' and 'byteStride' in view:raise ValueError('Indices must be tightly packed')
        if stride<size or stride%width or offset%width or (base+offset)%width:
            raise ValueError('Invalid '+label+' accessor alignment/stride')
        if offset+(count-1)*stride+size>length:raise ValueError(label+' accessor exceeds bufferView bytes')
        return accessor,count,(base+offset,stride,'<'+fmt*dimensions)

    def values(self,count,layout):
        start,stride,fmt=layout
        for i in range(count):yield struct.unpack_from(fmt,self.binary,start+i*stride)

    def geometry(self):
        doc=self.doc
        if doc.get('skins') or doc.get('animations'):raise ValueError('Static map geometry required')
        scene=item(doc.get('scenes'),doc.get('scene'),'default scene index')
        roots=scene.get('nodes')
        if not isinstance(roots,list) or not roots:raise ValueError('Scene has no root nodes')
        nodes=doc.get('nodes');meshes=doc.get('meshes');seen=set();mesh_seen=set();primitives=[]
        # Iterative traversal bounds work by the node table, not recursion depth.
        pending=list(roots)
        while pending:
            index=pending.pop();node=item(nodes,index,'scene node index')
            if index in seen:raise ValueError('Cyclic or multiply-parented scene node')
            seen.add(index)
            if node.get('extensions'):raise ValueError('Extended/instanced nodes are outside the map exporter contract')
            if 'skin' in node or 'weights' in node:raise ValueError('Skinned/morphed nodes are unsupported')
            if 'matrix' in node:
                if any(k in node for k in ('translation','rotation','scale')):raise ValueError('Node mixes matrix and TRS')
                matrix=finite_vector(node['matrix'],16,'node matrix')
                if any(abs(matrix[i])>1e-7 for i in (3,7,11)) or abs(matrix[15]-1)>1e-7:raise ValueError('Nonaffine node matrix')
                determinant=(matrix[0]*(matrix[5]*matrix[10]-matrix[9]*matrix[6])-matrix[4]*(matrix[1]*matrix[10]-matrix[9]*matrix[2])+matrix[8]*(matrix[1]*matrix[6]-matrix[5]*matrix[2]))
                if not math.isfinite(determinant) or determinant<=0:raise ValueError('Nonpositive/nonfinite node transform')
            else:
                finite_vector(node.get('translation',[0,0,0]),3,'node translation')
                scale=finite_vector(node.get('scale',[1,1,1]),3,'node scale')
                if min(scale)<=0:raise ValueError('Nonpositive node scale')
                rotation=finite_vector(node.get('rotation',[0,0,0,1]),4,'node rotation')
                if abs(sum(v*v for v in rotation)-1)>1e-4:raise ValueError('Nonunit node rotation')
            children=node.get('children',[])
            if not isinstance(children,list):raise ValueError('Invalid node children')
            pending.extend(children)
            if 'mesh' not in node:continue
            mesh_index=node['mesh'];mesh=item(meshes,mesh_index,'node mesh index')
            if mesh_index in mesh_seen:raise ValueError('Mesh instancing is outside the map exporter contract')
            mesh_seen.add(mesh_index)
            if mesh.get('weights'):raise ValueError('Morphed mesh is unsupported')
            parts=mesh.get('primitives')
            if not isinstance(parts,list) or not parts:raise ValueError('Scene mesh has no primitives')
            primitives.extend(parts)
        if not primitives:raise ValueError('Scene has no candidate geometry')
        if mesh_seen!=set(range(len(meshes))):raise ValueError('Orphan meshes are outside the exported scene')
        if len(primitives)>64:raise ValueError(f'GLB exceeds 64 primitives: {len(primitives)}')
        triangles=0;used_materials=set()
        for primitive in primitives:
            if not isinstance(primitive,dict):raise ValueError('Invalid primitive entry')
            if primitive.get('mode',4)!=4 or primitive.get('extensions') or primitive.get('targets'):
                raise ValueError('Uncompressed static triangle primitives required')
            attributes=primitive.get('attributes')
            if not isinstance(attributes,dict) or 'POSITION' not in attributes:raise ValueError('Missing POSITION attribute')
            accessor,vertices,layout=self.accessor(attributes['POSITION'],'VEC3',(5126,),'POSITION')
            if vertices<3:raise ValueError('Too few POSITION vertices')
            low=finite_vector(accessor.get('min'),3,'POSITION min');high=finite_vector(accessor.get('max'),3,'POSITION max')
            if any(a>b for a,b in zip(low,high)):raise ValueError('Invalid POSITION range')
            for point in self.values(vertices,layout):
                if not all(math.isfinite(v) for v in point):raise ValueError('Nonfinite POSITION')
                if any(v<a-1e-5*max(1,abs(a)) or v>b+1e-5*max(1,abs(b)) for v,a,b in zip(point,low,high)):
                    raise ValueError('POSITION lies outside declared range')
            if 'NORMAL' not in attributes:raise ValueError('Missing NORMAL attribute')
            vertex_fields=[('NORMAL','VEC3'),('TANGENT','VEC4')]
            for name in attributes:
                if name.startswith('TEXCOORD_'):
                    if not name[9:].isdigit():raise ValueError('Invalid texture coordinate semantic')
                    vertex_fields.append((name,'VEC2'))
            for name,shape in vertex_fields:
                if name not in attributes:continue
                _,count,layout=self.accessor(attributes[name],shape,(5126,),name,vertices)
                if any(not all(math.isfinite(v) for v in value) for value in self.values(count,layout)):
                    raise ValueError('Nonfinite '+name)
            if 'indices' in primitive:
                _,count,layout=self.accessor(primitive['indices'],'SCALAR',(5121,5123,5125),'index')
                if any(value[0]>=vertices for value in self.values(count,layout)):raise ValueError('Index exceeds POSITION vertex count')
            else:count=vertices
            if count%3:raise ValueError('Incomplete triangle primitive')
            triangles+=count//3
            material_index=primitive.get('material');item(doc.get('materials'),material_index,'primitive material index')
            used_materials.add(material_index)
        return primitives,triangles,used_materials

    def image_bytes(self,texture):
        if not isinstance(texture,dict) or texture.get('extensions'):raise ValueError('Expected untransformed texture coordinates')
        integer(texture.get('texCoord',0),'texture coordinate index')
        tex=item(self.doc.get('textures'),texture.get('index'),'texture index')
        image=item(self.doc.get('images'),tex.get('source'),'texture image index')
        return self.view_bytes(image.get('bufferView'))
