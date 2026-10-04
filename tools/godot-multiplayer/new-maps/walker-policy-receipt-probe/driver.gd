extends SceneTree
## Diagnostic-only entrypoint. No scene/body/controller, movement or physics API.
const Original = preload("res://tests/walker_parity_admission/policy.gd")
const Corrected = preload("cloned_policy.gd")
const Evidence = preload("res://tests/walker_parity_admission/evidence.gd")
const Diagnostic = preload("diagnostic.gd")
const PHASE := "policy-receipt-probe-v1"
const MODE := "frozen-receipt"
const GROUP := "numeric-membership"
const ENGINE := "5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae"
const RECEIPT := "708fda878f694b46c0ae1968aca653a206ac7b39e9f3af61e0807154cf2922f4"
const AI_SOURCE := "59b3d7fefd040fc006f6c8d2067ae35f56d583d2a603a14534d726b5b6cf088d"
const AI_GRANT := "3750e6dba14af411547f9880343bb72813ea5b35275d7e4db4c7737866e561f5"
const POLICY := "6fab2f142b3b849b3902a506a54c95d31f19a7dfecbab0202acb1896572f757f"
const EVIDENCE := "acbab472c5042bbe5d3d996fe45e9d71f1114dd24bc8f6316ba891bbaacdb96f"
const DIAGNOSTIC := "0a73ac7874798181bfa47bcb9e99509552391577f22b60fffcc60a71eb868bab"
const AI_MANIFEST := "e9f57119b10ac400430573e59253d78e714832743855094013ecba57797abd96"
const FILES := ["tests/walker_parity_admission/evidence.gd","tests/walker_parity_admission/policy.gd","probe/cloned_evidence.gd","probe/cloned_policy.gd","probe/diagnostic.gd","probe/driver.gd","project.godot"]
var args: Dictionary = {}
var started: int
var ended := false

func _initialize() -> void:
	started = Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		var pair := arg.split("=",true,1)
		if pair.size()!=2 or not pair[0] in ["--group","--mode","--grant-id","--grant-sha256"] or args.has(pair[0]): fail("args");return
		args[pair[0]] = pair[1]
	if args.size()!=4 or args["--group"]!=GROUP or args["--mode"]!=MODE: fail("scope");return
	call_deferred("run")

func fail(code: String) -> void:
	if not ended:
		ended = true
		printerr("PROBE_FAILURE "+JSON.stringify({"schema":PHASE,"code":code,"probeCollected":false}))
	quit(2)

func within_deadline() -> bool:
	if Time.get_ticks_msec()-started>=170000: fail("internal_timeout");return false
	return not ended

func read_object(path: String) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}

func corrected_result(r: Dictionary, source_hash: String = AI_SOURCE) -> bool:
	return Corrected.successful(r,"negative-controls",source_hash,AI_GRANT,ENGINE)

func run() -> void:
	var source_hash := FileAccess.get_sha256("res://source.json")
	var grant_hash := FileAccess.get_sha256("res://grant.json")
	var engine_hash := FileAccess.get_sha256(OS.get_executable_path())
	var g := read_object("res://grant.json");var s := read_object("res://source.json")
	if not Original.hash_valid(source_hash) or grant_hash!=args["--grant-sha256"] or engine_hash!=ENGINE: fail("hash");return
	var keys := ["phase","mode","allowedGroups","grantId","authorized","expiresUnix","sourceSha256","engineSha256"]
	if g.size()!=keys.size(): fail("grant_schema");return
	for k: String in keys:
		if not g.has(k): fail("grant_schema");return
	if g.phase!=PHASE or g.mode!=MODE or g.allowedGroups!=[GROUP] or not Evidence.flag(g.authorized,true) or not g.grantId is String or g.grantId.is_empty() or g.grantId!=args["--grant-id"]: fail("grant_scope");return
	if not Evidence.num(g.expiresUnix) or g.expiresUnix<=Time.get_unix_time_from_system() or g.sourceSha256!=source_hash or g.engineSha256!=ENGINE: fail("grant_binding");return
	if s.size()!=8 or s.get("phase")!=PHASE or s.get("mode")!=MODE or s.get("group")!=GROUP or s.get("namespace")!=ProjectSettings.globalize_path("res://").trim_suffix("/").get_file() or s.get("receiptSha256")!=RECEIPT or s.get("AIManifestSha256")!=AI_MANIFEST or not Original.hash_valid(s.get("hostPinsSha256")) or not s.get("files") is Dictionary or s.files.size()!=FILES.size(): fail("source_schema");return
	for name: String in FILES:
		if not Original.hash_valid(s.files.get(name)) or FileAccess.get_sha256("res://"+name)!=s.files[name]: fail("source_file");return
	if FileAccess.get_sha256("res://tests/walker_parity_admission/policy.gd")!=POLICY or FileAccess.get_sha256("res://tests/walker_parity_admission/evidence.gd")!=EVIDENCE or FileAccess.get_sha256("res://probe/diagnostic.gd")!=DIAGNOSTIC or FileAccess.get_sha256("res://frozen-negative.json")!=RECEIPT: fail("frozen_pin");return
	var version := Engine.get_version_info()
	if version.major!=4 or version.minor!=5 or version.patch!=2: fail("engine_version");return
	var r := read_object("res://frozen-negative.json")
	if r.is_empty(): fail("receipt_schema");return
	var original: bool = Original.successful(r,"negative-controls",AI_SOURCE,AI_GRANT,ENGINE)
	if not within_deadline(): return
	var corrected: bool = corrected_result(r)
	if not within_deadline(): return
	var diagnostic: Dictionary = Diagnostic.inspect_failed_negative(r,AI_SOURCE,AI_GRANT,ENGINE)
	var names := ["int0","int1","json0","json1","minus1","two","half","false","true","string0","string1","null","nan","inf","minus_inf"]
	var values: Array = [0,1,JSON.parse_string("0"),JSON.parse_string("1"),-1,2,.5,false,true,"0","1",null,NAN,INF,-INF]
	var types := [TYPE_INT,TYPE_INT,TYPE_FLOAT,TYPE_FLOAT,TYPE_INT,TYPE_INT,TYPE_FLOAT,TYPE_BOOL,TYPE_BOOL,TYPE_STRING,TYPE_STRING,TYPE_NIL,TYPE_FLOAT,TYPE_FLOAT,TYPE_FLOAT]
	var controls: Array = [];var agreement := true
	for i in values.size():
		var v: Variant = values[i]
		var integer_guard: bool = Evidence.integer(v)
		var membership: bool = v in [0,1]
		var numeric: bool = integer_guard and not (v != 0 and v != 1)
		controls.append({"name":names[i],"type":typeof(v),"integerGuard":integer_guard,"originalMembership":membership,"numericDomain":numeric})
		agreement = agreement and typeof(v)==types[i] and integer_guard==(i<6) and membership==(i<2) and numeric==(i<4)
	var count := 0;var membership_failures := 0
	for case: Dictionary in r.records:
		var profile: Dictionary = case.profiles[1]
		for row: Dictionary in profile.settle+profile.frames:
			count += 1
			if not row.appliedUpCount in [0,1]: membership_failures += 1
	var mutant_names := ["minus1","half","false","missing_record","duplicate_case","wrong_hash","wrong_outcome"]
	var mutants: Array = [];var mutants_pass := true
	for name: String in mutant_names:
		if not within_deadline(): return
		var m: Dictionary = r.duplicate(true)
		if name=="minus1": m.records[0].profiles[1].settle[0].appliedUpCount = -1
		elif name=="half": m.records[0].profiles[1].settle[0].appliedUpCount = .5
		elif name=="false": m.records[0].profiles[1].settle[0].appliedUpCount = false
		elif name=="missing_record": m.records.pop_back()
		elif name=="duplicate_case": m.records[1] = m.records[0].duplicate(true)
		elif name=="wrong_outcome": m.outcome = "invalid"
		var outcome: bool = corrected_result(m,"0".repeat(64) if name=="wrong_hash" else AI_SOURCE)
		mutants.append({"name":name,"correctedPolicyResult":outcome})
		mutants_pass = mutants_pass and not outcome
	if not within_deadline(): return
	var result := {"phase":PHASE,"mode":MODE,"group":GROUP,"sourceSha256":source_hash,"grantSha256":grant_hash,"engineSha256":engine_hash,"receiptSha256":RECEIPT,"originalSourceSha256":AI_SOURCE,"originalGrantSha256":AI_GRANT,"originalPolicySha256":POLICY,"originalEvidenceSha256":EVIDENCE,"clonePolicySha256":s.files["probe/cloned_policy.gd"],"cloneEvidenceSha256":s.files["probe/cloned_evidence.gd"],"probeCollected":true,"originalPolicyResult":original,"correctedPolicyResult":corrected,"controls":controls,"mutants":mutants,"candidateRecords":count,"membershipFailures":membership_failures,"variantAgreementPass":agreement,"mutantRejectionsPass":mutants_pass,"hypothesisConfirmed":not original and corrected and agreement and mutants_pass and count==678 and membership_failures==678,"diagnostic":diagnostic,"positiveAdmission":false,"nativeStepAdmission":false,"productionPromotion":false,"candidateMapWalks":0}
	var text := JSON.stringify(result,"",true,true)
	if text.to_utf8_buffer().size()>8192: fail("output_bound");return
	ended = true
	printerr("PROBE_RESULT "+text)
	quit(0)
