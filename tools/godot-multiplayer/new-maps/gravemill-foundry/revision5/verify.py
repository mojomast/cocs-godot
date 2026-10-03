"""Read actual GLB triangles/normals/PNG pixels; never trust builder counts."""
import collections
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[4]
sys.path.insert(0,str(ROOT/'tools/map-variety-pipeline'))
from receipt import glb_parts,inspect_art
from material_pack import load_pack,linear_rgba,srgb_png,sha
sys.path.insert(0,str(HERE))
from shapes import cross,sub,dot,volume

def verify():
 path=ROOT/'godot/multiplayer_worlds/art/revisions/gravemill-foundry-r5.glb';raw=path.read_bytes();doc,blob=glb_parts(raw)
 report=json.loads((HERE/'export-report.json').read_text());spec=json.loads((HERE/'shapes.json').read_text())
 assert sha(raw)==report['glb']['sha256'];assert sha((HERE/'gravemill-foundry-revision5.blend').read_bytes())==report['master']['sha256']
 def accessor(i):
  a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']];fmt={5126:'f',5125:'I',5123:'H'}[a['componentType']]*{'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
  size=struct.calcsize('<'+fmt);off=v.get('byteOffset',0)+a.get('byteOffset',0)
  return [struct.unpack_from('<'+fmt,blob,off+j*v.get('byteStride',size)) for j in range(a['count'])]
 components=[];triangles=0;all_new=[];actual_triangles=collections.defaultdict(list)
 def triangle_key(v):return tuple(sorted(tuple(round(x,4) for x in p) for p in v))
 for node in doc['nodes']:
  if 'mesh' not in node:continue
  assert not any(k in node for k in ('translation','rotation','scale','matrix')),node['name']
  for p in doc['meshes'][node['mesh']]['primitives']:
   assert 'TANGENT' in p['attributes'];idx=[a[0] for a in accessor(p['indices'])];triangles+=len(idx)//3
   if node.get('extras',{}).get('kit_sector')!='new-hero':continue
   vertices=accessor(p['attributes']['POSITION']);normals=accessor(p['attributes']['NORMAL']);faces=[idx[i:i+3] for i in range(0,len(idx),3)]
   all_new.extend([[vertices[i] for i in f] for f in faces])
   mat=doc['materials'][p['material']]['name']
   for f in faces:actual_triangles[(mat,triangle_key([vertices[i] for i in f]))].append(([vertices[i] for i in f],[normals[i] for i in f]))
   parent=list(range(len(vertices)))
   def root(i):
    while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
    return i
   def union(a,b):parent[root(a)]=root(b)
   seen={}
   for i,v in enumerate(vertices):
    if v in seen:union(i,seen[v])
    else:seen[v]=i
   for f in faces:union(f[0],f[1]);union(f[0],f[2])
   groups={}
   for f in faces:groups.setdefault(root(f[0]),[]).append(f)
   for fs in groups.values():
    ids={i for f in fs for i in f};lo=[min(vertices[i][k] for i in ids) for k in range(3)];hi=[max(vertices[i][k] for i in ids) for k in range(3)]
    center=[(a+b)/2 for a,b in zip(lo,hi)];vol=sum(dot(sub(vertices[f[0]],center),cross(sub(vertices[f[1]],center),sub(vertices[f[2]],center)))/6 for f in fs)
    components.append({'material':doc['materials'][p['material']]['name'],'bounds':[lo,hi],'volume':vol,'faces':fs,'ids':ids,'vertices':vertices,'normals':normals})
 checked=[];used=set();component_spec=json.loads((HERE/'component-triangles.json').read_text())
 for shape in spec['shapes']:
  expected=[[min(v[k] for v in shape['vertices']) for k in range(3)],[max(v[k] for v in shape['vertices']) for k in range(3)]]
  # A contact seam may share identical positions with another object. Match a
  # multiplicity-preserving triangle inventory, then measure GLB data itself.
  v=[];n=[];fs=[]
  for tri in component_spec[shape['id']]:
   key=(shape['material'],triangle_key(tri));assert actual_triangles[key],('missing exported triangle',shape['id'],key)
   positions,norm=actual_triangles[key].pop();fs.append(list(range(len(v),len(v)+3)));v.extend(positions);n.extend(norm)
  bounds=[[min(p[k] for p in v) for k in range(3)],[max(p[k] for p in v) for k in range(3)]]
  assert max(abs(a-b) for x,y in zip(expected,bounds) for a,b in zip(x,y))<.06,shape['id']
  center=[(a+b)/2 for a,b in zip(*bounds)]
  vol=sum(dot(sub(v[f[0]],center),cross(sub(v[f[1]],center),sub(v[f[2]],center)))/6 for f in fs)
  c={'vertices':v,'normals':n,'faces':fs,'ids':range(len(v)),'bounds':bounds,'volume':vol}
  assert vol>0,(shape['id'],vol)
  item={'id':shape['id'],'kind':shape['kind'],'bounds':c['bounds'],'signedVolume':c['volume'],'triangles':len(c['faces'])}
  if shape['kind']=='drum':
   v,n,center=c['vertices'],c['normals'],shape['center']
   outward_faces=sum(dot(cross(sub(v[f[1]],v[f[0]]),sub(v[f[2]],v[f[0]])),sub([sum(v[i][k] for i in f)/3 for k in range(3)],center))>0 for f in c['faces'])
   outward_normals=sum(dot(n[i],sub(v[i],center))>0 for i in c['ids'])
   assert outward_faces==len(c['faces']) and outward_normals==len(c['ids']),(shape['id'],outward_faces,outward_normals)
   item.update({'axis':shape['axis'],'outwardFaces':outward_faces,'outwardNormals':outward_normals,'vertexNormals':len(c['ids'])})
  checked.append(item)
 assert not any(actual_triangles.values()),'unaccounted exported new triangles'
 pack,hashes=load_pack(ROOT);assert hashes==report['moth']['pack']
 def image_bytes(slot):
  im=doc['images'][doc['textures'][slot['index']]['source']];v=doc['bufferViews'][im['bufferView']];o=v.get('byteOffset',0);return blob[o:o+v['byteLength']]
 old,_=glb_parts((ROOT/'godot/multiplayer_worlds/art/worlds/gravemill-foundry.glb').read_bytes())
 old_orange=next(m for m in old['materials'] if m['name']=='GM / orange');new_orange=next(m for m in doc['materials'] if m['name']=='GM / orange')
 def numeric_equal(a,b):
  if isinstance(a,dict):return set(a)==set(b) and all(numeric_equal(v,b[k]) for k,v in a.items())
  if isinstance(a,list):return len(a)==len(b) and all(numeric_equal(x,y) for x,y in zip(a,b))
  if isinstance(a,(int,float)) and not isinstance(a,bool):return abs(a-b)<1e-6
  return a==b
 assert numeric_equal(old_orange,new_orange),(old_orange,new_orange)
 lineage={};bindings={'GM / orange':{'role':'preserve'}}
 for m in doc['materials']:
  if m['name']=='GM / orange':continue
  name=m['name'];res=report['moth']['materials'][name]['resource'];channels=pack[res]['channels']
  color=image_bytes(m['pbrMetallicRoughness']['baseColorTexture']);normal=image_bytes(m['normalTexture']);rough=image_bytes(m['pbrMetallicRoughness']['metallicRoughnessTexture'])
  assert color==srgb_png(channels['albedo']['path'].read_bytes());assert sha(normal)==channels['normal']['sha256']
  w,h,pixels=linear_rgba(channels['roughness']['path'].read_bytes());ew,eh,output=linear_rgba(rough);assert (w,h)==(ew,eh)
  error=max(abs(pixels[i]-output[i+1]) for i in range(0,len(pixels),4));assert error<=1
  lineage[name]={'resource':res,'sourceAlbedoSha256':channels['albedo']['sha256'],'embeddedSrgbAlbedoSha256':sha(color),
   'normalSourceAndEmbeddedSha256':sha(normal),'sourceRoughnessSha256':channels['roughness']['sha256'],'embeddedPackedRoughnessSha256':sha(rough),
   'roughnessMaxQuantizationError':error,'tileMeters':pack[res]['tileMeters']}
  bindings[name]={'role':'surface','normal':True,'resource':res,'tileMeters':pack[res]['tileMeters']}
 inspection=inspect_art(raw,bindings,24)
 result={'kind':'actual-R5-GLB-shape-and-pixel-proof','geometryHash':report['geometryHash'],'glbSha256':sha(raw),
  'masterSha256':report['master']['sha256'],'pack':hashes,'materialLineage':lineage,'shapes':checked,
  'triangles':triangles,'batches':inspection['primitives'],'images':len(doc['images']),'glbBytes':len(raw),
  'preservedEmission':{'accepted':old_orange,'candidate':new_orange,'equalWithin':1e-6},
  'budget':{'trianglesGuideline':150000,'trianglePolicy':'User permits useful higher detail; evaluated cost and correctness govern review, not a hard triangle ceiling.',
   'batchesTarget':16,'bytesDesignTarget':7000000,'bytesOverTarget':max(0,len(raw)-7000000),'review':'Measured backend/load/cadence review; design target is not a correctness failure.'}}
 (HERE/'material-lineage.json').write_text(json.dumps(result,indent=2)+'\n')
 (HERE/'visual-triangles.json').write_text(json.dumps(all_new,separators=(',',':'))+'\n')
 art={'blend':str((HERE/'gravemill-foundry-revision5.blend').relative_to(ROOT)),'blendSha256':report['master']['sha256'],
  'glb':str(path.relative_to(ROOT)),'glbSha256':sha(raw),'lineage':str((HERE/'material-lineage.json').relative_to(ROOT)),
  'lineageSha256':sha((HERE/'material-lineage.json').read_bytes()),'maxPrimitives':24}
 candidate={'schemaVersion':2,'moth':{'manifest':'assets/moth/map-variety-20261003/candidate-v3/manifest.json','sha256':hashes['overlaySha256']},
  'maps':[{'id':'gravemill-foundry','authority':{'path':str((HERE/'candidate.json').relative_to(ROOT)),'sha256':report['authoritySha256'],'geometryHash':report['geometryHash']},'materials':bindings,'art':art}]}
 (HERE/'pack-candidate.json').write_text(json.dumps(candidate,indent=2)+'\n')
 print('R5_ACTUAL_GL B_PROOF',json.dumps({k:result[k] for k in ['triangles','batches','images','glbBytes','budget']}),'components',len(checked))
if __name__=='__main__':verify()
