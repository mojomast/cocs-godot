extends SceneTree
const Candidate = preload("candidate.gd")
const Policy = preload("policy.gd")
const OriginalProof = preload("res://tests/walker_step_up/sweep_proposal.gd")
const Fixtures = preload("res://tests/walker_admission/fixtures_v4.gd")
const Slides = preload("res://tests/walker_admission/slide_telemetry.gd")
var grant_id := ""
var grant_sha := ""
var selected_mode := ""
var selected_group := ""
var ready_to_write := false
var receipt: Dictionary = {"failed":true,"candidateResponseCollected":false,"responseGuardPassed":false,
	"positiveAdmission":false,"nativeStepAdmission":false,"candidateMapWalks":0,"appliedUpCount":0,"parentResponseCount":0,
	"candidateAttempts":0,"records":[],"outcome":"not_started"}

func _initialize() -> void:
	var seen := {}
	for arg: String in OS.get_cmdline_user_args():
		var key := arg.get_slice("=",0)
		if seen.has(key) or not "=" in arg: quit(2); return
		seen[key] = true
		match key:
			"--grant-id": grant_id = arg.trim_prefix("--grant-id=")
			"--grant-sha256": grant_sha = arg.trim_prefix("--grant-sha256=")
			"--mode": selected_mode = arg.trim_prefix("--mode=")
			"--group": selected_group = arg.trim_prefix("--group=")
			_: quit(2); return
	if seen.size()!=4 or selected_mode!=Policy.MODE or selected_group!=Policy.GROUP or FileAccess.file_exists("res://response-result.json"): quit(2); return
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

func finish(outcome: String, failed: bool, code: int) -> void:
	if ready_to_write and not FileAccess.file_exists("res://response-result.json"):
		receipt.outcome = outcome;receipt.failed = failed;receipt.finishedUnix = Time.get_unix_time_from_system()
		var output := FileAccess.open("res://response-result.json",FileAccess.WRITE)
		if output!=null: output.store_string(JSON.stringify(encode(receipt),"\t")+"\n");output.close()
	quit(code)

func factory(mode: String) -> Candidate:
	if mode!=Policy.MODE or selected_group!=Policy.GROUP: return null
	return Candidate.new() # one body only; ordinary_step is inherited Walker.step

func run() -> void:
	var source := read_json("res://source.json")
	var grant := read_json("res://grant.json")
	var source_hash := FileAccess.get_sha256("res://source.json")
	var engine_hash := FileAccess.get_sha256(OS.get_executable_path())
	if FileAccess.get_sha256("res://grant.json")!=grant_sha or not Policy.grant_valid(grant,selected_group,selected_mode,grant_id,source_hash,engine_hash,Time.get_unix_time_from_system()): quit(2); return
	if source.get("phase")!=Policy.PHASE or source.get("mode")!=Policy.MODE or source.get("allowedGroups")!=[Policy.GROUP] or not source.get("files") is Dictionary: quit(2); return
	for path: String in source.files:
		if not path.begins_with("res://") or ".." in path or FileAccess.get_sha256(path)!=source.files[path]: quit(2); return
	ready_to_write = true
	receipt.merge({"phase":Policy.PHASE,"mode":selected_mode,"group":selected_group,"grantId":grant_id,"grantSha256":grant_sha,
		"sourceSha256":source_hash,"engineSha256":engine_hash,"engine":Engine.get_version_info(),"AFIdentity":source.AFIdentity,
		"configuredPhysicsEngineSetting":ProjectSettings.get_setting("physics/3d/physics_engine","DEFAULT"),"backendImplementationVerified":false,
		"parentInternalTraceCaptured":false,"queryScope":"modeled requests at hypothetical raised/edge transforms"})
	var version := Engine.get_version_info()
	if version.major!=4 or version.minor!=5 or version.patch!=2 or Engine.physics_ticks_per_second!=60 or Engine.time_scale!=1.0: finish("engine_or_clock",true,2); return
	create_timer(170).timeout.connect(func() -> void: finish("internal_timeout",true,2))
	var spec := {"radius":.35,"yaw":-PI/4,"incline":0.0,"start":-1.0,"goal":1.0}
	var fixture := Fixtures.make(root,spec)
	var body := factory(selected_mode)
	if body==null: finish("factory_denied",true,2); return
	fixture.world.add_child(body);body.set_physics_process(false);body.set_spawn(fixture.start,spec.yaw)
	if body.get_script()!=Candidate: finish("candidate_factory_identity",true,2); return
	var capsule: CapsuleShape3D = body.get_child(0).shape
	if not is_equal_approx(capsule.radius,.35) or not is_equal_approx(capsule.height,1.8) or not is_equal_approx(body.rotation.y,-PI/4): finish("fixed_profile_mismatch",true,2); return
	receipt.geometry = fixture.faces;receipt.targetRid = fixture.topRid;receipt.targetShapeIndex = fixture.topShapeIndex
	receipt.bodyRid = body.get_rid();receipt.shapeRid = capsule.get_rid();receipt.actualShape = PhysicsServer3D.shape_get_data(capsule.get_rid())
	receipt.shapeOffset = body.get_child(0).transform;receipt.collisionLayer = body.collision_layer;receipt.collisionMask = body.collision_mask
	receipt.parameters = {"floorSnapLength":body.floor_snap_length,"floorMaxAngle":body.floor_max_angle,"safeMargin":body.safe_margin,
		"upDirection":body.up_direction,"floorStopOnSlope":body.floor_stop_on_slope,"floorConstantSpeed":body.floor_constant_speed,
		"walkSpeed":body.WALK_SPEED,"sprintSpeed":body.SPRINT_SPEED,"gravity":body.GRAVITY,"jumpSpeed":body.JUMP_SPEED,"actualYaw":body.rotation.y}
	var previous := -1
	for tick in range(60):
		await physics_frame
		var frame := Engine.get_physics_frames()
		if not Engine.is_in_physics_frame() or Engine.physics_ticks_per_second!=60 or Engine.time_scale!=1.0 or absf(body.get_physics_process_delta_time()-1.0/60.0)>1e-8 or (previous>=0 and frame!=previous+1): finish("actual_clock_failure",true,2); return
		previous = frame
		if tick==20 and not body.is_on_floor(): finish("not_grounded_after_settle",true,1); return
		var input := Vector2.ZERO if tick<20 else Vector2(0,-1)
		var before := body.state()
		var original := OriginalProof.propose(body,1.0/60.0,input,false,false)
		var after_proof := body.state()
		var record := {"tick":tick,"frame":frame,"actualDelta":body.get_physics_process_delta_time(),"physicsHz":60,"timeScale":1,
			"input":input,"jump":false,"sprint":false,"beforeOriginalProof":before,"afterOriginalProof":after_proof,"originalProof":original}
		receipt.records.append(record)
		if before!=after_proof: finish("original_proof_mutated_body",true,1); return
		if not original.accepted:
			body.ordinary_step(1.0/60.0,input)
			record.afterOrdinaryStep = body.state();record.slides = Slides.capture(body)
			record.wholeFrameDelta = body.global_position-before.transform.origin
			if not body.candidate_fault.is_empty() or body.reset_count!=1 or not body.global_position.is_finite(): finish("ordinary_response_fault",true,1); return
			continue
		# First original eligibility is the only trigger. No goal loop or retry.
		body.step(1.0/60.0,input,false,false)
		record.parityProposal = body.last_step_proposal;record.candidateTelemetry = body.telemetry
		record.afterCandidate = body.state();record.candidateFault = body.candidate_fault;record.slides = Slides.capture(body)
		record.wholeFrameDelta = body.global_position-before.transform.origin
		receipt.candidateAttempts = body.response_attempts;receipt.appliedUpCount = body.applied_up_count;receipt.parentResponseCount = body.parent_response_count
		receipt.candidateResponseCollected = body.candidate_response_collected;receipt.responseGuardPassed = body.response_guard_passed
		if not body.candidate_fault.is_empty(): finish("candidate_fault:"+body.candidate_fault,true,1); return
		if not body.last_step_proposal.accepted: finish("parity_policy_rejected:"+str(body.last_step_proposal.reason),true,1); return
		if body.reset_count!=1 or not body.global_position.is_finite(): finish("candidate_reset_or_nonfinite",true,1); return
		if body.telemetry.afterParent!=body.telemetry.afterGuard: finish("guard_mutated_body",true,1); return
		if body.response_attempts!=1 or body.applied_up_count!=1 or body.parent_response_count!=1 or not body.candidate_response_collected or not body.response_guard_passed: finish("incomplete_single_response",true,1); return
		finish("single_response_guard_passed_not_positive_admission",false,0);return
	finish("no_eligible_original_proof",true,1)
