"""Final R5 closure from actual artifacts and newly executed native receipts."""
import datetime
import json
from pathlib import Path
import statistics
import struct
import subprocess
import sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[4]
sys.path.insert(0,str(ROOT/'tools/map-variety-pipeline'))
from material_pack import sha,linear_rgba
from receipt import glb_parts,verify
def read(path):return json.loads(path.read_text())
def write(path,data):path.write_text(json.dumps(data,indent=2)+'\n')
native=ROOT/'godot/tests/new_maps/gravemill_foundry/revision5'
candidate=read(HERE/'candidate.json');export=read(HERE/'export-report.json');lineage=read(HERE/'material-lineage.json')
source=read(HERE/'source-validation.json');physics=read(native/'physics-report.json');imp=read(native/'import-report.json')
captures=read(native/'capture-report.json');reopen=read(HERE/'reopen-report.json')
assert len({candidate['geometryHash'],export['geometryHash'],lineage['geometryHash'],source['geometryHash'],physics['geometryHash']})==1
assert not physics['errors'] and physics['finiteCapsules']==physics['expected']==source['clearancePoints']==3849
assert not imp['errors'] and imp['triangles']==lineage['triangles'] and imp['meshNodes']==lineage['batches']
assert reopen['masterSha256']==export['master']['sha256']==sha((HERE/'gravemill-foundry-revision5.blend').read_bytes())
glb=ROOT/'godot/multiplayer_worlds/art/revisions/gravemill-foundry-r5.glb'
assert sha(glb.read_bytes())==export['glb']['sha256']==lineage['glbSha256']
doc,blob=glb_parts(glb.read_bytes());images=[];image_views=set()
for image in doc['images']:
 view=doc['bufferViews'][image['bufferView']];image_views.add(image['bufferView']);offset=view.get('byteOffset',0);raw=blob[offset:offset+view['byteLength']]
 extracted=glb.parent/('gravemill-foundry-r5_'+image['name']+'.png');assert extracted.read_bytes()==raw
 sidecar=Path(str(extracted)+'.import');assert sidecar.is_file()
 text=sidecar.read_text();assert 'compress/mode=0' in text and 'mipmaps/generate=true' in text
 images.append({'path':str(extracted.relative_to(ROOT)),'sha256':sha(raw),'bytes':len(raw),'dimensions':list(struct.unpack_from('>II',raw,16)),'importSha256':sha(sidecar.read_bytes())})
pack_receipt=verify(read(HERE/'pack-candidate.json'),True);write(HERE/'pack-receipt.json',pack_receipt)
assert len(captures['captures'])==22
manifest=[];by_view={};timing=[]
for c in captures['captures']:
 p=HERE/'evidence/native'/(c['view']+'-'+c['variant']+'.png');raw=p.read_bytes();assert sha(raw)==c['sha256'];assert struct.unpack_from('>II',raw,16)==(1280,720)
 assert not c['weatherLook']['capped'] and c['emissionPreserved']
 if c['variant']=='candidate-runtime-r5':assert c['geometryHash']==candidate['geometryHash'];timing.append(c['staticViewMeanFrameMs'])
 expected=next(v for v in source['cameraChecks'] if v['id']==c['view']);assert c['eye']==expected['eye'] and c['target']==expected['target']
 by_view.setdefault(c['view'],{})[c['variant']]=p
 manifest.append({'path':str(p.relative_to(ROOT)),'sha256':sha(raw),'bytes':len(raw),'width':1280,'height':720,'view':c['view'],'variant':c['variant'],'geometryHash':c['geometryHash']})
pairs=[]
for view,paths in by_view.items():
 a=linear_rgba(paths['accepted-finish-before'].read_bytes())[2];b=linear_rgba(paths['candidate-runtime-r5'].read_bytes())[2]
 difference=sum(a[i:i+4]!=b[i:i+4] for i in range(0,len(a),4));assert difference>0
 pairs.append({'view':view,'actualDifferingPixels':difference})
write(HERE/'evidence/image-manifest.json',{'scope':'True accepted runtime finish before vs exact staged R5 runtime services; parent visual review pending','images':manifest,'decodedPixelComparisons':pairs})
attempts=[]
for p in sorted((HERE/'evidence/attempts').glob('*.json')):
 d=read(p)
 if 'command' not in d or 'end' not in d:continue
 attempts.append({'receipt':str(p.relative_to(ROOT)),'command':d['command'],'returncode':d['returncode'],
 'elapsedSeconds':(datetime.datetime.fromisoformat(d['end'])-datetime.datetime.fromisoformat(d['start'])).total_seconds()})
render_rows=[c for c in captures['captures'] if c['variant']=='candidate-runtime-r5']
result={'kind':'Foundry-R5-corrective-production','status':'Actual export, packed-master reopen, source rays, native import/capsules and staged-runtime captures passed; parent/manual/hosted approval pending',
 'geometryHash':candidate['geometryHash'],'authoritySha256':sha((HERE/'candidate.json').read_bytes()),'glb':export['glb'],'master':export['master'],
 'sourceObjects':export['sourceObjects'],'triangles':lineage['triangles'],'batches':lineage['batches'],'texturedPBRMaterials':len(lineage['materialLineage']),'totalMaterials':len(doc['materials']),
 'embeddedImages':len(images),'imageClosure':images,'authorityChanges':candidate['arena']['art']['revision5'],'authorityCounts':source['authority'],
 'actualShapeChecks':len(lineage['shapes']),'actualDrumsWithAllOutwardFacesAndNormals':sum(s['kind']=='drum' for s in lineage['shapes']),
 'source':source,'nativePhysics':physics,'nativeImport':imp,'packedMasterReopen':reopen,'nativeCaptures':22,
 'captureReport':str((native/'capture-report.json').relative_to(ROOT)),'imageManifest':'evidence/image-manifest.json',
 'preservedOrange':lineage['preservedEmission'],'baselineMaterialRoles':export['baselineMaterialRoles'],'stagedProfileLineage':read(native/'profile-lineage.json'),
 'performance':{'backend':sorted({c['renderer'] for c in render_rows}),'staticViewMeanFrameMs':{'min':min(timing),'median':statistics.median(timing),'max':max(timing)},
 'peakReportedVideoMemoryBytes':max(c['videoMemoryBytes'] for c in render_rows),'peakReportedStaticMemoryBytes':max(c['staticMemoryBytes'] for c in render_rows),
 'scope':'8-frame static-view samples on Mesa llvmpipe, including settle/compile costs; warmed isolated import cache; no dedicated-GPU or hosted movement FPS claim'},
 'budget':{**lineage['budget'],'embeddedPNGBytes':sum(doc['bufferViews'][i]['byteLength'] for i in image_views),
 'nonImageBufferBytes':sum(v['byteLength'] for i,v in enumerate(doc['bufferViews']) if i not in image_views),
 'reason':'Full float32 vertex/normal/UV/tangent streams with hard-edge/UV splits and lossless embedded source PNGs. Useful editable detail retained; triangle and byte guidelines are not hard acceptance ceilings.'},
 'attempts':attempts,'acceptance':{'sourceModes':source['modes'],'hostedModesExecuted':[],'hostedSixModeJourneys':'pending','manualPlayerReview':'pending','publicPromotion':False},
 'limitations':['Clear weather selected by the production WeatherService at authored seed/time; weather path exercised, not every weather preset.',
 'One exact-centre native floor ray lies on a float32 seam: all four 5mm-neighbor support rays and the finite capsule pass; documented in native receipt.',
 'Static views contain no operator/team combat actors; palette assets are untouched, live team readability remains hosted/manual review.',
 'R4 remains rejected immutable evidence. Failed/superseded S artifacts, reports, captures and all command logs are retained under evidence/attempts.']}
write(HERE/'production-report.json',result)
print(json.dumps({k:result[k] for k in ['geometryHash','triangles','batches','nativeCaptures','performance']}))
