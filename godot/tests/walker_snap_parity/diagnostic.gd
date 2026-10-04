extends "res://tests/walker_step_up/driver_v2.gd"
const Pair = preload("query_pair.gd")
const Parity = preload("candidate.gd")
const Original = preload("res://tests/walker_admission/candidate_telemetry_v4.gd")
const Fixtures = preload("res://tests/walker_admission/fixtures_v4.gd")
const Slides = preload("res://tests/walker_admission/slide_telemetry.gd")
const GROUPS := ["original-query-observation","snap-parity-candidate"]

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="): directory = arg.trim_prefix("--fixture=")
		elif arg.begins_with("--group="): group_id = arg.trim_prefix("--group=")
		elif arg.begins_with("--grant-id="): grant_id = arg.trim_prefix("--grant-id=")
		elif arg.begins_with("--grant-sha256="): grant_sha = arg.trim_prefix("--grant-sha256=")
		else: quit(2); return
	if not directory.begins_with("res://tests/walker_snap_parity/") or not directory.ends_with("/") or ".." in directory or not group_id in GROUPS: quit(2); return
	output = directory+group_id+"-result.json"
	if FileAccess.file_exists(output): quit(2); return
	create_timer(170).timeout.connect(func() -> void: finish("timeout",true,2))
	call_deferred("run")

func run() -> void:
	config = read_json(directory+"source.json")
	var grant := read_json(directory+"grant.json")
	receipt.merge({"group":group_id,"grantId":grant_id,"sourceSha256":FileAccess.get_sha256(directory+"source.json"),
		"grantSha256":FileAccess.get_sha256(directory+"grant.json"),"nativeStepAdmission":false,"candidateMapWalks":0,"records":[]})
	if grant.get("phase")!="snap-query-parity-only-v1" or not grant.get("authorized",false) or grant_id.is_empty() or grant.get("grantId")!=grant_id or receipt.grantSha256!=grant_sha or grant.get("sourceSha256")!=receipt.sourceSha256 or float(grant.get("expiresUnix",0))<=Time.get_unix_time_from_system(): finish("explicit_future_grant_required",true,2); return
	var allowed: Variant = grant.get("allowedGroups")
	if not allowed is Array or allowed.is_empty() or not group_id in allowed or grant.has("groups") or grant.has("continueAfterKnownBaselineFailure"): finish("restricted_groups_required",true,2); return
	var seen := {}
	for item: Variant in allowed:
		if not item is String or not item in GROUPS or seen.has(item): finish("unknown_or_map_group",true,2); return
		seen[item] = true
	for path: String in config.files:
		if FileAccess.get_sha256(path)!=config.files[path]: finish("source_drift",true,2); return
	var v := Engine.get_version_info()
	if v.major!=4 or v.minor!=5 or v.patch!=2: finish("wrong_engine",true,2); return
	var spec := {"radius":.35,"yaw":-PI/4,"incline":0.0,"start":-1.0,"goal":1.0}
	var fixture := Fixtures.make(root,spec)
	var body: Baseline = Original.new() if group_id==GROUPS[0] else Parity.new()
	fixture.world.add_child(body);body.set_physics_process(false)
	body.set_spawn(fixture.start,spec.yaw)
	receipt.parameters = parameters(body)
	receipt.geometry = fixture.faces
	receipt.targetRid = fixture.topRid
	receipt.attempted = 1
	var previous := -1
	for frame in range(60):
		await physics_frame
		if not require_clock(body) or (previous>=0 and Engine.get_physics_frames()!=previous+1): finish("clock_failure",true,2); return
		previous = Engine.get_physics_frames()
		var input := Vector2.ZERO if frame<20 else Vector2(0,-1)
		var old := Proposal.propose(body,1.0/60.0,input,false,false)
		var comparison: Dictionary = Pair.compare(body,old) if old.accepted else {}
		var sample := super.step_record(body,input)
		var selected_plan: Dictionary = (body as Original).last_step_proposal if body is Original else (body as Parity).last_step_proposal
		var fault: String = (body as Original).candidate_fault if body is Original else (body as Parity).candidate_fault
		sample.proposal = selected_plan
		sample.candidateFault = fault
		sample.collisions = Slides.capture(body)
		sample.queryComparison = comparison.get("receipt",{})
		sample.originalPlanner = old
		receipt.records.append(sample)
		if sample.resetCount!=1 or not fault.is_empty(): receipt.failedTrials = 1; finish("candidate_fault:"+fault,true,1); return
		if old.accepted:
			if group_id==GROUPS[0]: finish("original_outcome_changed_requires_review",true,1); return
			if not selected_plan.accepted or not selected_plan.get("responseGuard",{}).get("passed",false): receipt.failedTrials = 1; finish("parity_proof_not_admitted",true,1); return
			receipt.passed = 1
			finish("single_response_parity_matched_not_tread_landing",false,0);return
	finish("no_eligible_edge_encounter",true,1)
