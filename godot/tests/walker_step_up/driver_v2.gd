extends SceneTree
## SOURCE PREPARED ONLY. Explicit future grant and one bounded group per invocation.
const Baseline = preload("res://exploration/walker.gd")
const Candidate = preload("candidate_walker.gd")
const Proposal = preload("sweep_proposal.gd")
const Response = preload("response_guard.gd")
const Controls = preload("controls_v2.gd")
const Binding = preload("res://tests/new_maps/botanical_post_x/art_binding.gd") # reviewed worktree copy, SHA-pinned by preparation
var directory := ""
var group_id := ""
var grant_id := ""
var grant_sha := ""
var continuation := false
var config: Dictionary = {}
var receipt: Dictionary = {"status":"started","failed":true,"attempted":0,"passed":0,"failedTrials":0,"unrun":0,"records":[]}
var output := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="): directory = arg.trim_prefix("--fixture=")
		if arg.begins_with("--group="): group_id = arg.trim_prefix("--group=")
		if arg.begins_with("--grant-id="): grant_id = arg.trim_prefix("--grant-id=")
		if arg.begins_with("--grant-sha256="): grant_sha = arg.trim_prefix("--grant-sha256=")
		if arg=="--continue-after-known-baseline-failure": continuation = true
	if not directory.begins_with("res://tests/walker_step_up/") or not directory.ends_with("/") or ".." in directory or group_id.is_empty(): quit(2); return
	for character: String in group_id:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789-": quit(2); return
	output = directory+group_id+"-result.json"
	if FileAccess.file_exists(output): push_error("Write-once group already exists"); quit(2); return
	create_timer(170).timeout.connect(func() -> void: finish("timeout",true,2))
	call_deferred("run")

func encode(value: Variant) -> Variant:
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Vector2: return [value.x,value.y]
	if value is Transform3D: return {"origin":encode(value.origin),"basis":[encode(value.basis.x),encode(value.basis.y),encode(value.basis.z)]}
	if value is RID: return value.get_id()
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[str(key)] = encode(value[key])
		return result
	if value is Array or value is PackedVector3Array or value is PackedVector2Array:
		var result: Array = []
		for item: Variant in value: result.append(encode(item))
		return result
	return value

func write(path: String, value: Dictionary) -> void:
	assert(not FileAccess.file_exists(path))
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify(encode(value),"\t")+"\n")
	file.close()

func read_json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func finish(reason: String, failed: bool, code: int) -> void:
	if not output.is_empty() and not FileAccess.file_exists(output):
		receipt.status = reason
		receipt.failed = failed
		receipt.finishedUnix = Time.get_unix_time_from_system()
		write(output,receipt)
	quit(code)

func clock() -> Dictionary:
	return {"frame":Engine.get_physics_frames(),"hz":Engine.physics_ticks_per_second,"scale":Engine.time_scale,"physics":Engine.is_in_physics_frame(),"usec":Time.get_ticks_usec()}

func require_clock(body: Baseline) -> bool:
	return Engine.is_in_physics_frame() and Engine.physics_ticks_per_second==60 and Engine.time_scale==1.0 and absf(body.get_physics_process_delta_time()-1.0/60.0)<1e-8

func walker(experimental: bool, radius: float) -> Baseline:
	# Explicit factories: never text-rewrite Z or dynamically change production script.
	var body: Baseline = Candidate.new() if experimental else Baseline.new()
	body.set_physics_process(false)
	var shape: CapsuleShape3D = body.get_child(0).shape
	assert(is_equal_approx(shape.radius,.35) and is_equal_approx(shape.height,1.8))
	assert(radius==.35 or radius==.42)
	shape.radius = radius
	return body

func parameters(body: Baseline) -> Dictionary:
	var collision: CollisionShape3D = body.get_child(0)
	var shape: CapsuleShape3D = collision.shape
	var actual: Dictionary = PhysicsServer3D.shape_get_data(shape.get_rid())
	assert(is_equal_approx(actual.radius,shape.radius) and is_equal_approx(actual.height,1.8))
	assert(collision.position.is_equal_approx(Vector3(0,.9,0)) and not collision.disabled)
	assert(is_equal_approx(body.safe_margin,.02) and is_equal_approx(body.floor_snap_length,.3) and is_equal_approx(body.floor_max_angle,deg_to_rad(46)))
	assert(Baseline.WALK_SPEED==6.0 and Baseline.SPRINT_SPEED==10.0 and Baseline.GRAVITY==20.0 and Baseline.JUMP_SPEED==6.5)
	assert(body.floor_stop_on_slope and not body.floor_constant_speed)
	return {"shape":actual,"offset":collision.transform,"bodyTransform":body.global_transform,"margin":body.safe_margin,"snap":body.floor_snap_length,
		"floorAngle":body.floor_max_angle,"layer":body.collision_layer,"mask":body.collision_mask,"maxSlides":body.max_slides,
		"walk":Baseline.WALK_SPEED,"sprint":Baseline.SPRINT_SPEED,"gravity":Baseline.GRAVITY,"jump":Baseline.JUMP_SPEED,"clock":clock()}

func step_record(body: Baseline, input: Vector2, jump: bool = false) -> Dictionary:
	var experimental := body as Candidate
	var before := body.global_position
	var grounded_before := body.is_on_floor()
	body.step(1.0/60.0,input,false,jump)
	var collisions: Array = []
	for index in body.get_slide_collision_count():
		var hit := body.get_slide_collision(index)
		collisions.append({"collider":str(hit.get_collider().name),"rid":hit.get_collider_rid(),"shape":hit.get_collider_shape(),
			"position":hit.get_position(),"normal":hit.get_normal(),"travel":hit.get_travel(),"remainder":hit.get_remainder()})
	var query := PhysicsRayQueryParameters3D.create(body.global_position+Vector3.UP*.3,body.global_position-Vector3.UP*.8,1,[body.get_rid()])
	var support := body.get_world_3d().direct_space_state.intersect_ray(query)
	return {"clock":clock(),"input":input,"sprint":false,"jump":jump,"before":before,"after":body.global_position,"wholeFrameDelta":body.global_position-before,
		"parentPositionDelta":body.get_position_delta(),"parentRealVelocity":body.get_real_velocity(),"velocity":body.velocity,
		"groundedBefore":grounded_before,"groundedAfter":body.is_on_floor(),"resetCount":body.reset_count,"collisions":collisions,
		"support":{} if support.is_empty() else {"position":support.position,"normal":support.normal,"rid":support.rid,"shape":support.shape,"collider":str(support.collider.name)},
		"proposal":experimental.last_step_proposal if experimental!=null else {},"candidateFault":experimental.candidate_fault if experimental!=null else ""}

func run() -> void:
	config = read_json(directory+"source.json")
	var version := Engine.get_version_info()
	receipt.merge({"group":group_id,"version":version,"clock":clock(),"sourceSha256":FileAccess.get_sha256(directory+"source.json"),"grantId":grant_id,"grantReceiptSha256":grant_sha,
		"scope":"experimental walk-only diagnostic; real-velocity accounting blocker retained; no production or 184-contact waiver"})
	if version.major!=4 or version.minor!=5 or version.patch!=2 or Engine.physics_ticks_per_second!=60 or Engine.time_scale!=1.0 or config.is_empty() or not config.groups.has(group_id): finish("version_or_config",true,2); return
	for path: String in config.files:
		if FileAccess.get_sha256(path)!=config.files[path]: finish("source_identity_failure:"+path,true,2); return
	var grant := read_json(directory+"grant.json")
	if grant_id.is_empty() or grant_sha.length()!=64 or FileAccess.get_sha256(directory+"grant.json")!=grant_sha or grant.get("grantId")!=grant_id or not grant.get("authorized",false) or not group_id in grant.get("groups",[]): finish("explicit_grant_required",true,2); return
	var index: int = config.order.find(group_id)
	var group: Dictionary = config.groups[group_id]
	receipt.unrun = group.trials.size() if group_id!="controls" else Controls.cases().size()*2
	if index>0:
		var previous := read_json(directory+str(config.order[index-1])+"-result.json")
		if previous.is_empty() or previous.get("sourceSha256")!=receipt.sourceSha256 or previous.get("grantId")!=grant_id or previous.get("grantReceiptSha256")!=grant_sha: finish("missing_or_unbound_predecessor",true,2); return
		if index==2:
			if not continuation or not grant.get("continueAfterKnownBaselineFailure",false) or not previous.get("referenceExpected",false) or not previous.get("failed",false): finish("known_reference_failure_requires_explicit_continuation",true,2); return
		elif previous.get("failed",true): finish("predecessor_failed",true,2); return
	if index>=2:
		var reference := read_json(directory+str(config.order[1])+"-result.json")
		if not continuation or not grant.get("continueAfterKnownBaselineFailure",false) or not reference.get("referenceExpected",false): finish("reference_continuation_not_authorized",true,2); return
		if index>2:
			var first_candidate := read_json(directory+str(config.order[2])+"-result.json")
			if first_candidate.get("failed",true) or first_candidate.get("passed",0)!=10: finish("candidate_baseline_not_fixed",true,2); return
	if group_id=="controls": await run_controls(); return
	var bound := Binding.make_world(root,directory,config,str(group.variant))
	if not bound.receipt.bindingReady or not bound.receipt.bothVariantsRuntimeVerified: finish("art_binding_failed",true,2); return
	receipt.binding = bound.receipt
	write(directory+group_id+"-binding.json",{"binding":bound.receipt,"clock":clock(),"sourceSha256":receipt.sourceSha256})
	await physics_frame
	for trial: Dictionary in group.trials:
		var body := walker(not group.referenceOnly,float(group.radius))
		root.add_child(body)
		body.set_physics_process(false)
		body.set_spawn(Vector3(trial.start[0],trial.start[1],trial.start[2])+Vector3.UP*.05)
		var row := {"trial":trial,"profile":group.profile,"parameters":parameters(body),"settle":[],"frames":[],"reached":false,"stalled":0}
		receipt.records.append(row);receipt.attempted += 1;receipt.unrun -= 1
		for settle in range(20):
			await physics_frame
			if not require_clock(body): finish("physics_clock",true,2); return
			row.settle.append(step_record(body,Vector2.ZERO))
			if body.reset_count!=1 or (body is Candidate and not (body as Candidate).candidate_fault.is_empty()): receipt.failedTrials += 1; finish("settle_fault",true,1); return
		var goal := Vector3(trial.goal[0],trial.goal[1],trial.goal[2])
		var last_frame := -1
		for frame in range(900):
			await physics_frame
			if not require_clock(body) or (last_frame>=0 and Engine.get_physics_frames()!=last_frame+1): finish("nonconsecutive_physics",true,2); return
			last_frame = Engine.get_physics_frames()
			var delta := goal-body.global_position
			if Vector2(delta.x,delta.z).length()<.15 and absf(delta.y)<=body.safe_margin+.001 and body.is_on_floor(): row.reached = true; break
			var sample := step_record(body,Vector2(delta.x,-delta.z).normalized())
			row.frames.append(sample)
			if not body.global_position.is_finite() or body.reset_count!=1 or not sample.candidateFault.is_empty(): receipt.failedTrials += 1; finish("candidate_proof_or_reset_fault",true,1); return
			row.stalled = int(row.stalled)+1 if sample.wholeFrameDelta.length()<.0001 else 0
			if row.stalled>=120: break
		if row.reached: receipt.passed += 1
		else:
			receipt.failedTrials += 1
			if not group.referenceOnly: finish("experimental_stall_or_no_landing",true,1); return
			if not reference_stall(row): finish("unexpected_reference_failure",true,1); return
		body.queue_free()
		await process_frame
	if group.referenceOnly:
		receipt.referenceExpected = receipt.passed==5 and receipt.failedTrials==5 and reference_directions()
		finish("known_reference_failure" if receipt.referenceExpected else "unexpected_reference_outcome",true,1)
	else: finish("experimental_group_pass",false,0)

func reference_stall(row: Dictionary) -> bool:
	if row.trial.goal[2]<=row.trial.start[2] or row.stalled!=120 or row.frames.is_empty(): return false
	var last: Dictionary = row.frames[-1]
	var expected := Vector3(row.trial.start[0],12.0166673660278,24.7000026702881)
	if last.after.distance_to(expected)>.0001 or not last.groundedAfter: return false
	if last.collisions.is_empty(): return false
	for collision: Dictionary in last.collisions:
		if collision.collider!="civic-stair-0Collider": return false
	return true

func reference_directions() -> bool:
	for row: Dictionary in receipt.records:
		if row.reached != (row.trial.goal[2]<row.trial.start[2]): return false
	return true

func run_controls() -> void:
	for id: String in Controls.cases():
		for radius: float in [.35,.42]:
			var pair: Array = []
			var row := {"id":id,"radius":radius,"profiles":pair,"passed":false}
			receipt.records.append(row);receipt.attempted += 1;receipt.unrun -= 1
			for experimental: bool in [false,true]:
				var fixture := Controls.scene(id)
				var world: Node3D = fixture.world
				root.add_child(world)
				var parent := Node3D.new()
				world.add_child(parent)
				var body := walker(experimental,radius)
				parent.add_child(body);body.set_physics_process(false)
				var z := -.32-(radius-.35)*.6
				body.set_spawn(Vector3(0,1.0 if id=="airborne" else .05,z))
				var profile := {"experimental":experimental,"parameters":parameters(body),"settle":[],"observer":{},"response":{}}
				pair.append(profile)
				for settle in range(1 if id=="airborne" else 20):
					await physics_frame
					if not require_clock(body): finish("control_clock",true,2); return
					profile.settle.append(step_record(body,Vector2.ZERO))
				if id=="jumping":
					await physics_frame
					profile.launch = step_record(body,Vector2.ZERO,true)
				if id=="tilted-body": body.rotation.z = .1
				if id=="transformed-parent": parent.position.x = .2
				await physics_frame
				if not require_clock(body): finish("control_clock",true,2); return
				var input := Vector2.ZERO if id=="no-input" else Vector2(1,-1).normalized() if id=="lateral" else Vector2(0,-1)
				if not experimental:
					var before := body.global_transform
					var velocity := body.velocity
					profile.observer = Proposal.propose(body,1.0/60.0,input,false,false)
					if body.global_transform!=before or body.velocity!=velocity: receipt.failedTrials += 1; finish("query_mutated_body",true,1); return
				profile.response = step_record(body,input)
				var plan: Dictionary = profile.response.proposal if experimental else profile.observer
				if plan.accepted or not plan.reason in fixture.reasons or not profile.response.candidateFault.is_empty() or body.reset_count!=1:
					receipt.failedTrials += 1; finish("unexpected_control_result",true,1); return
				world.queue_free()
				await process_frame
			var a: Dictionary = pair[0].response
			var b: Dictionary = pair[1].response
			var epsilon := Response.numeric_budget([a.after,b.after])
			if epsilon<0.0 or a.after.distance_to(b.after)>epsilon or a.velocity.distance_to(b.velocity)>epsilon or a.groundedAfter!=b.groundedAfter:
				receipt.failedTrials += 1; finish("rejected_candidate_changed_ordinary_response",true,1); return
			row.passed = true;receipt.passed += 1
	finish("native_rejection_controls_pass",false,0)
