"""Deterministic additive source derivation, never staging or native execution.

write exclusively creates new versioned source files. check/diff are read-only.
Every replacement asserts its occurrence count. Old source hashes are mandatory.
"""
import argparse,difflib,hashlib,json
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
OLD=ROOT/'tools/godot-multiplayer/new-maps/walker-parity-admission'
GD=ROOT/'godot/tests/walker_parity_admission';NEWGD=ROOT/'godot/tests/walker_calibrated_admission'
PHASE='parity-admission-calibrated-v1';MODE='calibrated-controls';SCOPE='calibrated-admission'
def replace(text,old,new,n=1):
    if text.count(old)!=n:raise ValueError('source delta occurrence: '+repr(old))
    return text.replace(old,new)
def originals():
    pins=json.loads((OLD/'review-pins.json').read_text())
    for group in ['stageInputs','hostInputs','productionDependencies']:
        for name,h in pins[group].items():
            if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=h:raise ValueError('approved AK source drift: '+name)
    if hashlib.sha256((GD/'evidence.gd').read_bytes()).hexdigest()!='19b7c024e3f15a365cd0289bef45fc069f3908fd9325359dccffc556a3242be8':raise ValueError('corrected Evidence pin')
def version(t):
    return t.replace('parity-admission-synthetic-v1',PHASE).replace('synthetic-controls',MODE).replace('synthetic-admission',SCOPE)
def render():
    originals();out={}
    for path in [GD/'policy.gd',GD/'evidence.gd',GD/'observe.gd',GD/'driver.gd',OLD/'policy.py',OLD/'evidence.py',OLD/'receipt_fixtures.py']:
        t=version(path.read_text());name=path.name
        if path.suffix=='.py':
            if name=='receipt_fixtures.py':
                t=replace(t,'from evidence import canonical,IDS,REASONS','from .evidence import canonical,IDS,REASONS')
                t=replace(t,'from evidence import footprint','from .evidence import footprint')
                t=replace(t,'def support_fixture(after,name):','def support_fixture(after,name,rise=.15):')
                t=replace(t,"'point':[pos[0],.15,pos[2]]","'point':[pos[0],rise,pos[2]]")
                t=replace(t,"pair['profiles'].append(p);yaw=spec.get('yaw',0)","pair['profiles'].append(p);rise=spec.get('rise',.15);yaw=spec.get('yaw',0)")
                t=replace(t,"back=.15+3*math.tan(math.radians(spec['incline']));vertices=[[-2,.15,0],[-2,back,3],[2,back,3],[2,.15,0]]","back=rise+3*math.tan(math.radians(spec['incline']));vertices=[[-2,rise,0],[-2,back,3],[2,back,3],[2,rise,0]]")
                t=replace(t,"p['geometry']=[{'name':'InclinedLanding' if inclined else 'PositiveTread','rid':100}]","p['geometry']=[{'name':'InclinedLanding' if inclined else 'PositiveTread','rid':100,'bodyTransform':state([0,0,0])['transform'],'offset':state([0,0,0])['transform'],'linearVelocity':[0,0,0],'shapeData':{'backface_collision':True,'faces':copy.deepcopy(faces)}}]")
                t=replace(t,"pos=[direction[0]*(.1+.1*tick),.15,direction[2]*(.1+.1*tick)]","pos=[direction[0]*(.1+.1*tick),rise,direction[2]*(.1+.1*tick)]")
                t=replace(t,'landingY=.15','landingY=rise')
                t=replace(t,"support_fixture(after,'actual-final-support')","support_fixture(after,'actual-final-support',rise)")
                t=replace(t,"support_fixture(after,'fresh-full-tread-support')","support_fixture(after,'fresh-full-tread-support',rise)")
                t=replace(t,"parentPositionDelta=[horizontal[0],-.05,horizontal[2]],parentRealVelocity=[horizontal[0]*60,-3,horizontal[2]*60]","parentPositionDelta=[horizontal[0],rise-.2,horizontal[2]],parentRealVelocity=[horizontal[0]*60,(rise-.2)*60,horizontal[2]*60]")
                t=replace(t,"row.update(bodyRid=200,floorConstantSpeed=False)","row.update(bodyRid=200,floorConstantSpeed=False)\n                if not negative and not inclined and not experimental and active:\n                    row['slides']=[{'colliderRid':100,'colliderShapeIndex':0,'point':[0,rise,0],'normal':[-direction[0]*math.sqrt(.75),.5,-direction[2]*math.sqrt(.75)]}]")
            if name=='policy.py':
                t=replace(t,'from evidence import campaign','from .evidence import campaign')
                t=replace(t,'def validate(g,*,group,mode,grant_id,source_hash,engine_hash,now):','ENGINE="5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae"\ndef validate(g,*,group,mode,grant_id,source_hash,engine_hash,now):\n    if engine_hash!=ENGINE:raise ValueError("pinned engine")')
            if name=='evidence.py':
                t=replace(t,"    return [{'id':str(r)+':'+str(deg)","    return [{**({'rise':.15 if r==.35 else .18} if group=='positive-step-admission' else {}),'id':str(r)+':'+str(deg)")
                t=replace(t,'abs(y-.15)','abs(y-spec[\'rise\'])')
                t=replace(t,"    points=[[-2,.15,0],[-2,.15+3*math.tan(math.radians(spec['incline'])),3],[2,.15+3*math.tan(math.radians(spec['incline'])),3],[2,.15,0]]","    rise=spec.get('rise',.15)\n    points=[[-2,rise,0],[-2,rise+3*math.tan(math.radians(spec['incline'])),3],[2,rise+3*math.tan(math.radians(spec['incline'])),3],[2,rise,0]]")
                t=replace(t,"not near(plan.get('landingY'),.15)","not near(plan.get('landingY'),spec['rise'])")
                t=replace(t,"final['epsilon'],.15,'fresh-full-tread-support'","final['epsilon'],spec['rise'],'fresh-full-tread-support'")
                t=replace(t,'up not in (0,1)','(up != 0 and up != 1)')
                t=replace(t,"    return any(near(g.get('rid'),p['targetRid'],0) and g.get('name')==('InclinedLanding' if spec['incline'] else 'PositiveTread') for g in p['geometry'])","    return any(near(g.get('rid'),p['targetRid'],0) and g.get('name')==('InclinedLanding' if spec['incline'] else 'PositiveTread') and (spec['incline']!=0 or positive_mesh(g,faces)) for g in p['geometry'])")
                t=replace(t,"stall=stall+1 if distance(row['wholeFrameDelta'],[0,0,0])<.0001 else 0","stall=stall+1 if distance(row['wholeFrameDelta'],[0,0,0])<.0001 and (negative or inclined or experimental or baseline_target(row,p['target'])) else 0")
                t += PY_EVIDENCE
            out[HERE/name]=(path,t)
        else:
            if name=='evidence.gd':
                t=replace(t,'\treturn rows\n','\tif group=="positive-step-admission":\n\t\tfor spec: Dictionary in rows: spec.rise = .15 if spec.radius==.35 else .18\n\treturn rows\n')
                t=replace(t,'absf(p[1]-.15)','absf(p[1]-spec.rise)')
                t=replace(t,'near(getv(plan,"landingY"),.15)','near(getv(plan,"landingY"),spec.rise)')
                t=replace(t,'final.epsilon,.15,"fresh-full-tread-support"','final.epsilon,spec.rise,"fresh-full-tread-support"')
                t=replace(t,'var back: float = .15+3*tan(deg_to_rad(spec.incline))\n\tvar points := [[-2,.15,0],[-2,back,3],[2,back,3],[2,.15,0]]','var rise: float = spec.get("rise",.15)\n\tvar back: float = rise+3*tan(deg_to_rad(spec.incline))\n\tvar points := [[-2,rise,0],[-2,back,3],[2,back,3],[2,rise,0]]')
                t=replace(t,'("InclinedLanding" if spec.incline>0 else "PositiveTread"): return true','("InclinedLanding" if spec.incline>0 else "PositiveTread") and (spec.incline>0 or positive_mesh(g,t.faces)): return true')
                t=replace(t,'stall+1 if distance(row.wholeFrameDelta,[0,0,0])<.0001 else 0','stall+1 if distance(row.wholeFrameDelta,[0,0,0])<.0001 and (negative or inclined or experimental or baseline_target(row,p.target)) else 0')
                t += GD_EVIDENCE
            if name=='observe.gd':t=replace(t,'absf(body.global_position.y-.15)','absf(body.global_position.y-float(fixture.faces[0].y))')
            if name=='driver.gd':
                t=replace(t,'preload("candidate.gd")','preload("res://tests/walker_parity_admission/candidate.gd")')
                t=replace(t,'preload("res://tests/walker_admission/fixtures_v4.gd")','preload("fixtures.gd")')
                t=replace(t,'absf(body.global_position.y-.15)','absf(body.global_position.y-float(fixture.faces[0].y))')
                t=replace(t,'r.wholeFrameDelta.length()<.0001 else 0','r.wholeFrameDelta.length()<.0001 and (experimental or spec.incline>0 or Policy.Evidence.baseline_target(Observe.encode(r),Observe.encode(active_profile.target))) else 0')
                t=replace(t,'\tfor path: String in config.files:', '\tif not config.get("positiveCases") is Array or config.positiveCases.size()!=4 or config.get("lineage")!=Policy.LINEAGE: fail_admission("source.calibrated_selection");return\n\tfor i in 4:\n\t\tif not Policy.Evidence.spec_equal(config.positiveCases[i],Policy.Evidence.canonical(Policy.GROUPS[2])[i]): fail_admission("source.calibrated_census");return\n\tfor path: String in config.files:')
            if name=='policy.gd':
                t += '\nconst ENGINE := "5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae"\nconst LINEAGE := '+json.dumps(lineage(),separators=(',',':'))+'\n'
                t=replace(t,'return hash_valid(source_hash) and hash_valid(engine_hash)','return engine_hash==ENGINE and hash_valid(source_hash) and hash_valid(engine_hash)')
            out[NEWGD/name]=(path,t)
    return out
def lineage():
    return {'ALManifestSha256':'bef580de4e1605446425927bf9ee3f07dfb61992bfd6bb50af48369db7f738b5','AKManifestSha256':'827dd68b00c400b7ec17f9ab0e5a2067929277c3bb22e1681d38a1d5143a5ee1','selectionSha256':hashlib.sha256((HERE/'selection.json').read_bytes()).hexdigest(),'role':'selection-lineage-not-admission'}
PY_EVIDENCE='''
def positive_mesh(g,faces):
    identity={'origin':[0,0,0],'basis':[[1,0,0],[0,1,0],[0,0,1]]}
    data=g.get('shapeData')
    return (same_transform(g.get('bodyTransform'),identity,1e-6) and same_transform(g.get('offset'),identity,1e-6)
        and zero(g.get('linearVelocity')) and isinstance(data,dict) and data.get('backface_collision') is True
        and isinstance(data.get('faces'),list) and len(data['faces'])==6 and all(distance(a,b)<=1e-6 for a,b in zip(data['faces'],faces)))
def baseline_target(row,t):
    if row['after'].get('grounded') is not True:return False
    for c in row['slides']:
        n=c.get('normal');point=c.get('point')
        if not near(c.get('colliderRid'),t['rid'],0) or not near(c.get('colliderShapeIndex'),0,0) or not vec(n) or not vec(point) or not 0<point[1]<.25:continue
        if abs(distance(n,[0,0,0])-1)>=.0001 or abs(point[1]-t['faces'][0][1])>1e-6:continue
        flat=math.hypot(n[0],n[2])
        if flat>0 and -(n[0]*t['direction'][0]+n[2]*t['direction'][2])/flat>=.98:return True
    return False
'''
GD_EVIDENCE='''
static func positive_mesh(g: Dictionary,faces: Array) -> bool:
	var identity := {"origin":[0,0,0],"basis":[[1,0,0],[0,1,0],[0,0,1]]}
	var data: Variant = g.get("shapeData")
	if not same_transform(g.get("bodyTransform"),identity,1e-6) or not same_transform(g.get("offset"),identity,1e-6) or not zero(g.get("linearVelocity")) or not data is Dictionary or not flag(data.get("backface_collision"),true) or not data.get("faces") is Array or data.faces.size()!=6: return false
	for i in 6:
		if distance(data.faces[i],faces[i])>1e-6: return false
	return true
static func baseline_target(row: Dictionary,t: Dictionary) -> bool:
	if not flag(getv(row.after,"grounded"),true): return false
	for c: Variant in row.slides:
		var n: Variant = getv(c,"normal");var point: Variant = getv(c,"point")
		if not near(getv(c,"colliderRid"),t.rid,0) or not near(getv(c,"colliderShapeIndex"),0,0) or not vec(n) or not vec(point) or point[1]<=0 or point[1]>=.25: continue
		if absf(distance(n,[0,0,0])-1)>=.0001 or absf(point[1]-t.faces[0][1])>1e-6: continue
		var flat := sqrt(n[0]*n[0]+n[2]*n[2])
		if flat>0 and -(n[0]*t.direction[0]+n[2]*t.direction[2])/flat>=.98: return true
	return false
'''
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('operation',choices=['write','check','diff']);a=parser.parse_args()
    for dest,(source,text) in render().items():
        if a.operation=='write':
            with dest.open('x') as f:f.write(text)
        elif a.operation=='check':
            if dest.read_text()!=text:raise ValueError('derived version drift: '+str(dest))
        elif a.operation=='diff':print(''.join(difflib.unified_diff(source.read_text().splitlines(True),text.splitlines(True),fromfile=str(source.relative_to(ROOT)),tofile=str(dest.relative_to(ROOT)),n=0)),end='')
