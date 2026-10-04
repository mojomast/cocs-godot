extends RefCounted
## Serialized operands only, not a substitute for the unchanged physics guard.
const IDS := ["ceiling-up","overhang-forward","height-025","height-030","height-031","height-guard","narrow-width","narrow-depth","hole","pit","lateral","no-input","airborne","jumping","tilted-body","transformed-parent","moving-floor"]
const REASONS := [["up_blocked_or_lateral_recovery"],["raised_path_blocked"],["not_low_riser_band","strict_surface_rise_limit"],["not_low_riser_band","strict_surface_rise_limit"],["not_low_riser_band","strict_surface_rise_limit"],["not_low_riser_band","strict_surface_rise_limit"],["unsupported_or_narrow_landing"],["unsupported_or_narrow_landing"],["no_continuous_flat_landing"],["no_bounded_riser","no_flat_static_base_support"],["lateral_wall_or_corner","multiple_obstacles"],["no_input"],["not_stationary_grounded_intent"],["not_stationary_grounded_intent"],["non_yaw_rotation"],["transformed_parent"],["moving_platform","no_flat_static_base_support"]]
static func getv(v: Variant, key: String, fallback: Variant = null) -> Variant:
	return v.get(key,fallback) if v is Dictionary else fallback
static func num(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v))
static func integer(v: Variant) -> bool:
	return num(v) and v==floor(v)
static func near(a: Variant,b: Variant,e: float = .000001) -> bool:
	return num(a) and num(b) and absf(a-b)<=e
static func flag(v: Variant, expected: bool) -> bool:
	return v is bool and v==expected
static func vec(v: Variant,n: int = 3) -> bool:
	if not v is Array or v.size()!=n: return false
	for x: Variant in v:
		if not num(x): return false
	return true
static func distance(a: Variant,b: Array) -> float:
	if not vec(a,b.size()): return INF
	var total := 0.0
	for i in b.size(): total += pow(a[i]-b[i],2)
	return sqrt(total)
static func origin(s: Variant) -> Variant:
	return getv(getv(s,"transform"),"origin")
static func state(s: Variant) -> bool:
	return vec(origin(s)) and vec(getv(s,"velocity")) and getv(s,"grounded") is bool and near(getv(s,"resetCount"),1,0)
static func canonical(group: String) -> Array:
	var rows: Array = []
	if group=="negative-controls":
		for id: String in IDS:
			for radius: float in [.35,.42]: rows.append({"id":id,"radius":radius})
	else:
		for radius: float in [.35,.42]:
			for degrees: float in [-45.0,45.0]:
				rows.append({"id":str(radius)+":"+str(degrees),"radius":radius,"yaw":deg_to_rad(degrees),"incline":47.0 if group=="inclined-landing-rejections" else 0.0,"start":-1.0,"goal":1.0,"maxResponses":240})
	return rows
static func spec_equal(a: Variant,b: Dictionary) -> bool:
	if not a is Dictionary or a.size()!=b.size(): return false
	for key: String in b:
		if num(b[key]):
			if not near(a.get(key),b[key],1e-12): return false
		elif a.get(key)!=b[key]: return false
	return true
static func footprint(s: Variant,spec: Dictionary) -> bool:
	if not state(s): return false
	var p: Array = origin(s)
	var along: float = sin(spec.yaw)*p[0]+cos(spec.yaw)*p[2]
	return along>=spec.radius+.02 and along<=3-spec.radius-.02 and absf(cos(spec.yaw)*p[0]-sin(spec.yaw)*p[2])<=2-spec.radius-.02 and flag(s.grounded,true) and absf(p[1]-.15)<=.0201
static func support(q: Variant,rid: Variant) -> bool:
	if not flag(getv(q,"hit"),true) or not flag(getv(q,"validResult"),true): return false
	var contacts: Variant = getv(q,"contacts")
	if not contacts is Array or contacts.is_empty() or contacts.size()>=32: return false
	for c: Variant in contacts:
		if not near(getv(c,"colliderRid"),rid,0) or not near(getv(c,"colliderShape"),0,0) or not near(getv(c,"localShape"),0,0) or not vec(getv(c,"point")) or absf(c.point[1]-.15)>1e-6 or not vec(getv(c,"normal")) or c.normal[1]<cos(deg_to_rad(46.0)) or distance(getv(c,"velocity"),[0,0,0])>1e-6: return false
	return true
static func witness(plan: Dictionary) -> bool:
	for s: Variant in plan.stages:
		if getv(s,"name")=="intent" and flag(getv(s,"hit"),true) and flag(getv(s,"validResult"),true) and getv(s,"contacts") is Array and not s.contacts.is_empty(): return true
	return false
static func profile(p: Dictionary,spec: Dictionary,group: String,experimental: bool) -> bool:
	var negative := group=="negative-controls"
	var inclined := group=="inclined-landing-rejections"
	var expected := "expected_original_rejection_and_ordinary_response" if negative else "expected_inclined_rejection_and_block" if inclined else "full_tread_guarded_arrival" if experimental else "expected_baseline_blocked"
	if p.get("outcome")!=expected or p.get("status")!="completed" or not flag(p.get("experimental"),experimental): return false
	if not flag(p.get("reached"),not negative and not inclined and experimental): return false
	var params: Variant = p.get("parameters")
	var values := {"margin":.02,"snap":.3,"floorAngle":deg_to_rad(46.0),"walk":6,"sprint":10,"gravity":20,"jump":6.5}
	for key: String in values:
		if not near(getv(params,key),values[key]): return false
	if not near(getv(getv(params,"shape"),"radius"),spec.radius) or not near(getv(getv(params,"shape"),"height"),1.8) or distance(getv(getv(params,"offset"),"origin"),[0,.9,0])>1e-6: return false
	if not p.get("geometry") is Array or p.geometry.is_empty(): return false
	if not negative and not target(p,spec): return false
	var settles := 1 if negative and spec.id=="airborne" else 20
	if not p.get("settle") is Array or p.settle.size()!=settles or not p.get("frames") is Array: return false
	var yaw: float = 0.0 if negative else spec.yaw
	var basis := [[cos(yaw),0,-sin(yaw)],[0,1,0],[sin(yaw),0,cos(yaw)]]
	var actual_basis: Variant = getv(getv(getv(p.settle[0],"before"),"transform"),"basis")
	if not actual_basis is Array or actual_basis.size()!=3: return false
	for i in range(3):
		if distance(actual_basis[i],basis[i])>1e-6: return false
	var frames: Array = p.frames
	if negative:
		if frames.size()!=(2 if spec.id=="jumping" else 1): return false
	elif frames.is_empty() or frames.size()>240: return false
	var applied := 0;var verified := 0;var attempts := 0;var parents := 0
	var stall := 0;var holds := 0;var inclined_hits := 0;var previous := -1
	var rows: Array = p.settle+frames
	for i in rows.size():
		var row: Variant = rows[i]
		var active := i>=settles
		var jump: bool = negative and spec.id=="jumping" and active and i==settles
		var input: Array = [0,0] if not active or jump or negative and spec.id=="no-input" else [pow(2,-.5),-pow(2,-.5)] if negative and spec.id=="lateral" else [0,-1]
		if not flag(getv(row,"returned"),true) or getv(row,"candidateFault")!="" or not flag(getv(row,"sprint"),false) or not flag(getv(row,"jump"),jump) or distance(getv(row,"input"),input)>1e-6: return false
		if not integer(getv(row,"frame")) or row.frame<0 or previous>=0 and row.frame!=previous+1: return false
		previous = int(row.frame)
		if not near(getv(row,"actualDelta"),1.0/60.0,1e-8) or not near(getv(row,"physicsHz"),60,0) or not near(getv(row,"timeScale"),1,0) or not integer(getv(row,"usec")): return false
		if not state(getv(row,"before")) or not state(getv(row,"after")) or not vec(getv(row,"wholeFrameDelta")) or not getv(row,"slides") is Array: return false
		var a: Array = origin(row.before);var b: Array = origin(row.after)
		if distance(row.wholeFrameDelta,[b[0]-a[0],b[1]-a[1],b[2]-a[2]])>1e-6: return false
		var plan: Variant = getv(row,"proposal")
		if not getv(plan,"accepted") is bool or not getv(plan,"stages") is Array: return false
		var ordinary := true
		if experimental:
			var life: Variant = getv(row,"lifecycle");var up: Variant = getv(row,"appliedUpCount")
			var accepted: Variant = getv(getv(life,"originalProof"),"accepted")
			if not flag(getv(life,"returned"),true) or not near(getv(life,"frame"),row.frame,0) or not integer(up) or not up in [0,1] or not near(getv(life,"parentCalls"),1,0) or not accepted is bool: return false
			if not getv(life,"ordinary") is bool or life.ordinary==accepted: return false
			ordinary = life.ordinary
			if not accepted:
				if up!=0 or not flag(plan.accepted,false) or not flag(getv(row,"responseGuardPassed"),false): return false
			else:
				if negative or inclined or up!=1 or not flag(plan.accepted,true) or not flag(getv(row,"responseGuardPassed"),true) or not flag(getv(getv(plan,"responseGuard"),"passed"),true): return false
				var t: Variant = getv(row,"telemetry")
				if not flag(getv(t,"finalSupportQueryReached"),true) or getv(t,"afterParent")!=getv(t,"afterGuard") or not state(getv(t,"upAfter")) or not vec(getv(t,"actualUpTravel")) or t.actualUpTravel[1]<=0: return false
				if not near(getv(plan,"supportRid"),p.get("targetRid"),0) or not near(getv(plan,"supportShape"),0,0) or not near(getv(plan,"landingY"),.15): return false
				if distance(getv(plan,"expectedFinal"),origin(row.after))>1e-6: return false
				if not guarded(row,p): return false
				attempts += 1;verified += 1
			applied += int(up);parents += 1
			var totals := {"totalAttempts":attempts,"totalApplied":applied,"totalVerified":verified,"totalParentCalls":parents}
			for key: String in totals:
				if not near(getv(life,key),totals[key],0): return false
		elif getv(row,"afterQueries")!=row.before: return false
		if active:
			stall = stall+1 if distance(row.wholeFrameDelta,[0,0,0])<.0001 else 0
			if inclined:
				if plan.accepted or not plan.get("reason") in ["no_bounded_riser","no_continuous_flat_landing"]: return false
				if plan.reason=="no_continuous_flat_landing":
					if not inclined_witness(plan,p.target): return false
					inclined_hits += 1
			if not negative and not inclined: holds = holds+1 if ordinary and footprint(row.after,spec) else 0
	if not near(p.get("appliedUpCount"),applied,0) or not near(p.get("verifiedLifts"),verified,0) or applied>ceil(2*spec.radius/.1)+2: return false
	if negative:
		var plan: Dictionary = frames[-1].proposal;var reasons: Array = REASONS[IDS.find(spec.id)]
		if plan.accepted or not plan.get("reason") in reasons or p.get("expectedReasons")!=reasons or applied!=0: return false
		if IDS.find(spec.id)<9 and not witness(plan): return false
		if not negative_stages(plan,spec.id): return false
	elif inclined:
		if inclined_hits<1 or not near(p.get("inclinedWitnesses"),inclined_hits,0) or stall!=120 or applied!=0: return false
	elif experimental:
		var final: Variant = p.get("finalSupport");var last: Dictionary = frames[-1].after;var pos: Array = origin(last)
		var along: float = sin(spec.yaw)*pos[0]+cos(spec.yaw)*pos[2]
		if verified<1 or verified!=applied or not flag(p.get("reached"),true) or holds<3 or along<spec.goal or not near(p.get("ordinaryLandingStreak"),holds,0): return false
		if not integer(p.get("targetRid")) or p.targetRid<=0 or not near(p.get("targetShape"),0,0) or not flag(getv(final,"passed"),true) or not flag(getv(final,"footprintInside"),true) or getv(final,"reason")!="full_footprint_and_fresh_target_support": return false
		if getv(final,"bodyBefore")!=last or getv(final,"bodyAfter")!=last or not near(getv(final,"epsilon"),1e-6,0) or not support(getv(final,"query"),p.targetRid): return false
	else:
		var pos: Array = origin(frames[-1].after)
		var along: float = sin(spec.yaw)*pos[0]+cos(spec.yaw)*pos[2]
		if stall!=120 or not flag(p.get("reached"),false) or applied!=0 or along>=spec.goal: return false
	if not negative and not near(p.get("stallCount"),stall,0): return false
	return true
static func target(p: Dictionary,spec: Dictionary) -> bool:
	var t: Variant = p.get("target")
	if not integer(p.get("targetRid")) or p.targetRid<=0 or not near(p.get("targetShape"),0,0) or not near(getv(t,"rid"),p.targetRid,0) or not near(getv(t,"shape"),0,0) or not getv(t,"path") is String or t.path.is_empty(): return false
	if distance(getv(t,"direction"),[sin(spec.yaw),0,cos(spec.yaw)])>1e-6 or not vec(getv(t,"normal")) or not near(t.normal[1],cos(deg_to_rad(spec.incline))): return false
	var back: float = .15+3*tan(deg_to_rad(spec.incline))
	var points := [[-2,.15,0],[-2,back,3],[2,back,3],[2,.15,0]]
	var indices := [0,1,2,0,2,3]
	if not getv(t,"faces") is Array or t.faces.size()!=6: return false
	for i in range(6):
		var v: Array = points[indices[i]]
		if distance(t.faces[i],[cos(spec.yaw)*v[0]+sin(spec.yaw)*v[2],v[1],-sin(spec.yaw)*v[0]+cos(spec.yaw)*v[2]])>1e-6: return false
	for g: Variant in p.geometry:
		if near(getv(g,"rid"),p.targetRid,0) and getv(g,"name")==("InclinedLanding" if spec.incline>0 else "PositiveTread"): return true
	return false
static func negative_stages(plan: Dictionary,id: String) -> bool:
	var required := ["current-support","intent"]
	if id=="ceiling-up": required.append("up")
	if id=="overhang-forward": required.append_array(["up","forward"])
	if IDS.find(id)>=11 and plan.reason!="no_bounded_riser": return true
	if id=="pit" and plan.reason=="no_flat_static_base_support": return plan.stages==[]
	if plan.stages.size()!=required.size(): return false
	for i in required.size():
		var s: Variant = plan.stages[i]
		if getv(s,"name")!=required[i] or not flag(getv(s,"validResult"),true) or not getv(s,"hit") is bool or not near(getv(s,"maxCollisions"),32,0) or not near(getv(s,"margin"),.02) or not vec(getv(s,"motion")) or not vec(getv(s,"travel")) or not vec(getv(s,"remainder")) or not vec(getv(getv(s,"from"),"origin")): return false
		if not num(getv(s,"safeFraction")) or not num(getv(s,"unsafeFraction")) or s.safeFraction<0 or s.safeFraction>s.unsafeFraction or s.unsafeFraction>1 or not getv(s,"contacts") is Array: return false
	var ground: Dictionary = plan.stages[0];var intent: Dictionary = plan.stages[1]
	var floor_found := false
	for c: Variant in ground.contacts:
		if vec(getv(c,"normal")) and c.normal[1]>=cos(deg_to_rad(46.0)): floor_found = true
	if not flag(ground.hit,true) or not floor_found: return false
	if id in ["ceiling-up","overhang-forward","narrow-width","narrow-depth","hole"]:
		var low_headon := false
		for c: Variant in intent.contacts:
			if not vec(getv(c,"point")) or c.point[1]<=0 or c.point[1]>=.25 or not vec(getv(c,"normal")) or c.normal[2]>=0: continue
			var length := sqrt(c.normal[0]*c.normal[0]+c.normal[2]*c.normal[2])
			if length>0 and -c.normal[2]/length>=.98: low_headon = true
		if not low_headon: return false
	return true
static func inclined_witness(plan: Dictionary,t: Dictionary) -> bool:
	for s: Variant in plan.stages:
		if getv(s,"name")!="intent" or not flag(getv(s,"hit"),true) or not flag(getv(s,"validResult"),true) or not getv(s,"contacts") is Array: continue
		for c: Variant in s.contacts:
			if getv(c,"collider")!=t.path or not near(getv(c,"colliderShape"),0,0) or not vec(getv(c,"point")) or c.point[1]<=0 or c.point[1]>=.25 or not vec(getv(c,"normal")): continue
			var n: Array = c.normal
			var length := sqrt(n[0]*n[0]+n[2]*n[2])
			if length>0 and -(n[0]*t.direction[0]+n[2]*t.direction[2])/length>=.98: return true
	return false
static func campaign(r: Dictionary,group: String) -> bool:
	if r.get("outcome")!=("negative_control_group_pass" if group=="negative-controls" else "synthetic_group_pass"): return false
	var expected := canonical(group)
	if not r.get("records") is Array or r.records.size()!=expected.size(): return false
	for i in expected.size():
		var row: Variant = r.records[i]
		if not spec_equal(getv(row,"spec"),expected[i]) or not getv(row,"profiles") is Array or row.profiles.size()!=2: return false
		for j in range(2):
			if not row.profiles[j] is Dictionary or not profile(row.profiles[j],expected[i],group,j==1): return false
		if group!="positive-step-admission":
			var aa: Array = row.profiles[0].settle+row.profiles[0].frames
			var bb: Array = row.profiles[1].settle+row.profiles[1].frames
			if aa.size()!=bb.size(): return false
			for j in aa.size():
				if distance(origin(aa[j].after),origin(bb[j].after))>1e-6 or distance(aa[j].after.velocity,bb[j].after.velocity)>1e-6 or aa[j].after.grounded!=bb[j].after.grounded: return false
	return true
static func guarded(row: Dictionary,p: Dictionary) -> bool:
	var plan: Dictionary = row.proposal;var g: Variant = plan.get("responseGuard");var t: Dictionary = row.telemetry
	if getv(g,"reason")!="endpoint_and_pinned_clear_branch_and_live_support_agree" or not near(getv(g,"epsilon"),1e-6,0) or not near(getv(g,"slideCount"),0,0) or getv(g,"observedSlides")!=[]: return false
	if distance(getv(g,"actualFinal"),origin(row.after))>1e-6 or distance(getv(g,"expectedFinal"),plan.expectedFinal)>1e-6: return false
	if t.get("beforePlanning")!=row.before or t.get("afterPlanning")!=row.before or t.get("afterParent")!=row.after or t.get("beforeParent")!=t.upAfter: return false
	if not flag(t.get("upCollisionReturned"),false) or t.get("upContacts")!=[] or getv(t.get("upRequest"),"before")!=row.before: return false
	var a: Array = origin(row.before);var b: Array = origin(t.upAfter)
	if distance(t.actualUpTravel,[b[0]-a[0],b[1]-a[1],b[2]-a[2]])>1e-6: return false
	var q: Variant = getv(g,"support");var identities: Variant = t.get("finalSupportIdentities")
	if not getv(q,"contacts") is Array or not identities is Array or q.contacts.size()!=identities.size(): return false
	var contacts: Array = []
	for i in identities.size():
		var c: Variant = q.contacts[i];var identity: Variant = identities[i]
		if not c is Dictionary or not flag(getv(identity,"ridResolved"),true) or not near(getv(identity,"colliderId"),getv(c,"colliderId"),0) or not near(getv(identity,"colliderShapeIndex"),getv(c,"colliderShape"),0) or not near(getv(identity,"localShapeIndex"),getv(c,"localShape"),0): return false
		var copy: Dictionary = c.duplicate();copy.colliderRid = getv(identity,"colliderRid");contacts.append(copy)
	var query: Dictionary = q.duplicate();query.contacts = contacts
	return support(query,p.targetRid)
static func supervisor_ok(s: Dictionary,group: String,source: String,grant: String,engine: String,native_hash: String) -> bool:
	var bindings := {"phase":"parity-admission-synthetic-v1","mode":"synthetic-controls","group":group,"sourceSha256":source,"grantSha256":grant,"engineSha256":engine,"nativeReceiptSha256":native_hash,"scope":"synthetic-admission"}
	for key: String in bindings:
		if s.get(key)!=bindings[key]: return false
	var flags := {"failed":false,"releasedCleanly":true,"partialCountersMayBeUnknown":false,"nativeStepAdmission":false,"productionPromotion":false,"positiveAdmission":group=="positive-step-admission"}
	for key: String in flags:
		if not flag(s.get(key),flags[key]): return false
	if not near(s.get("returnCode"),0,0): return false
	if s.get("nativeOutcome")!=("negative_control_group_pass" if group=="negative-controls" else "synthetic_group_pass"): return false
	for key: String in ["stopReason","supervisorError","invalidNativeReceipt"]:
		if s.get(key)!=null and s.get(key)!="": return false
	if s.get("cleanupErrors",[])!=[]: return false
	var owned: Variant = s.get("owned")
	for key: String in ["pid","pgid","startTicks"]:
		if not integer(getv(owned,key)) or owned[key]<=0: return false
	if owned.pid!=owned.pgid or not num(s.get("lockAcquiredUnix")) or not num(s.get("lockReleasePendingUnix")) or s.lockAcquiredUnix<=0 or s.lockReleasePendingUnix<=s.lockAcquiredUnix: return false
	if not s.get("releaseAudits") is Array or s.releaseAudits.size()!=3: return false
	var previous: float = s.lockAcquiredUnix
	var regex := RegEx.new()
	regex.compile("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{6}\\+00:00$")
	for a: Variant in s.releaseAudits:
		if not flag(getv(a,"measured"),true) or getv(a,"members")!=[] or (getv(a,"error")!=null and getv(a,"error")!=""): return false
		var text: Variant = getv(a,"utc")
		if not text is String or regex.search(text)==null: return false
		var whole: String = text.substr(0,19)
		var seconds := Time.get_unix_time_from_datetime_string(whole)
		# Round-trip rejects normalized invalid dates, not just malformed strings.
		if Time.get_datetime_string_from_unix_time(seconds)!=whole: return false
		var instant: float = seconds+float("0."+text.substr(20,6))
		if instant<=previous or instant>s.lockReleasePendingUnix: return false
		previous = instant
	return true
