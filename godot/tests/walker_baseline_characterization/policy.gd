extends RefCounted
## Encoded-operand replay, also used before every classification. Unparsed source.
const Fixture = preload("fixture.gd")
const Observe = preload("observe.gd")
const PHASE := "baseline-characterization-v1"
const MODE := "baseline-only"
const GROUP := "radius-rise"
const ENGINE := "5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae"
const AK := "827dd68b00c400b7ec17f9ab0e5a2067929277c3bb22e1681d38a1d5143a5ee1"
const AK_RESULT := "76130effe1da05bfc800fa8e14bea5b0382b87b130899a3cc1b52e2dab9bb6d7"
const EPS := .000001
const IDENTITY := [[1,0,0],[0,1,0],[0,0,1]]
const KEYS := ["phase","mode","allowedGroups","grantId","authorized","expiresUnix","sourceSha256","engineSha256"]
static func number(x: Variant) -> bool:
	return (x is int or x is float) and is_finite(float(x))
static func integer(x: Variant) -> bool:
	return number(x) and x==floor(x)
static func count(x: Variant,n: int) -> bool:
	return integer(x) and x==n
static func hash_valid(x: Variant) -> bool:
	if not x is String or x.length()!=64: return false
	for c: String in x:
		if not c in "0123456789abcdef": return false
	return true
static func grant_valid(g: Dictionary, group: String, mode: String, id: String, source: String, engine: String, now: float) -> bool:
	if g.size()!=8: return false
	for k: String in KEYS:
		if not g.has(k): return false
	return g.phase==PHASE and g.mode==MODE and mode==MODE and group==GROUP and g.allowedGroups==[GROUP] and g.authorized is bool and g.authorized and g.grantId==id and id.length()>0 and id.length()<=128 and number(g.expiresUnix) and g.expiresUnix>now and hash_valid(source) and g.sourceSha256==source and engine==ENGINE and g.engineSha256==engine
static func close(a: Variant,b: Variant,e: float = EPS) -> bool:
	return number(a) and number(b) and absf(float(a)-float(b))<=e
static func vec(v: Variant) -> bool:
	return v is Array and v.size()==3 and number(v[0]) and number(v[1]) and number(v[2])
static func near(a: Variant,b: Variant,e: float = EPS) -> bool:
	return vec(a) and vec(b) and close(a[0],b[0],e) and close(a[1],b[1],e) and close(a[2],b[2],e)
static func v(a: Array) -> Vector3:
	return Vector3(a[0],a[1],a[2])
static func basis(s: Dictionary) -> Array:
	var t := deg_to_rad(float(s.yawDegrees));return [[cos(t),0,-sin(t)],[0,1,0],[sin(t),0,cos(t)]]
static func transform(t: Variant,b: Array) -> bool:
	if not t is Dictionary or t.size()!=2 or not vec(t.get("origin")) or not t.get("basis") is Array or t.basis.size()!=3: return false
	for i in 3:
		if not near(t.basis[i],b[i]): return false
	return true
static func parameters(p: Dictionary,s: Dictionary) -> bool:
	var expected := {"radius":s.radius,"height":1.8,"margin":.02,"snap":.3,"floorAngle":deg_to_rad(46.0),"walk":6,"sprint":10,"gravity":20,"jump":6.5,"layer":1,"mask":1,"motionMode":0,"maxSlides":6,"wallMinSlideAngle":deg_to_rad(15.0),"platformFloorLayers":4294967295,"platformWallLayers":0,"platformOnLeave":0}
	for k: String in expected:
		if not close(p.get(k),expected[k]): return false
	for k: String in ["layer","mask","motionMode","maxSlides","platformFloorLayers","platformWallLayers","platformOnLeave"]:
		if not count(p.get(k),int(expected[k])): return false
	for k: String in ["floorStopOnSlope","floorBlockOnWall","slideOnCeiling"]:
		if not p.get(k) is bool or not p[k]: return false
	if not p.get("floorConstantSpeed") is bool or p.floorConstantSpeed or p.get("exceptions")!=[] or not near(p.get("up"),[0,1,0]) or not transform(p.get("offset"),IDENTITY) or not near(p.offset.origin,[0,.9,0]): return false
	return integer(p.get("bodyRid")) and p.bodyRid>0 and integer(p.get("shapeRid")) and p.shapeRid>0
static func geometry(g: Dictionary,s: Dictionary) -> bool:
	if g.size()!=2 or not g.get("base") is Dictionary or not g.get("target") is Dictionary: return false
	for role: String in ["base","target"]:
		var o: Dictionary = g[role]
		if not integer(o.get("rid")) or o.rid<=0 or not integer(o.get("shapeRid")) or o.shapeRid<=0 or not count(o.get("shape"),0) or not count(o.get("layer"),1) or not count(o.get("mask"),1) or not o.get("path") is String or o.path.is_empty(): return false
		if not transform(o.get("transform"),IDENTITY) or not near(o.transform.origin,[0,0,0]) or not transform(o.get("offset"),IDENTITY) or not near(o.get("velocity"),[0,0,0]) or not near(o.get("angularVelocity"),[0,0,0]): return false
	if g.base.rid==g.target.rid or g.base.shapeRid==g.target.shapeRid: return false
	if g.base.get("type")!="BoxShape3D" or not near(g.base.get("size"),[20,1,20]) or not near(g.base.offset.origin,[0,-.5,0]): return false
	var t: Dictionary = g.target;var expected: Array = Observe.encode(Fixture.vertices(s))
	if t.get("type")!="ConcavePolygonShape3D" or not t.get("backface") is bool or not t.backface or not near(t.offset.origin,[0,0,0]) or not t.get("faces") is Array or t.faces.size()!=6: return false
	var bounds := AABB(v(expected[0]),Vector3.ZERO)
	for i in 6:
		if not near(t.faces[i],expected[i]): return false
		bounds = bounds.expand(v(expected[i]))
	return t.get("aabb") is Dictionary and near(t.aabb.get("position"),Observe.encode(bounds.position)) and near(t.aabb.get("size"),Observe.encode(bounds.size)) and close(t.get("plane"),s.rise)
static func state(a: Dictionary,s: Dictionary) -> bool:
	if not transform(a.get("transform"),basis(s)): return false
	for x: float in a.transform.origin:
		if absf(x)>=8: return false
	for k: String in ["velocity","floorNormal","platformVelocity","platformAngularVelocity","lastMotion","parentDelta","realVelocity"]:
		if not vec(a.get(k)): return false
	for k: String in ["grounded","onWall","onCeiling"]:
		if not a.get(k) is bool: return false
	var d := Fixture.direction(s)
	return near(a.platformVelocity,[0,0,0]) and near(a.platformAngularVelocity,[0,0,0]) and count(a.get("resetCount"),1) and integer(a.get("slideCount")) and a.slideCount>=0 and a.slideCount<=6 and absf(v(a.transform.origin).dot(Vector3(d.z,0,-d.x)))<=.0001
static func contact(c: Dictionary,g: Dictionary) -> String:
	if not vec(c.get("point")) or not vec(c.get("normal")) or not close(v(c.normal).length(),1,.0001) or not near(c.get("velocity"),[0,0,0]) or not number(c.get("depth")) or c.depth<0 or not count(c.get("localShape"),0) or not count(c.get("shape"),0) or not integer(c.get("rid")): return ""
	for role: String in ["base","target"]:
		if c.get("rid")==g[role].rid and c.get("path")==g[role].path:
			if role=="target":
				var f: Array = g.target.faces;var edge := v(c.point)-v(f[0]);var forward := (v(f[1])-v(f[0]))/3.0;var right := (v(f[5])-v(f[0]))/4.0
				if absf(c.point[1]-g.target.plane)>EPS or edge.dot(forward)<-EPS or edge.dot(forward)>3+EPS or edge.dot(right)<-EPS or edge.dot(right)>4+EPS: return ""
			elif absf(c.point[0])>10+EPS or absf(c.point[2])>10+EPS or c.point[1]<-1-EPS or c.point[1]>EPS: return ""
			return role
	return ""
static func support(q: Dictionary,a: Dictionary,p: Dictionary,g: Dictionary,s: Dictionary) -> Dictionary:
	if q.get("before")!=a or q.get("after")!=a or q.get("bodyRid")!=p.bodyRid or q.get("from")!=a.transform: return {}
	if not near(q.get("motion"),[0,-(p.margin+.0001),0]) or not close(q.get("margin"),p.margin) or not count(q.get("maxCollisions"),32) or q.get("excludeBodies")!=[] or q.get("excludeObjects")!=[]: return {}
	for k: String in ["recoveryAsCollision","collideSeparationRay"]:
		if not q.get(k) is bool or not q[k]: return {}
	if not q.get("hit") is bool or not vec(q.get("travel")) or not vec(q.get("remainder")) or not number(q.get("safeFraction")) or not number(q.get("unsafeFraction")) or q.safeFraction<0 or q.safeFraction>q.unsafeFraction or q.unsafeFraction>1: return {}
	if not q.get("contacts") is Array or q.contacts.size()>32 or not count(q.get("count"),q.contacts.size()): return {}
	var usable: bool = q.hit and q.contacts.size()>0 and q.contacts.size()<32
	var target := usable;var base := usable;var floors := 0
	for c: Dictionary in q.contacts:
		var role := contact(c,g)
		if role.is_empty(): return {}
		if role!="target" or c.normal[1]<cos(deg_to_rad(46.0)) or absf(c.point[1]-s.rise)>EPS: target = false
		if c.normal[1]>=cos(deg_to_rad(46.0)+.01):
			floors += 1
			if role!="base" or not near(c.normal,[0,1,0]) or absf(c.point[1])>EPS: base = false
		elif role!="base" and role!="target": base = false
	return {"base":base and floors>0,"target":target}
static func row(r: Dictionary,p: Dictionary,g: Dictionary,s: Dictionary,moving: bool) -> Dictionary:
	if not r.get("returned") is bool or not r.returned or not count(r.get("parentCalls"),1) or not r.get("input") is Array or r.input.size()!=2 or not count(r.input[0],0) or not count(r.input[1],-1 if moving else 0): return {}
	for k: String in ["jump","sprint"]:
		if not r.get(k) is bool or r[k]: return {}
	if not integer(r.get("frame")) or r.frame<0 or not integer(r.get("usec")) or r.usec<0 or not count(r.get("physicsHz"),60) or not count(r.get("timeScale"),1) or not close(r.get("delta"),1.0/60.0,.00000001) or not r.get("inPhysicsFrame") is bool or not r.inPhysicsFrame: return {}
	if not near(r.get("requestedMotion"),Observe.encode(Fixture.direction(s)*.1 if moving else Vector3.ZERO)): return {}
	if r.get("parameters")!=p or not parameters(p,s) or not r.get("before") is Dictionary or not r.get("after") is Dictionary or not state(r.before,s) or not state(r.after,s): return {}
	var a: Dictionary = r.after;var delta := v(a.transform.origin)-v(r.before.transform.origin)
	if not near(r.get("wholeDelta"),Observe.encode(delta)) or not near(a.parentDelta,Observe.encode(delta)) or not near(a.realVelocity,Observe.encode(delta/float(r.delta)),.00001): return {}
	if not r.get("slides") is Array or r.slides.size()>192: return {}
	var witness := false;var d := Fixture.direction(s);var indices := {}
	for c: Dictionary in r.slides:
		var role := contact(c,g)
		if role.is_empty() or not integer(c.get("slideIndex")) or c.slideIndex<0 or c.slideIndex>=a.slideCount or not integer(c.get("contactIndex")) or c.contactIndex<0 or c.contactIndex>=32 or not vec(c.get("travel")) or not vec(c.get("remainder")): return {}
		var key := int(c.slideIndex)
		if not indices.has(key): indices[key] = 0
		if c.contactIndex!=indices[key]: return {}
		indices[key] += 1
		var n := v(c.normal);var flat := Vector3(n.x,0,n.z)
		if role=="target" and c.point[1]>0 and c.point[1]<.25 and n.y<cos(deg_to_rad(46.0)+.01) and flat.length()>0 and -flat.normalized().dot(d)>=.98: witness = true
	if indices.size()!=int(a.slideCount): return {}
	if not r.get("support") is Dictionary: return {}
	var q := support(r.support,a,p,g,s)
	if q.is_empty(): return {}
	var pos := v(a.transform.origin);var along := pos.dot(d);var lateral := absf(pos.dot(Vector3(d.z,0,-d.x)))
	var footprint: bool = along>=p.radius+p.margin and along<=3-p.radius-p.margin and lateral<=2-p.radius-p.margin
	return {"landing":moving and a.grounded and footprint and absf(pos.y-s.rise)<=p.margin+.0001 and q.target,"blocked":moving and a.grounded and along<1 and delta.length()<.0001 and q.base and witness,"along":along,"base":q.base}
static func profile(p: Dictionary,index: int) -> String:
	if not count(p.get("caseIndex"),index) or p.get("spec")!=Fixture.cases()[index] or not p.get("experimental") is bool or p.experimental: return ""
	if not parameters(p.parameters,p.spec) or not geometry(p.geometry,p.spec) or p.settle.size()!=20 or p.frames.size()<1 or p.frames.size()>240: return ""
	for role: String in ["base","target"]:
		if p.parameters.bodyRid==p.geometry[role].rid or p.parameters.shapeRid==p.geometry[role].shapeRid: return ""
	var prev := {};var landing := 0;var blocked := 0;var outcome := "";var rows: Array = p.settle+p.frames
	for i in rows.size():
		var r: Dictionary = rows[i];var checked := row(r,p.parameters,p.geometry,p.spec,i>=20)
		if checked.is_empty(): return ""
		if not prev.is_empty():
			if r.frame!=prev.frame+1 or r.usec<=prev.usec or r.before!=prev.after: return ""
		else:
			var start := -Fixture.direction(p.spec);start.y = .05
			if not near(r.before.transform.origin,Observe.encode(start)) or not near(r.before.velocity,[0,0,0]): return ""
		if i==19 and (not r.after.grounded or not checked.base): return ""
		if i>=20:
			if not outcome.is_empty(): return ""
			landing = landing+1 if checked.landing else 0;blocked = blocked+1 if checked.blocked else 0
			if landing>=3 and checked.along>=1: outcome = "arrived"
			elif blocked>=120: outcome = "blocked_with_target_witness"
		prev = r
	if outcome.is_empty():
		if p.frames.size()!=240: return ""
		outcome = "unresolved_at_cap"
	return outcome if p.get("outcome")==outcome and p.get("status")=="completed" and count(p.get("landingStreak"),landing) and count(p.get("blockedStreak"),blocked) else ""
static func successful(r: Dictionary,source: String,grant: String,engine: String) -> bool:
	if r.get("phase")!=PHASE or r.get("mode")!=MODE or r.get("group")!=GROUP or r.get("sourceSha256")!=source or r.get("grantSha256")!=grant or r.get("engineSha256")!=engine or engine!=ENGINE: return false
	if not hash_valid(source) or not hash_valid(grant) or not hash_valid(r.get("dependenciesSha256")) or r.get("lineage")!={"AKManifestSha256":AK,"AKPositiveSha256":AK_RESULT,"role":"failed-positive-lineage-not-admission"}: return false
	if not number(r.get("startedUnix")) or not number(r.get("finishedUnix")) or r.startedUnix<=0 or r.finishedUnix<=r.startedUnix: return false
	if not r.get("engine") is Dictionary or not count(r.engine.get("major"),4) or not count(r.engine.get("minor"),5) or not count(r.engine.get("patch"),2): return false
	for k: String in ["failed","candidateAdmission","nativeStepAdmission","productionPromotion","selectionQualified","backendImplementationVerified","parentInternalCallsTraced"]:
		if not r.get(k) is bool or r[k]: return false
	if not r.get("completedCharacterization") is bool or not r.completedCharacterization or r.has("faultCode") or r.get("outcome")!="collection_complete" or not r.has("selectedHeight") or not r.has("physicalCallCounts") or r.selectedHeight!=null or r.physicalCallCounts!=null or not count(r.get("candidateMapWalks"),0): return false
	if not count(r.get("attemptedProfiles"),8) or not count(r.get("completedProfiles"),8) or not count(r.get("unrunProfiles"),0) or not r.get("records") is Array or r.records.size()!=8: return false
	var outcomes: Array = [];var inputs := 0
	for i in 8:
		var outcome := profile(r.records[i],i)
		if outcome.is_empty(): return false
		outcomes.append(outcome);inputs += r.records[i].frames.size()
	var agree: bool = outcomes[0]=="blocked_with_target_witness" and outcomes[1]=="blocked_with_target_witness" and outcomes[2]=="arrived"
	return r.get("referenceAgreement") is bool and r.referenceAgreement==agree and count(r.get("inputResponses"),inputs) and count(r.get("settleResponses"),160)
