extends SceneTree
const Walker = preload("res://exploration/walker.gd")
const Fixture = preload("fixture.gd")
const Observe = preload("observe.gd")
const Policy = preload("policy.gd")
const FILES := ["res://exploration/walker.gd","res://ui/settings_access.gd","res://ui/mouse_motion.gd","res://tests/walker_baseline_characterization/fixture.gd","res://tests/walker_baseline_characterization/observe.gd","res://tests/walker_baseline_characterization/policy.gd","res://tests/walker_baseline_characterization/driver.gd","res://project.godot"]
var args := {}
var done := false
var ready := false
var current := -1
var previous := {}
var receipt := {"phase":Policy.PHASE,"mode":Policy.MODE,"group":Policy.GROUP,"failed":true,"completedCharacterization":false,"candidateAdmission":false,"nativeStepAdmission":false,"productionPromotion":false,"selectionQualified":false,"selectedHeight":null,"candidateMapWalks":0,"physicalCallCounts":null,"parentInternalCallsTraced":false,"backendImplementationVerified":false,"attemptedProfiles":0,"completedProfiles":0,"unrunProfiles":8,"settleResponses":0,"inputResponses":0,"referenceAgreement":false,"records":[]}
static func read_json(path: String) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return raw if raw is Dictionary else {}
func gate(code: String) -> void:
	printerr("ADMISSION_FAILURE "+JSON.stringify({"schema":"baseline-characterization-gate-v1","code":code,"phase":Policy.PHASE,"nativeCountersKnown":false,"physicalCallCounts":null}));done = true;quit(2)
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var k := arg.get_slice("=",0)
		if not "=" in arg or args.has(k) or not k in ["--group","--mode","--grant-id","--grant-sha256","--dependencies-sha256"]: gate("args.schema");return
		args[k] = arg.substr(k.length()+1)
	if args.size()!=5 or args["--group"]!=Policy.GROUP or args["--mode"]!=Policy.MODE: gate("args.scope");return
	if FileAccess.file_exists("res://radius-rise-result.json"): gate("output.exists");return
	call_deferred("run")
func finish(code: String = "") -> void:
	if done: return
	done = true
	receipt.finishedUnix = Time.get_unix_time_from_system()
	if not code.is_empty():
		receipt.outcome = "fault";receipt.faultCode = code
		if current>=0 and receipt.records[current].status=="running": receipt.records[current].status = "fault";receipt.records[current].outcome = "fault"
		for p: Dictionary in receipt.records:
			if p.status=="unrun": p.status = "unrun_after_fault";p.outcome = "unrun_after_fault"
	else:
		receipt.outcome = "collection_complete";receipt.completedCharacterization = true;receipt.failed = false
		receipt.referenceAgreement = receipt.records[0].outcome=="blocked_with_target_witness" and receipt.records[1].outcome=="blocked_with_target_witness" and receipt.records[2].outcome=="arrived"
		if not Policy.successful(Observe.encode(receipt),receipt.sourceSha256,receipt.grantSha256,receipt.engineSha256):
			receipt.outcome = "fault";receipt.faultCode = "receipt_validation";receipt.failed = true;receipt.completedCharacterization = false
	var file := FileAccess.open("res://radius-rise-result.json",FileAccess.WRITE)
	if file==null: gate("output.write");return
	file.store_string(JSON.stringify(Observe.encode(receipt))+"\n");file.close()
	quit(1 if receipt.failed else 0)
func run() -> void:
	var config := read_json("res://source.json");var grant := read_json("res://grant.json")
	var source := FileAccess.get_sha256("res://source.json");var engine := FileAccess.get_sha256(OS.get_executable_path());var gh := FileAccess.get_sha256("res://grant.json")
	if gh!=args["--grant-sha256"] or not Policy.grant_valid(grant,args["--group"],args["--mode"],args["--grant-id"],source,engine,Time.get_unix_time_from_system()): gate("grant.binding");return
	if config.get("phase")!=Policy.PHASE or config.get("mode")!=Policy.MODE or config.get("group")!=Policy.GROUP or config.get("matrix")!=Fixture.cases() or not config.get("files") is Dictionary or config.files.size()!=FILES.size() or config.get("grant")!=null or config.get("autoStart")!=false or config.get("queued")!=false: gate("source.schema");return
	for k: String in ["autoStart","queued","candidateAdmission"]:
		if not config.get(k) is bool or config[k]: gate("source.flags");return
	for path: String in FILES:
		if not config.files.has(path) or FileAccess.get_sha256(path)!=config.files[path]: gate("source.hash");return
	var lineage := {"AKManifestSha256":Policy.AK,"AKPositiveSha256":Policy.AK_RESULT,"role":"failed-positive-lineage-not-admission"}
	if config.get("lineage")!=lineage: gate("source.lineage");return
	var deps := read_json("res://radius-rise-dependencies.json")
	if FileAccess.get_sha256("res://radius-rise-dependencies.json")!=args["--dependencies-sha256"] or deps!={"phase":Policy.PHASE,"group":Policy.GROUP,"sourceSha256":source,"grantSha256":gh,"engineSha256":engine,"lineage":lineage,"predecessors":{}}: gate("dependencies.binding");return
	receipt.merge({"sourceSha256":source,"grantSha256":gh,"engineSha256":engine,"dependenciesSha256":args["--dependencies-sha256"],"lineage":lineage,"startedUnix":Time.get_unix_time_from_system(),"engine":Engine.get_version_info(),"configuredPhysicsEngineSetting":ProjectSettings.get_setting("physics/3d/physics_engine","DEFAULT")})
	for i in 8: receipt.records.append({"caseIndex":i,"spec":Fixture.cases()[i],"experimental":false,"status":"unrun","outcome":"unrun","settle":[],"frames":[],"landingStreak":0,"blockedStreak":0})
	ready = true
	var version := Engine.get_version_info()
	if version.major!=4 or version.minor!=5 or version.patch!=2: finish("parameters");return
	create_timer(170).timeout.connect(func() -> void: finish("internal_timeout"))
	for index in 8:
		if done: return
		current = index;previous = {};var p: Dictionary = receipt.records[index];var s: Dictionary = p.spec
		var f := Fixture.make(root,s);var body := Walker.new();(body.get_child(0).shape as CapsuleShape3D).radius = s.radius
		f.world.add_child(body);body.set_physics_process(false);body.set_process_input(false);body.set_process_unhandled_input(false)
		var start := -Fixture.direction(s);start.y = .05;body.set_spawn(start,deg_to_rad(s.yawDegrees))
		p.status = "running";receipt.attemptedProfiles += 1;receipt.unrunProfiles -= 1
		p.parameters = Observe.encode(Observe.parameters(body));p.geometry = Observe.encode(Fixture.certificate(f))
		if not Policy.parameters(p.parameters,s): finish("parameters");return
		if not Policy.geometry(p.geometry,s): finish("geometry");return
		for i in 20:
			await physics_frame
			if done: return
			var checked := sample(body,p,false)
			if done: return
			if i==19 and (not body.is_on_floor() or not checked.base): finish("not_settled");return
		for i in 240:
			await physics_frame
			if done: return
			var checked := sample(body,p,true)
			if done: return
			p.landingStreak = p.landingStreak+1 if checked.landing else 0;p.blockedStreak = p.blockedStreak+1 if checked.blocked else 0
			if p.landingStreak>=3 and checked.along>=1: p.outcome = "arrived";break
			if p.blockedStreak>=120: p.outcome = "blocked_with_target_witness";break
		if p.outcome=="unrun": p.outcome = "unresolved_at_cap"
		p.status = "completed"
		if Policy.profile(p,index).is_empty(): p.status = "running";finish("receipt_validation");return
		receipt.completedProfiles += 1;f.world.queue_free();await process_frame
	finish()
func sample(body: Walker,p: Dictionary,moving: bool) -> Dictionary:
	var before := Observe.state(body);var input := Vector2(0,-1) if moving else Vector2.ZERO
	var r := {"frame":Engine.get_physics_frames(),"usec":Time.get_ticks_usec(),"delta":body.get_physics_process_delta_time(),"physicsHz":Engine.physics_ticks_per_second,"timeScale":Engine.time_scale,"inPhysicsFrame":Engine.is_in_physics_frame(),"parameters":Observe.parameters(body),"before":before,"input":input,"jump":false,"sprint":false,"returned":false,"parentCalls":0}
	p.inflight = Observe.encode(r)
	r.requestedMotion = body.basis*Vector3(0,0,.1) if moving else Vector3.ZERO
	if not r.inPhysicsFrame or r.physicsHz!=60 or r.timeScale!=1.0 or absf(r.delta-1.0/60.0)>.00000001 or (not previous.is_empty() and (r.frame!=previous.frame+1 or r.usec<=previous.usec)): finish("clock");return {}
	if not Policy.parameters(Observe.encode(r.parameters),p.spec) or Observe.encode(r.parameters)!=p.parameters: finish("parameters");return {}
	if not previous.is_empty() and Observe.encode(before)!=previous.after: finish("state");return {}
	body.step(1.0/60.0,input,false,false)
	r.returned = true;r.parentCalls = 1;r.after = Observe.state(body);r.wholeDelta = body.global_position-before.transform.origin;r.slides = Observe.slides(body);r.support = Observe.support(body)
	var encoded: Dictionary = Observe.encode(r)
	if moving: p.frames.append(encoded);receipt.inputResponses += 1
	else: p.settle.append(encoded);receipt.settleResponses += 1
	p.erase("inflight")
	if encoded.support.before!=encoded.support.after: finish("query_mutation");return {}
	var checked := Policy.row(encoded,p.parameters,p.geometry,p.spec,moving)
	if checked.is_empty(): finish("state");return {}
	previous = encoded
	return checked
