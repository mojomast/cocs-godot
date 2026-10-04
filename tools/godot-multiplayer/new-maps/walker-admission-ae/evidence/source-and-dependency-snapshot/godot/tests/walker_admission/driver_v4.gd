extends "res://tests/walker_step_up/driver_v2.gd"
## New source-only admission phase; inherits serialization/ordinary-step observer,
## not the v2 execution sequence. No map loader is invoked by this driver.
const Fixtures = preload("fixtures_v4.gd")
const CandidateTelemetry = preload("candidate_telemetry_v4.gd")
const Slides = preload("slide_telemetry.gd")
const PHASE := "admission-controls-only-v4"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="): directory = arg.trim_prefix("--fixture=")
		elif arg.begins_with("--group="): group_id = arg.trim_prefix("--group=")
		elif arg.begins_with("--grant-id="): grant_id = arg.trim_prefix("--grant-id=")
		elif arg.begins_with("--grant-sha256="): grant_sha = arg.trim_prefix("--grant-sha256=")
		else: quit(2); return
	if not directory.begins_with("res://tests/walker_admission/") or not directory.ends_with("/") or ".." in directory or not group_id in Fixtures.GROUPS: quit(2); return
	output = directory+group_id+"-result.json"
	if FileAccess.file_exists(output): quit(2); return
	create_timer(170).timeout.connect(func() -> void: finish("timeout",true,2))
	call_deferred("run")

func step_record(body: Baseline, input: Vector2, jump: bool = false) -> Dictionary:
	var sample := super.step_record(body,input,jump)
	sample.collisions = Slides.capture(body)
	var capsule: CapsuleShape3D = body.get_child(0).shape
	sample.bodyRid = body.get_rid()
	sample.capsuleRid = capsule.get_rid()
	sample.actualShapeData = PhysicsServer3D.shape_get_data(capsule.get_rid())
	sample.bodyTransform = body.global_transform
	return sample

func walker(experimental: bool, radius: float) -> Baseline:
	var body: Baseline = CandidateTelemetry.new() if experimental else Baseline.new()
	body.set_physics_process(false)
	var shape: CapsuleShape3D = body.get_child(0).shape
	assert(radius==.35 or radius==.42)
	shape.radius = radius
	return body

func run() -> void:
	config = read_json(directory+"source.json")
	var grant := read_json(directory+"grant.json")
	receipt.merge({"phase":PHASE,"group":group_id,"sourceSha256":FileAccess.get_sha256(directory+"source.json"),
		"grantId":grant_id,"grantReceiptSha256":grant_sha,"nativeStepAdmission":false,"productionPromotion":false,
		"baselinePassed":0,"candidatePassed":0,"candidateMapWalks":0,"version":Engine.get_version_info()})
	if config.get("phase")!=PHASE or grant.get("phase")!=PHASE or not grant.get("authorized",false) or grant_id.is_empty() or grant.get("grantId")!=grant_id or FileAccess.get_sha256(directory+"grant.json")!=grant_sha or float(grant.get("expiresUnix",0))<=Time.get_unix_time_from_system(): finish("grant_or_source_rejected",true,2); return
	if grant.get("sourceSha256")!=receipt.sourceSha256: finish("grant_source_binding_required",true,2); return
	if grant.has("groups") or grant.has("continueAfterKnownBaselineFailure"): finish("ambiguous_or_continuation_grant",true,2); return
	var allowed: Variant = grant.get("allowedGroups")
	if not allowed is Array or allowed.is_empty() or not group_id in allowed: finish("allowed_groups_required",true,2); return
	var seen := {}
	for item: Variant in allowed:
		if not item is String or not item in Fixtures.GROUPS or seen.has(item): finish("map_or_unknown_group_forbidden",true,2); return
		seen[item] = true
	var version := Engine.get_version_info()
	if version.major!=4 or version.minor!=5 or version.patch!=2 or Engine.physics_ticks_per_second!=60 or Engine.time_scale!=1.0: finish("version_or_clock",true,2); return
	for path: String in config.files:
		if FileAccess.get_sha256(path)!=config.files[path]: finish("source_identity:"+path,true,2); return
	if config.get("abEvidenceVerified")!=true: finish("AB_lineage_required",true,2); return
	var ab_controls := read_json(directory+"AB-controls-result.json")
	var ab_reference := read_json(directory+"AB-reference-accepted-civic-r035-result.json")
	if ab_controls.get("failed",true) or ab_controls.get("passed",0)!=34 or not ab_reference.get("failed",false) or not ab_reference.get("referenceExpected",false) or ab_reference.get("passed",0)!=5 or ab_reference.get("failedTrials",0)!=5: finish("AB_outcomes_not_qualified",true,2); return
	if ab_controls.get("sourceSha256")!=FileAccess.get_sha256(directory+"AB-source.json") or ab_controls.get("sourceSha256")!=ab_reference.get("sourceSha256") or ab_controls.get("grantReceiptSha256")!=ab_reference.get("grantReceiptSha256"): finish("AB_receipt_binding_mismatch",true,2); return
	if group_id==Fixtures.GROUPS[1]:
		var previous := read_json(directory+Fixtures.GROUPS[0]+"-result.json")
		if previous.get("failed",true) or previous.get("passed",0)!=4 or previous.get("sourceSha256")!=receipt.sourceSha256 or previous.get("grantReceiptSha256")!=grant_sha: finish("inclined_predecessor_required",true,2); return
	var cases := Fixtures.cases(group_id)
	receipt.unrun = cases.size()
	for spec: Dictionary in cases:
		var row := {"spec":spec,"profiles":[],"passed":false}
		receipt.records.append(row);receipt.attempted += 1;receipt.unrun -= 1
		for experimental: bool in [false,true]:
			var fixture := Fixtures.make(root,spec)
			var body := walker(experimental,spec.radius)
			fixture.world.add_child(body);body.set_physics_process(false)
			body.set_spawn(fixture.start,spec.yaw)
			var profile := {"experimental":experimental,"parameters":parameters(body),"geometry":fixture.faces,
				"geometryNormal":fixture.normal,"topRid":fixture.topRid,"topShapeIndex":0,"settle":[],"frames":[],
				"appliedVerifiedLifts":0,"inclinedPolicyWitnesses":0,"stallCount":0,"reached":false}
			row.profiles.append(profile)
			for settle in range(20):
				await physics_frame
				if not require_clock(body): finish("settle_clock",true,2); return
				var sample := step_record(body,Vector2.ZERO)
				profile.settle.append(sample)
				if sample.resetCount!=1 or not sample.candidateFault.is_empty() or sample.proposal.get("accepted",false): fail_case("settle_fault"); return
			if not body.is_on_floor(): fail_case("not_settled"); return
			var last_frame: int = profile.settle[-1].clock.frame
			for frame in range(int(spec.maxResponses)):
				await physics_frame
				if not require_clock(body) or Engine.get_physics_frames()!=last_frame+1: finish("nonconsecutive_clock",true,2); return
				last_frame = Engine.get_physics_frames()
				var observed: Dictionary = {}
				if not experimental:
					var before := body.global_transform
					var velocity := body.velocity
					observed = Proposal.propose(body,1.0/60.0,Vector2(0,-1),false,false)
					if before!=body.global_transform or velocity!=body.velocity: fail_case("observer_mutated_baseline"); return
				var sample := step_record(body,Vector2(0,-1))
				sample.baselineObserver = observed
				profile.frames.append(sample)
				if sample.resetCount!=1 or not sample.candidateFault.is_empty(): fail_case("native_candidate_or_reset_fault"); return
				var plan: Dictionary = sample.proposal if experimental else observed
				if spec.incline>0.0:
					if plan.get("accepted",false): fail_case("inclined_landing_admitted"); return
					if plan.get("reason")=="no_continuous_flat_landing":
						if not inclined_witness(plan,fixture): fail_case("wrong_inclined_obstacle"); return
						profile.inclinedPolicyWitnesses += 1
					elif plan.get("reason")!="no_bounded_riser": fail_case("unexpected_inclined_rejection"); return
				elif experimental and plan.get("accepted",false):
					if not plan.get("responseGuard",{}).get("passed",false) or plan.supportRid!=fixture.topRid or int(plan.supportShape)!=0: fail_case("lift_not_guarded_on_target"); return
					profile.appliedVerifiedLifts += 1
				var along: float = body.global_position.dot(fixture.direction)
				var lateral: float = absf(body.global_position.dot(fixture.direction.cross(Vector3.UP)))
				if lateral>.0001: fail_case("left_centerline"); return
				profile.stallCount = int(profile.stallCount)+1 if sample.wholeFrameDelta.length()<.0001 else 0
				if spec.incline==0.0 and along>=float(spec.goal) and body.is_on_floor():
					if absf(body.global_position.y-.15)>body.safe_margin+.0001: fail_case("wrong_landing_height"); return
					var support := Proposal.sweep(body,body.global_transform,-Vector3.UP*(body.safe_margin+.0001),true)
					profile.finalSupport = Proposal.log_sweep("admission-final-support",support)
					var result: PhysicsTestMotionResult3D = support.result
					if not support.valid or not support.hit or result.get_collision_count()==0 or result.get_collision_count()>=32: fail_case("missing_final_support"); return
					for index in result.get_collision_count():
						if result.get_collider_rid(index)!=fixture.topRid or result.get_collider_shape(index)!=0 or result.get_collision_local_shape(index)!=0 or not result.get_collider_velocity(index).is_zero_approx() or result.get_collision_normal(index).dot(Vector3.UP)<cos(body.floor_max_angle): fail_case("wrong_final_support"); return
					profile.reached = true;break
				if profile.stallCount>=120: break
			if spec.incline>0.0:
				if profile.inclinedPolicyWitnesses<1 or profile.stallCount<120: fail_case("incline_not_witnessed_and_blocked"); return
			elif experimental:
				if not profile.reached or profile.appliedVerifiedLifts<1: fail_case("no_positive_guarded_admission"); return
			elif profile.reached or profile.stallCount<120: fail_case("baseline_not_blocked"); return
			if experimental: receipt.candidatePassed += 1
			else: receipt.baselinePassed += 1
			fixture.world.queue_free();await process_frame
		if spec.incline>0.0:
			var a: Array = row.profiles[0].frames
			var b: Array = row.profiles[1].frames
			if a.size()!=b.size(): fail_case("incline_response_count_differs"); return
			for index in a.size():
				var epsilon := Response.numeric_budget([a[index].after,b[index].after])
				if epsilon<0.0 or a[index].after.distance_to(b[index].after)>epsilon or a[index].velocity.distance_to(b[index].velocity)>epsilon or a[index].groundedAfter!=b[index].groundedAfter: fail_case("incline_ordinary_response_differs"); return
		row.passed = true;receipt.passed += 1
	receipt.nativeStepAdmission = group_id==Fixtures.GROUPS[1]
	finish("admission_control_group_pass",false,0)

func fail_case(reason: String) -> void:
	receipt.failedTrials += 1
	finish(reason,true,1)

func inclined_witness(plan: Dictionary, fixture: Dictionary) -> bool:
	if fixture.normal.dot(Vector3.UP)>=cos(deg_to_rad(46.0)): return false
	for stage: Dictionary in plan.stages:
		if stage.name!="intent": continue
		for contact: Dictionary in stage.contacts:
			if contact.collider==str(fixture.top.get_path()) and int(contact.colliderShape)==0 and contact.point.y>0.0 and contact.point.y<.25 and -contact.normal.slide(Vector3.UP).normalized().dot(fixture.direction)>=.98:
				return true
	return false
