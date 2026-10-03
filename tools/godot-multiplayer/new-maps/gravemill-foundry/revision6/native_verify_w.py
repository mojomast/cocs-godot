"""Compare actual Godot-imported corner streams and readback pixels to actual GLB."""
import collections
import math
import struct
from pathlib import Path
from finish import HERE,ROOT,read,write,glb_parts,primitives,sha
from material_pack import linear_rgba

out=HERE/'evidence/W';report=read(out/'native-import.json')
art=ROOT/'godot/multiplayer_worlds/art/revisions/gravemill-foundry-r6.glb'
assert sha(art.read_bytes())==report['artHash']
doc,blob=glb_parts(art.read_bytes());expected=collections.defaultdict(list)
def canonical(points):
    index=min(range(3),key=lambda i:tuple(points[i:]+points[:i]))
    return tuple(points[index:]+points[:index]),index
for _,_,p,streams,faces in primitives(doc,blob):
    role=doc['materials'][p['material']]['name']
    for face in faces:
        # Godot clockwise front faces reverse glTF's counter-clockwise winding.
        face=list(reversed(face));points=[streams['POSITION'][i] for i in face];key,rotation=canonical(points)
        cs=[(streams['NORMAL'][i],streams['TANGENT'][i],streams['TEXCOORD_0'][i]) for i in face]
        expected[role,key].append(cs[rotation:]+cs[:rotation])
raw=(out/'native-streams.bin').read_bytes();max_error=[0,0,0];count=0;direction_error=0;hand_mismatches=[];undefined=[];defined_tangent_error=0
for surface in report['surfaces']:
    offset=surface['offset'];size=surface['vertices'];arrays=[]
    for width in (3,3,2,4):
        arrays.append([struct.unpack_from('<'+'f'*width,raw,offset+i*width*4) for i in range(size)]);offset+=size*width*4
    positions,normals,uvs,tangents=arrays
    indices=struct.unpack_from('<'+'I'*surface['indices'],raw,offset)
    for start in range(0,len(indices),3):
        face=indices[start:start+3];points=[positions[i] for i in face];key,rotation=canonical(points)
        candidates=expected[surface['material'],key]
        assert candidates,('Native position/winding/multiplicity mismatch',surface['material'],key)
        cs=[(normals[i],tangents[i],uvs[i]) for i in face];cs=cs[rotation:]+cs[:rotation]
        errors=[]
        for want in candidates:
            errors.append([max(abs(x-y) for a,b in zip(cs,want) for x,y in zip(a[k],b[k])) for k in range(3)])
        index=min(range(len(errors)),key=lambda i:max(errors[i]));err=errors[index]
        want=candidates[index]
        for corner,(actual_corner,source_corner) in enumerate(zip(cs,want)):
            if source_corner[1][:3]==(0.0,0.0,0.0):
                undefined.append({'role':surface['material'],'position':key[corner],'sourceTangent':source_corner[1],
                    'nativeTangent':actual_corner[1],'status':'Inherited undefined R5 tangent; native substitution recorded, not direction preservation'})
                assert actual_corner[1]==(-3.0518509447574615e-05,0.0,-1.0,1.0),'Unexpected native zero-direction substitution'
            else:
                defined_tangent_error=max(defined_tangent_error,max(abs(x-y) for x,y in zip(actual_corner[1],source_corner[1])))
        xyz_error=max(abs(x-y) for a,b in zip(cs,want) for x,y in zip(a[1][:3],b[1][:3]));direction_error=max(direction_error,xyz_error)
        if err[1]>.0002 and len(hand_mismatches)<20:
            hand_mismatches.append({'role':surface['material'],'points':key,'actual':cs,'expected':want,'xyzError':xyz_error})
        max_error=[max(a,b) for a,b in zip(max_error,err)]
        candidates.pop(index);count+=1
assert not any(expected.values())
pixel_checks=[]
for mat in doc['materials']:
    if mat['name']=='GM / orange':continue
    native=report['materials'][mat['name']]
    pbr=mat['pbrMetallicRoughness']
    assert abs(native['metallic']-pbr.get('metallicFactor',1))<1e-6
    assert abs(native['normalScale']-mat['normalTexture'].get('scale',1))<1e-6
    for channel,slot in [('albedo',pbr['baseColorTexture']),('normal',mat['normalTexture']),('roughness',pbr['metallicRoughnessTexture'])]:
        image=doc['images'][doc['textures'][slot['index']]['source']];view=doc['bufferViews'][image['bufferView']];start=view.get('byteOffset',0)
        expected_pixels=linear_rgba(blob[start:start+view['byteLength']])
        path=ROOT/'godot'/native['images'][channel]['path'].removeprefix('res://')
        actual_pixels=linear_rgba(path.read_bytes())
        assert expected_pixels==actual_pixels,('Native texture pixels differ',mat['name'],channel)
        pixel_checks.append({'material':mat['name'],'channel':channel,'readbackSha256':sha(path.read_bytes()),'decodedPixelsEqual':True})
result={'artHash':report['artHash'],'triangles':count,'exactPositionAndWindingMultiplicity':True,'maxNormalTangentUVError':max_error,
    'maxTangentXYZError':direction_error,'tangentMismatchExamples':hand_mismatches,
    'maxDefinedTangentError':defined_tangent_error,'inheritedUndefinedTangentCorners':undefined,
    'status':'Exact positions/UV and bounded normal/defined-tangent import verified; seven inherited undefined tangent substitutions remain explicitly unapproved',
    'pixelChecks':pixel_checks,'nativeGeometryScope':'Actual full-precision native mesh arrays, Godot clockwise winding, no generated LODs',
    'nativeVisualAcceptance':'pending manual review'}
write(out/'native-proof-diagnostic.json',result)
# Godot stores normal/tangent directions in octahedral signed 16-bit form even
# when position compression is disabled. Bound directional error; positions exact.
assert max_error[0]<=.0002 and defined_tangent_error<=.0002 and max_error[2]<=.00001,(max_error,defined_tangent_error)
assert len(undefined)==7,'Inherited tangent exception inventory changed'
write(out/'native-proof.json',result)
print('R6_NATIVE_PROOF',count,'triangles',len(pixel_checks),'material/channel pixel matches',max_error,'defined tangent max error',defined_tangent_error,'inherited undefined corners',len(undefined))
