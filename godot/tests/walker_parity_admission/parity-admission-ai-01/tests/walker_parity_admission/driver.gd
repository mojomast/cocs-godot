extends SceneTree
const Walker = preload("res://exploration/walker.gd")
const Candidate = preload("candidate.gd")
const Policy = preload("policy.gd")
const Observe = preload("observe.gd")
const Proposal = preload("res://tests/walker_step_up/sweep_proposal.gd")
const Guard = preload("res://tests/walker_step_up/response_guard.gd")
const Controls = preload("res://tests/walker_step_up/controls_v2.gd")
const Fixtures = preload("res://tests/walker_admission/fixtures_v4.gd")
const Slides = preload("res://tests/walker_admission/slide_telemetry.gd")
var group := ""
var mode := ""
var grant_id := ""
var grant_hash := ""
var deps_hash := ""
var admission_failure_reported := false
var admission_hashes: Dictionary = {}
var ready := false
var previous_frame := -1
var active_pair: Dictionary = {}
var active_profile: Dictionary = {}
var receipt := {"phase":Policy.PHASE,"mode":Policy.MODE,"scope":"synthetic-admission","failed":true,"passed":false,
	"positiveAdmission":false,"nativeStepAdmission":false,"productionPromotion":false,"candidateMapWalks":0,
	"attemptedPairs":0,"completedPairs":0,"passedPairs":0,"failedPairs":0,"interruptedPairs":0,"unrunPairs":0,
	"attemptedProfiles":0,"completedProfiles":0,"failedProfiles":0,"interruptedProfiles":0,"unrunProfiles":0,"records":[]}

func _initialize() -> void:
	var seen := {}
	for arg: String in OS.get_cmdline_user_args():
		var key := arg.get_slice("=",0)
		if seen.has(key) or not "=" in arg: fail_admission("args.duplicate_or_malformed");return
		seen[key] = true
		match key:
			"--group": group = arg.trim_prefix("--group=")
			"--mode": mode = arg.trim_prefix("--mode=")
			"--grant-id": grant_id = arg.trim_prefix("--grant-id=")
			"--grant-sha256": grant_hash = arg.trim_prefix("--grant-sha256=")
			"--dependencies-sha256": deps_hash = arg.trim_prefix("--dependencies-sha256=")
			_: fail_admission("args.unknown");return
	if seen.size()!=5: fail_admission("args.count");return
	if not group in Policy.GROUPS: fail_admission("args.group");return
	if mode!=Policy.MODE: fail_admission("args.mode");return
	if FileAccess.file_exists("res://"+group+"-result.json"): fail_admission("output.exists");return
	call_deferred("run")

func fail_admission(code: String, details: Dictionary = {}) -> bool:
	# Diagnostic only: no file writes, world construction or caller text/paths.
	# The supervisor already captures stderr in its write-once owned log.
	if not admission_failure_reported:
		admission_failure_reported = true
		var diagnostic := {"schema":"parity-admission-gate-failure-v1","stage":"pre_world_admission",
			"code":code,"phase":Policy.PHASE,"mode":Policy.MODE,"group":group if group in Policy.GROUPS else null,
			"failed":true,"exitCode":2,"nativeCountersKnown":false,"physicalCallCounts":null,
			"hashes":admission_hashes.duplicate(),"details":{}}
		# Bounded fixed-schema metadata only. Invalid CLI values are never echoed.
		for key: String in ["predecessor","predicate","inputSha256","expectedSha256"]:
			if details.has(key): diagnostic.details[key] = details[key]
		printerr("ADMISSION_FAILURE "+JSON.stringify(diagnostic))
	quit(2)
	return false

func finish(reason: String, failed: bool, code: int) -> void:
	if ready:
		if failed:
			var status := "interrupted" if code==2 else "failed"
			if active_profile.get("status")=="running":
				active_profile.status = status
				if code==2: receipt.interruptedProfiles += 1
				else: receipt.failedProfiles += 1;receipt.completedProfiles += 1
			if active_pair.get("status")=="running":
				active_pair.status = status
				if code==2: receipt.interruptedPairs += 1
				else: receipt.failedPairs += 1;receipt.completedPairs += 1
		else: receipt.passed = true;receipt.positiveAdmission = group==Policy.GROUPS[2]
		receipt.failed = failed;receipt.outcome = reason;receipt.finishedUnix = Time.get_unix_time_from_system()
		var path := "res://"+group+"-result.json"
		if not FileAccess.file_exists(path):
			var file := FileAccess.open(path,FileAccess.WRITE)
			if file!=null: file.store_string(JSON.stringify(Observe.encode(receipt),"\t")+"\n");file.close()
	quit(code)

func predecessors(source_hash: String, engine_hash: String) -> bool:
	var path := "res://"+group+"-dependencies.json"
	var actual_dependencies_hash := FileAccess.get_sha256(path)
	admission_hashes.dependenciesSha256 = actual_dependencies_hash
	if actual_dependencies_hash!=deps_hash: return fail_admission("dependencies.hash",{"inputSha256":actual_dependencies_hash,"expectedSha256":deps_hash if Policy.hash_valid(deps_hash) else null})
	var d := Observe.read_json(path)
	if d.get("phase")!=Policy.PHASE or d.get("group")!=group or d.get("sourceSha256")!=source_hash or d.get("grantSha256")!=grant_hash or d.get("engineSha256")!=engine_hash or not d.get("predecessors") is Dictionary: return fail_admission("dependencies.binding_schema")
	var index := Policy.GROUPS.find(group)
	if d.predecessors.size()!=index: return fail_admission("dependencies.predecessor_count")
	for i in range(index):
		var prior: String = Policy.GROUPS[i]
		if not d.predecessors.has(prior): return fail_admission("dependencies.predecessor_missing",{"predecessor":prior})
		var rpath := "res://"+prior+"-result.json"
		var spath := "res://"+prior+"-supervisor.json"
		if not d.predecessors[prior] is Dictionary: return fail_admission("dependencies.predecessor_schema",{"predecessor":prior})
		var h: Dictionary = d.predecessors[prior]
		var native_hash := FileAccess.get_sha256(rpath)
		var supervisor_hash := FileAccess.get_sha256(spath)
		admission_hashes.predecessorNativeSha256 = native_hash
		admission_hashes.predecessorSupervisorSha256 = supervisor_hash
		if native_hash!=h.get("resultSha256"): return fail_admission("predecessor.native_hash",{"predecessor":prior})
		if supervisor_hash!=h.get("supervisorSha256"): return fail_admission("predecessor.supervisor_hash",{"predecessor":prior})
		var r := Observe.read_json(rpath);var s := Observe.read_json(spath)
		if not Policy.successful(r,prior,source_hash,grant_hash,engine_hash): return fail_admission("predecessor.native_policy",{"predecessor":prior,"predicate":"Policy.successful"})
		if not Policy.Evidence.supervisor_ok(s,prior,source_hash,grant_hash,engine_hash,h.resultSha256): return fail_admission("predecessor.supervisor_policy",{"predecessor":prior,"predicate":"Evidence.supervisor_ok"})
	return true

func run() -> void:
	var config := Observe.read_json("res://source.json");var grant := Observe.read_json("res://grant.json")
	var source_hash := FileAccess.get_sha256("res://source.json");var engine_hash := FileAccess.get_sha256(OS.get_executable_path())
	admission_hashes = {"sourceSha256":source_hash,"engineSha256":engine_hash,"grantSha256":FileAccess.get_sha256("res://grant.json")}
	if admission_hashes.grantSha256!=grant_hash: fail_admission("grant.hash");return
	if not Policy.grant_valid(grant,group,mode,grant_id,source_hash,engine_hash,Time.get_unix_time_from_system()): fail_admission("grant.policy",{"predicate":"Policy.grant_valid"});return
	if config.get("phase")!=Policy.PHASE or config.get("mode")!=Policy.MODE or config.get("order")!=Policy.GROUPS or not config.get("files") is Dictionary: fail_admission("source.binding_schema");return
	for path: String in config.files:
		if not path.begins_with("res://") or ".." in path: fail_admission("source.input_namespace");return
		if FileAccess.get_sha256(path)!=config.files[path]: fail_admission("source.input_hash",{"inputSha256":FileAccess.get_sha256(path)});return
	if not predecessors(source_hash,engine_hash): return
	ready = true
	var n: int = Policy.COUNTS[Policy.GROUPS.find(group)]
	receipt.unrunPairs = n;receipt.unrunProfiles = 2*n
	receipt.merge({"group":group,"grantId":grant_id,"grantSha256":grant_hash,"sourceSha256":source_hash,"engineSha256":engine_hash,
		"dependenciesSha256":deps_hash,"lineage":config.lineage,"engine":Engine.get_version_info(),
		"configuredPhysicsEngineSetting":ProjectSettings.get_setting("physics/3d/physics_engine","DEFAULT"),"backendImplementationVerified":false,
		"parentInternalCallsTraced":false,"partialCounters":"post-return values only; interrupted paths can be unknown"})
	var v := Engine.get_version_info()
	if v.major!=4 or v.minor!=5 or v.patch!=2 or Engine.physics_ticks_per_second!=60 or Engine.time_scale!=1.0: finish("engine_or_clock",true,2);return
	create_timer(170).timeout.connect(func() -> void: finish("internal_timeout",true,2))
	if group==Policy.GROUPS[0]: await negatives()
	else: await traversals()

func body_for(experimental: bool, radius: float, fixture: Dictionary) -> Walker:
	var body: Walker = Candidate.new() if experimental else Walker.new()
	var capsule: CapsuleShape3D = body.get_child(0).shape
	capsule.radius = radius;body.set_physics_process(false)
	if experimental:
		(body as Candidate).configure(group==Policy.GROUPS[2],fixture.get("topRid",RID()),0,float(fixture.faces[0].y) if fixture.has("faces") else 0.0,radius)
	return body

func begin_pair(spec: Dictionary) -> void:
	active_pair = {"caseIndex":receipt.attemptedPairs,"spec":spec,"status":"running","profiles":[]}
	receipt.records.append(active_pair);receipt.attemptedPairs += 1;receipt.unrunPairs -= 1

func begin_profile(experimental: bool, body: Walker, world: Node3D) -> bool:
	var capsule: CapsuleShape3D = body.get_child(0).shape
	active_profile = {"experimental":experimental,"status":"running","settle":[],"frames":[],"appliedUpCount":0,"verifiedLifts":0,
		"reached":false,"stallCount":0,"inclinedWitnesses":0,"ordinaryLandingStreak":0,"parameters":{"shape":PhysicsServer3D.shape_get_data(capsule.get_rid()),
		"shapeRid":capsule.get_rid(),"bodyRid":body.get_rid(),"offset":body.get_child(0).transform,"margin":body.safe_margin,"snap":body.floor_snap_length,
		"floorAngle":body.floor_max_angle,"walk":body.WALK_SPEED,"sprint":body.SPRINT_SPEED,"gravity":body.GRAVITY,"jump":body.JUMP_SPEED,
		"layer":body.collision_layer,"mask":body.collision_mask},"geometry":[]}
	for node: Node in world.find_children("*","StaticBody3D",true,false):
		var fixed := node as StaticBody3D
		for owner: int in fixed.get_shape_owners():
			for index in fixed.shape_owner_get_shape_count(owner):
				var shape := fixed.shape_owner_get_shape(owner,index)
				active_profile.geometry.append({"name":fixed.name,"rid":fixed.get_rid(),"bodyTransform":fixed.global_transform,"offset":fixed.shape_owner_get_transform(owner),"shapeRid":shape.get_rid(),"shapeData":PhysicsServer3D.shape_get_data(shape.get_rid()),"linearVelocity":fixed.constant_linear_velocity})
	active_pair.profiles.append(active_profile);receipt.attemptedProfiles += 1;receipt.unrunProfiles -= 1;previous_frame = -1
	var actual: Dictionary = active_profile.parameters.shape
	if not is_equal_approx(actual.radius,float(active_pair.spec.radius)) or not is_equal_approx(actual.height,1.8) or not body.get_child(0).position.is_equal_approx(Vector3(0,.9,0)) or not is_equal_approx(body.safe_margin,.02) or not is_equal_approx(body.floor_snap_length,.3) or not is_equal_approx(body.floor_max_angle,deg_to_rad(46.0)) or body.WALK_SPEED!=6.0 or body.SPRINT_SPEED!=10.0 or body.GRAVITY!=20.0 or body.JUMP_SPEED!=6.5 or not body.floor_stop_on_slope or body.floor_constant_speed:
		finish("profile_parameter_mismatch",true,2);return false
	return true

func sample(body: Walker, input: Vector2, jump: bool = false) -> Dictionary:
	var frame := Engine.get_physics_frames()
	var before := Observe.state(body)
	var row := {"frame":frame,"usec":Time.get_ticks_usec(),"actualDelta":body.get_physics_process_delta_time(),"physicsHz":Engine.physics_ticks_per_second,"timeScale":Engine.time_scale,"input":input,"jump":jump,"sprint":false,"before":before,"returned":false}
	active_profile.inflight = row # preserve a partial current response on failure
	if not Engine.is_in_physics_frame() or Engine.physics_ticks_per_second!=60 or Engine.time_scale!=1.0 or absf(body.get_physics_process_delta_time()-1.0/60.0)>1e-8 or (previous_frame>=0 and frame!=previous_frame+1): finish("nonconsecutive_clock",true,2);return {}
	previous_frame = frame
	if not body is Candidate:
		row.proposal = Proposal.propose(body,1.0/60.0,input,false,jump)
		row.afterQueries = Observe.state(body)
		if row.afterQueries!=before: finish("baseline_query_mutation",true,1);return row
	body.step(1.0/60.0,input,false,jump)
	row.after = Observe.state(body);row.wholeFrameDelta = body.global_position-before.transform.origin;row.slides = Slides.capture(body)
	row.bodyRid = body.get_rid();row.floorConstantSpeed = body.floor_constant_speed
	row.candidateFault = ""
	if body is Candidate:
		var candidate := body as Candidate
		row.proposal = candidate.last_step_proposal;row.lifecycle = candidate.lifecycle;row.telemetry = candidate.telemetry
		# Serialization-only binding: frozen guard calls Proposal.sweep on this body.
		if row.proposal.has("responseGuard") and row.proposal.responseGuard.has("support"):
			row.proposal.responseGuard.support.bodyRid = body.get_rid()
			# Pinned sweep creates fresh parameters and leaves both exclusion lists empty.
			row.proposal.responseGuard.support.excludeBodies = []
			row.proposal.responseGuard.support.excludeObjects = []
		row.appliedUpCount = candidate.applied_up_count;row.responseGuardPassed = candidate.response_guard_passed;row.candidateFault = candidate.candidate_fault
		active_profile.appliedUpCount = candidate.total_applied;active_profile.verifiedLifts = candidate.total_verified
	row.returned = true
	return row

func valid_sample(row: Dictionary) -> bool:
	if row.is_empty() or not row.has("after"): return false
	if row.after.resetCount!=1 or not row.after.transform.origin.is_finite() or not row.candidateFault.is_empty(): finish("candidate_or_reset_fault",true,1);return false
	return true

func complete_profile(outcome: String) -> void:
	active_profile.status = "completed";active_profile.outcome = outcome;receipt.completedProfiles += 1

func complete_pair(compare_all: bool) -> bool:
	if compare_all:
		var a: Array = active_pair.profiles[0].settle+active_pair.profiles[0].frames
		var b: Array = active_pair.profiles[1].settle+active_pair.profiles[1].frames
		if a.size()!=b.size(): finish("paired_response_count_differs",true,1);return false
		for i in a.size():
			var epsilon := Guard.numeric_budget([a[i].after.transform.origin,b[i].after.transform.origin])
			if epsilon<0.0 or a[i].after.transform.origin.distance_to(b[i].after.transform.origin)>epsilon or a[i].after.velocity.distance_to(b[i].after.velocity)>epsilon or a[i].after.grounded!=b[i].after.grounded: finish("ordinary_response_pair_differs",true,1);return false
	active_pair.status = "passed";receipt.completedPairs += 1;receipt.passedPairs += 1
	return true

func negatives() -> void:
	for id: String in Controls.cases():
		for radius: float in [.35,.42]:
			begin_pair({"id":id,"radius":radius})
			for experimental: bool in [false,true]:
				var fixture := Controls.scene(id);root.add_child(fixture.world)
				var parent := Node3D.new();fixture.world.add_child(parent)
				var body := body_for(experimental,radius,fixture);parent.add_child(body);body.set_physics_process(false)
				body.set_spawn(Vector3(0,1.0 if id=="airborne" else .05,-.32-(radius-.35)*.6))
				if not begin_profile(experimental,body,fixture.world): return
				for tick in range(1 if id=="airborne" else 20):
					await physics_frame
					var r := sample(body,Vector2.ZERO);active_profile.settle.append(r)
					if not valid_sample(r): return
				if id=="jumping":
					await physics_frame
					var r := sample(body,Vector2.ZERO,true);active_profile.frames.append(r)
					if not valid_sample(r): return
				if id=="tilted-body": body.rotation.z = .1
				if id=="transformed-parent": parent.position.x = .2
				await physics_frame
				var input := Vector2.ZERO if id=="no-input" else Vector2(1,-1).normalized() if id=="lateral" else Vector2(0,-1)
				var r := sample(body,input);active_profile.frames.append(r)
				if not valid_sample(r): return
				if r.proposal.accepted or not r.proposal.reason in fixture.reasons or active_profile.appliedUpCount!=0: finish("unexpected_negative_mechanism",true,1);return
				active_profile.expectedReasons = fixture.reasons
				complete_profile("expected_original_rejection_and_ordinary_response")
				fixture.world.queue_free();await process_frame
			if not complete_pair(true): return
	finish("negative_control_group_pass",false,0)

func inclined_witness(plan: Dictionary, fixture: Dictionary) -> bool:
	if fixture.normal.dot(Vector3.UP)>=cos(deg_to_rad(46.0)): return false
	for stage: Dictionary in plan.stages:
		if stage.name!="intent": continue
		for contact: Dictionary in stage.contacts:
			if contact.collider==str(fixture.top.get_path()) and int(contact.colliderShape)==0 and contact.point.y>0.0 and contact.point.y<.25 and -contact.normal.slide(Vector3.UP).normalized().dot(fixture.direction)>=.98: return true
	return false

func traversals() -> void:
	for spec: Dictionary in Fixtures.cases(group):
		begin_pair(spec)
		for experimental: bool in [false,true]:
			var fixture := Fixtures.make(root,spec);var body := body_for(experimental,spec.radius,fixture)
			fixture.world.add_child(body);body.set_physics_process(false);body.set_spawn(fixture.start,spec.yaw)
			if not begin_profile(experimental,body,fixture.world): return
			active_profile.targetRid = fixture.topRid;active_profile.targetShape = 0
			active_profile.target = {"rid":fixture.topRid,"shape":0,"path":str(fixture.top.get_path()),"faces":fixture.faces,"direction":fixture.direction,"normal":fixture.normal}
			for tick in range(20):
				await physics_frame
				var r := sample(body,Vector2.ZERO);active_profile.settle.append(r)
				if not valid_sample(r): return
			if not body.is_on_floor(): finish("not_settled",true,1);return
			for tick in range(int(spec.maxResponses)):
				await physics_frame
				var r := sample(body,Vector2(0,-1));active_profile.frames.append(r)
				if not valid_sample(r): return
				if spec.incline>0:
					if r.proposal.accepted: finish("inclined_original_admitted",true,1);return
					if r.proposal.reason=="no_continuous_flat_landing":
						if not inclined_witness(r.proposal,fixture): finish("wrong_inclined_witness",true,1);return
						active_profile.inclinedWitnesses += 1
					elif r.proposal.reason!="no_bounded_riser": finish("unexpected_inclined_rejection",true,1);return
				var along: float = body.global_position.dot(fixture.direction)
				if experimental and spec.incline==0 and body.is_on_floor() and body.global_position.y>float(fixture.faces[0].y)+body.safe_margin+.0001: finish("grounded_profile_height_cap",true,1);return
				if absf(body.global_position.dot(fixture.direction.cross(Vector3.UP)))>.0001: finish("left_centerline",true,1);return
				active_profile.stallCount = int(active_profile.stallCount)+1 if r.wholeFrameDelta.length()<.0001 else 0
				var ordinary: bool = not experimental or r.lifecycle.ordinary
				if spec.incline==0 and ordinary and Observe.footprint(body,fixture) and body.is_on_floor() and absf(body.global_position.y-.15)<=body.safe_margin+.0001: active_profile.ordinaryLandingStreak += 1
				else: active_profile.ordinaryLandingStreak = 0
				if spec.incline==0 and along>=float(spec.goal):
					active_profile.finalSupport = Observe.landing(body,fixture)
					if not active_profile.finalSupport.passed: finish("arrival_support_not_qualified",true,1);return
					active_profile.reached = true
					if not experimental: finish("unexpected_baseline_arrival",true,1);return
					if active_profile.ordinaryLandingStreak<3 or active_profile.verifiedLifts<1 or active_profile.appliedUpCount!=active_profile.verifiedLifts: finish("arrival_not_sustained_and_guarded",true,1);return
					break
				if active_profile.stallCount>=120: break
			if spec.incline>0:
				if active_profile.inclinedWitnesses<1 or active_profile.stallCount<120 or active_profile.appliedUpCount!=0: finish("incline_not_witnessed_blocked",true,1);return
				complete_profile("expected_inclined_rejection_and_block")
			elif experimental:
				if not active_profile.reached: finish("candidate_no_full_tread_arrival",true,1);return
				complete_profile("full_tread_guarded_arrival")
			else:
				if active_profile.reached or active_profile.stallCount<120: finish("baseline_not_blocked",true,1);return
				complete_profile("expected_baseline_blocked")
			fixture.world.queue_free();await process_frame
		if not complete_pair(spec.incline>0): return
	finish("synthetic_group_pass",false,0)
