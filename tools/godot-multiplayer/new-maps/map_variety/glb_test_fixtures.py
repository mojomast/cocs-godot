"""Small real embedded geometry fixtures; no bpy or claimed native evidence."""
import json
import struct


def encode_glb(document,binary):
    text=json.dumps(document).encode();text+=b' '*((-len(text))%4)
    binary=bytes(binary)+b'\0'*((-len(binary))%4)
    return (struct.pack('<III',0x46546c67,2,28+len(text)+len(binary))+
            struct.pack('<II',len(text),0x4e4f534a)+text+
            struct.pack('<II',len(binary),0x004e4942)+binary)


def geometry_fixture(index_count=3,primitive_count=1,position_stride=12,position_prefix=0):
    binary=bytearray();views=[];accessors=[]
    def view(data,stride=None):
        binary.extend(b'\0'*((-len(binary))%4));start=len(binary);binary.extend(data)
        entry={'buffer':0,'byteOffset':start,'byteLength':len(data)}
        if stride is not None:entry['byteStride']=stride
        views.append(entry);return len(views)-1
    positions=[(0.,0.,0.),(1.,0.,0.),(0.,1.,0.)]
    position_bytes=b'\0'*position_prefix+b''.join(struct.pack('<fff',*p)+b'\0'*(position_stride-12) for p in positions)
    accessors.append({'bufferView':view(position_bytes,position_stride),'byteOffset':position_prefix,
                      'componentType':5126,'type':'VEC3','count':3,'min':[0,0,0],'max':[1,1,0]})
    attributes={'POSITION':0}
    for name,shape,values in [('NORMAL','VEC3',(0.,0.,1.)*3),('TANGENT','VEC4',(1.,0.,0.,1.)*3),('TEXCOORD_0','VEC2',(0.,0.,1.,0.,0.,1.))]:
        attributes[name]=len(accessors)
        accessors.append({'bufferView':view(struct.pack('<'+'f'*len(values),*values)),
                          'componentType':5126,'type':shape,'count':3})
    index_accessor=len(accessors)
    payload=(struct.pack('<HHH',0,1,2)*((index_count+2)//3))[:index_count*2]
    accessors.append({'bufferView':view(payload),'componentType':5123,'type':'SCALAR','count':index_count})
    primitive={'attributes':attributes,'indices':index_accessor,'material':0,'mode':4}
    document={'asset':{'version':'2.0'},'scene':0,'scenes':[{'nodes':[0]}],
              'nodes':[{'mesh':0}],'meshes':[{'primitives':[dict(primitive) for _ in range(primitive_count)]}],
              'buffers':[{'byteLength':len(binary)}],'bufferViews':views,'accessors':accessors,
              'materials':[{'name':'glass','pbrMetallicRoughness':{'baseColorFactor':[.1,.2,.3,1]}}]}
    return document,binary


def preserved_bindings():
    return {'schema':'map-variety-bindings/v1','materials':{'glass':{'role':'preserve'}},
            'pack':{'base':'assets/moth/map-variety-20261003/candidate-v2/manifest.json',
                    'overlay':'assets/moth/map-variety-20261003/candidate-v3/manifest.json'}}
