extends SceneTree
## Only the original Walker is constructed. All lookahead calls are read-only.
const Walker = preload("res://exploration/walker.gd")
const Legacy = preload("res://tests/walker_step_up/sweep_proposal.gd")
const Pair = preload("res://tests/walker_snap_parity/query_pair.gd")
const Fixtures = preload("res://tests/walker_admission/fixtures_v4.gd")
const Slides = preload("res://tests/walker_admission/slide_telemetry.gd")
const Policy = preload("policy.gd")
var grant_id := ""
var grant_sha := ""
var selected_group := ""
var selected_mode := ""
var result: Dictionary = {"failed":true,"comparisonCollected":false,"queryAgreementQualified":false,"nativeStepAdmission":false,"productionPromotion":false,"candidateMapWalks":0,"records":[],"attemptedCases":0,"completedCases":0,"failedCases":0,"unrunCases":1}
var ready_to_write := false

func _initialize() -> void:
	var seen := {}
	for arg: String in OS.get_cmdline_user_args():
		var key := arg.get_slice("=",0)
		if seen.has(key) or not "=" in arg: quit(2); return
		seen[key] = true
		match key:
			"--grant-id": grant_id = arg.trim_prefix("--grant-id=")
			"--grant-sha256": grant_sha = arg.trim_prefix("--grant-sha256=")
			"--group": selected_group = arg.trim_prefix("--group=")
			"--mode": selected_mode = arg.trim_prefix("--mode=")
			_: quit(2); return
	if seen.size()!=4 or selected_mode!=Policy.MODE or selected_group!=Policy.GROUP: quit(2); return
	if FileAccess.file_exists("res://comparison-result.json"): quit(2); return
	call_deferred("run")

func read_json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func encode(value: Variant) -> Variant:
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Vector2: return [value.x,value.y]
	if value is RID: return value.get_id()
	if value is Transform3D: return {"origin":encode(value.origin),"basis":[encode(value.basis.x),encode(value.basis.y),encode(value.basis.z)]}
	if value is Dictionary:
		var converted := {}
		for key: Variant in value: converted[str(key)] = encode(value[key])
		return converted
	if value is Array or value is PackedVector3Array or value is PackedVector2Array:
		var converted: Array = []
		for item: Variant in value: converted.append(encode(item))
		return converted
	return value

func finish(status: String, failed: bool, code: int) -> void:
	if ready_to_write and not FileAccess.file_exists("res://comparison-result.json"):
		result.status = status
		result.failed = failed
		result.finishedUnix = Time.get_unix_time_from_system()
		result.failedCases = 1 if failed and result.attemptedCases==1 else 0
		var output := FileAccess.open("res://comparison-result.json",FileAccess.WRITE)
		if output!=null: output.store_string(JSON.stringify(encode(result),"\t")+"\n");output.close()
	quit(code)

func snapshot(body: Walker) -> Dictionary:
	return {"bodyTransform":body.global_transform,"velocity":body.velocity,"grounded":body.is_on_floor(),
		"onWall":body.is_on_wall(),"onCeiling":body.is_on_ceiling(),"floorNormal":body.get_floor_normal(),
		"platformVelocity":body.get_platform_velocity(),"slideCount":body.get_slide_collision_count(),
		"lastMotion":body.get_last_motion(),"positionDelta":body.get_position_delta(),"realVelocity":body.get_real_velocity(),
		"resetCount":body.reset_count}

func run() -> void:
	var source := read_json("res://source.json")
	var grant := read_json("res://grant.json")
	var binary_hash := FileAccess.get_sha256(OS.get_executable_path())
	var source_hash := FileAccess.get_sha256("res://source.json")
	if FileAccess.get_sha256("res://grant.json")!=grant_sha or not Policy.grant_valid(grant,selected_group,selected_mode,grant_id,source_hash,binary_hash,Time.get_unix_time_from_system()): quit(2); return
	if source.get("phase")!=Policy.PHASE or source.get("mode")!=Policy.MODE or source.get("allowedGroups")!=[Policy.GROUP] or not source.get("files") is Dictionary: quit(2); return
	for path: String in source.files:
		if not path.begins_with("res://") or ".." in path or FileAccess.get_sha256(path)!=source.files[path]: quit(2); return
	ready_to_write = true
	result.merge({"phase":Policy.PHASE,"mode":selected_mode,"group":selected_group,"grantId":grant_id,"grantSha256":grant_sha,
		"sourceSha256":source_hash,"engineSha256":binary_hash,"engine":Engine.get_version_info(),"AEIdentity":source.AEIdentity,
		"configuredPhysicsEngineSetting":ProjectSettings.get_setting("physics/3d/physics_engine","DEFAULT"),"backendImplementationVerified":false})
	var version := Engine.get_version_info()
	if version.major!=4 or version.minor!=5 or version.patch!=2 or Engine.physics_ticks_per_second!=60 or Engine.time_scale!=1.0: finish("engine_or_clock",true,2); return
	create_timer(170).timeout.connect(func() -> void: finish("internal_timeout",true,2))
	var spec := {"radius":.35,"yaw":-PI/4,"incline":0.0,"start":-1.0,"goal":1.0}
	var fixture := Fixtures.make(root,spec)
	var body := Walker.new() # the only controller factory in this phase
	fixture.world.add_child(body)
	body.set_physics_process(false)
	body.set_spawn(fixture.start,spec.yaw)
	if body.get_script()!=Walker: finish("original_controller_identity",true,2); return
	var capsule: CapsuleShape3D = body.get_child(0).shape
	if not is_equal_approx(capsule.radius,.35) or not is_equal_approx(capsule.height,1.8): finish("shape_profile",true,2); return
	result.geometry = fixture.faces
	result.targetRid = fixture.topRid
	result.targetShapeIndex = 0
	result.controller = "res://exploration/walker.gd"
	result.controllerSha256 = FileAccess.get_sha256(result.controller)
	result.attemptedCases = 1;result.unrunCases = 0
	var previous_frame := -1
	for tick in range(60):
		await physics_frame
		var frame := Engine.get_physics_frames()
		if not Engine.is_in_physics_frame() or Engine.physics_ticks_per_second!=60 or Engine.time_scale!=1.0 or absf(body.get_physics_process_delta_time()-1.0/60.0)>1e-8 or (previous_frame>=0 and frame!=previous_frame+1): finish("actual_clock_failure",true,2); return
		previous_frame = frame
		if tick==20 and not body.is_on_floor(): finish("not_grounded_after_settle",true,1); return
		var input := Vector2.ZERO if tick<20 else Vector2(0,-1)
		var before := snapshot(body)
		var plan := Legacy.propose(body,1.0/60.0,input,false,false)
		var paired: Dictionary = Pair.compare(body,plan) if plan.accepted else {}
		var after_queries := snapshot(body)
		var record := {"tick":tick,"frame":frame,"actualDelta":body.get_physics_process_delta_time(),"physicsHz":60,"timeScale":1,
			"actualBodyGlobalTransform":before.bodyTransform,
			"input":input,"sprint":false,"jump":false,"beforeQueries":before,"afterQueries":after_queries,
			"bodyRid":body.get_rid(),"shapeRid":capsule.get_rid(),"actualShape":PhysicsServer3D.shape_get_data(capsule.get_rid()),
			"shapeOffset":body.get_child(0).transform,"collisionLayer":body.collision_layer,"collisionMask":body.collision_mask,
			"proofEligible":plan.accepted,"readOnlyOriginalProof":plan,"comparison":paired.get("receipt",{}),
			"queryOriginScope":"hypothetical raised/forward pose while actual body remains original grounded pose"}
		result.records.append(record)
		if before!=after_queries: finish("query_mutated_observed_body_state",true,1); return
		if plan.accepted:
			for name: String in ["short","parentSnap","parentForward"]:
				if not paired[name].valid: finish("invalid_query_result",true,1); return
			record.queries = {"oldShort32":paired.short.record,"modeledParentSnap4":paired.parentSnap.record,"modeledParentForward6":paired.parentForward.record}
			record.rawTravelDeltaFullMinusShort = paired.parentSnap.travel-paired.short.travel
		body.step(1.0/60.0,input,false,false) # exactly one unchanged ordinary step; no UP application
		record.afterOrdinaryStep = snapshot(body)
		record.wholeFrameDelta = body.global_position-before.bodyTransform.origin
		record.slides = Slides.capture(body)
		if body.reset_count!=1 or not body.global_position.is_finite(): finish("ordinary_response_fault",true,1); return
		if plan.accepted:
			result.comparisonCollected = true
			result.completedCases = 1
			finish("comparison_collected_not_query_agreement_or_step_admission",false,0);return
	finish("no_eligible_query_event",true,1)
