extends SceneTree
## F05: one presentation profile per source weapon.
##
## Presentation only; no aim, spread, ammo, damage or reload value is asserted or
## written. Proves three things: the Pulse Rifle profile reproduces the current
## procedural response *exactly* (same numbers, same composed result), the shared
## profile is immutable at *every* nesting depth while every rig keeps its own
## runtime state, and two rigs that share one profile never share a pose.
## Immutability is proved twice over: structurally, that every container the
## profile hands out is engine-read-only, and behaviourally, by an isolated child
## process that performs the nested in-place writes and reports that none stuck.
const Rig = preload("res://first_person/rig.gd")
const Profile = preload("res://first_person/profiles/weapon_presentation_profile.gd")
const Handling = preload("res://first_person/handling.gd")
const Inertia = preload("res://first_person/inertia.gd")
const SprintFov = preload("res://first_person/sprint_fov.gd")
const Catalog = preload("res://first_person/generated/catalog.gd")
const Spring = preload("res://animation/critical_spring.gd")
## Every exported table the profile freezes. `weapon_id`/`source_index` are
## scalars, so they are covered by the setter checks alone.
const FROZEN_GROUPS: Array[String] = ["pose", "recoil", "springs", "impulses", "handling", "optics", "clips", "grammar", "audio"]
## Result line of the isolated nested-write probe; the parent never prints the
## child's stdout, which is where Godot's read-only ERROR text lands.
const INTRUDER_MARKER := "FIRST_PERSON_PROFILE_INTRUDER "
## How many nested in-place writes `run_intruder()` must actually attempt. The
## child counts its own attempts, so adding one here fails the gate until the
## child really tries it.
const INTRUDER_ATTEMPTS := 18
var failures: Array[String] = []
var checks := 0
var measured: Array[Dictionary] = []
var volley := 0

func _initialize() -> void:
	# `--intruder` re-runs this same gate as an isolated negative control.
	if "--intruder" in OS.get_cmdline_user_args(): run_intruder()
	else: call_deferred("run")

## Asserts `value` and every Dictionary/Array reachable from it is read-only, so
## the sweep proves the freeze reaches every nesting depth instead of sampling one
## level. Scalars are values, not containers, and are skipped.
func check_frozen_table(label: String, value: Variant) -> void:
	if value is Dictionary:
		var table: Dictionary = value
		check(table.is_read_only(), "%s is read-only" % label)
		for field: Variant in table: check_frozen_table("%s.%s" % [label, field], table[field])
	elif value is Array:
		var list: Array = value
		check(list.is_read_only(), "%s is read-only" % label)
		for index: int in list.size(): check_frozen_table("%s[%d]" % [label, index], list[index])

## --- Isolated nested-write probe --------------------------------------------
## Godot refuses a write to a read-only container by printing an engine ERROR and
## aborting the writing function, so these attempts cannot live in the gate's own
## process: `tools/godot-dev/gate_runner.py` fails any gate whose log carries an
## `ERROR:`/`SCRIPT ERROR:` line. Each attempt therefore gets its own function,
## because a refusal aborts exactly one frame of it, and the child's output is
## captured rather than printed.

## One nested in-place write. Returns true only if the write actually landed; a
## refused `table[field] = value` aborts this function before the return, so the
## caller's `landed` list can only ever record writes that stuck. Every attempt is
## counted through `attempts`, so the reported total cannot drift from what was
## actually tried.
static func intruder_put(attempts: Array, table: Dictionary, field: String, value: Variant) -> bool:
	attempts.append(field)
	table[field] = value
	return true

## `erase`/`merge` are refused differently: the engine logs and no-ops, so the
## GDScript frame is *not* aborted and the next statement still runs. Detecting
## them by return value would therefore be vacuous, so they report whether the
## container actually changed.
static func intruder_erase(attempts: Array, table: Dictionary, field: String) -> bool:
	attempts.append("erase:" + field)
	var had: bool = table.has(field)
	table.erase(field)
	return had != table.has(field)

static func intruder_merge(attempts: Array, table: Dictionary, extra: String) -> bool:
	attempts.append("merge:" + extra)
	var before: int = table.size()
	table.merge({extra: "hacked"}, true)
	return table.size() != before

## A structural fingerprint of a value: containers render their keys/items and
## scalars render themselves, sorted, so *any* edit at any depth changes the
## string. This is what proves a refused write left the table untouched.
static func intruder_fingerprint(value: Variant) -> String:
	if value is Dictionary:
		var fields: Array[String] = []
		for field: Variant in value: fields.append("%s=%s" % [str(field), intruder_fingerprint(value[field])])
		fields.sort()
		return "{%s}" % ",".join(PackedStringArray(fields))
	if value is Array:
		var items: Array[String] = []
		for item: Variant in value: items.append(intruder_fingerprint(item))
		return "[%s]" % ",".join(PackedStringArray(items))
	return str(value)

## The values a consumer actually reads, plus a fingerprint of every exported
## table, so the probe can prove the refused writes moved none of them. Compared
## in-process, so no float round-trips through JSON.
static func intruder_snapshot(profile) -> Dictionary:
	var snapshot := {}
	for group: String in FROZEN_GROUPS:
		snapshot["shape.%s" % group] = intruder_fingerprint(profile.get(group))
	snapshot["hip_offset"] = str(profile.hip_offset())
	snapshot["sight_rear"] = String(profile.sight_corridor().get("rear", ""))
	snapshot["lateral_roll"] = float((profile.impulse("lateral") as Dictionary).get("roll", 0.0))
	snapshot["land_max"] = float((profile.impulse("vertical") as Dictionary).get("land_max", 0.0))
	snapshot["look_gain"] = float((profile.impulse("look_y") as Dictionary).get("gain", 0.0))
	snapshot["heft_high"] = profile.recoil_heft_high()
	snapshot["scale"] = profile.recoil_scale([0.045, 0.03, 16.0])
	snapshot["lateral_limit"] = float((profile.spring("lateral") as Dictionary).get("limit", 0.0))
	snapshot["look_y_omega"] = float((profile.spring("look_y") as Dictionary).get("omega", 0.0))
	snapshot["fov_degrees"] = profile.sprint_fov_degrees()
	snapshot["charge_time"] = profile.charge_time()
	snapshot["reload_clip"] = profile.clip("reload")
	snapshot["report_cue"] = profile.report_cue()
	return snapshot

static func intruder_changed(before: Dictionary, profile) -> Array[String]:
	var moved: Array[String] = []
	var after := intruder_snapshot(profile)
	for field: String in before:
		if after.get(field) != before.get(field): moved.append(field)
	return moved

func run_intruder() -> void:
	var profile: Profile = Profile.for_weapon(0)
	var before := intruder_snapshot(profile)
	var landed: Array[String] = []
	var attempts: Array[String] = []
	# Exactly the in-place writes a consumer could make, at the top level, through
	# a property, through a method-returned sub-table and one level deeper still.
	if intruder_put(attempts, profile.pose, "hip_offset", Vector3(9.0, 9.0, 9.0)): landed.append("pose.hip_offset")
	if intruder_put(attempts, profile.pose, "brand_new", 1.0): landed.append("pose.brand_new")
	if intruder_put(attempts, profile.sight_corridor(), "rear", "Hacked"): landed.append("pose.sight_corridor.rear")
	if intruder_put(attempts, profile.impulses, "brand_new", {}): landed.append("impulses.brand_new")
	if intruder_put(attempts, profile.impulses["lateral"] as Dictionary, "roll", 99.0): landed.append("impulses.lateral.roll")
	if intruder_put(attempts, profile.impulse("vertical") as Dictionary, "land_max", 99.0): landed.append("impulse(vertical).land_max")
	if intruder_put(attempts, profile.recoil, "heft_high", 9.0): landed.append("recoil.heft_high")
	if intruder_put(attempts, profile.recoil, "scale_low", 9.0): landed.append("recoil.scale_low")
	if intruder_put(attempts, profile.springs, "brand_new", {}): landed.append("springs.brand_new")
	if intruder_put(attempts, profile.springs["lateral"] as Dictionary, "limit", 99.0): landed.append("springs.lateral.limit")
	if intruder_put(attempts, profile.spring("look_y") as Dictionary, "omega", 99.0): landed.append("spring(look_y).omega")
	if intruder_put(attempts, profile.optics, "sprint_fov_degrees", 99.0): landed.append("optics.sprint_fov_degrees")
	if intruder_put(attempts, profile.handling, "charge_time", 99.0): landed.append("handling.charge_time")
	if intruder_put(attempts, profile.clips, "reload", "hacked"): landed.append("clips.reload")
	if intruder_put(attempts, profile.grammar, "impact_visual", "hacked"): landed.append("grammar.impact_visual")
	if intruder_put(attempts, profile.audio, "report", "hacked"): landed.append("audio.report")
	if intruder_erase(attempts, profile.pose, "hip_offset"): landed.append("pose.erase")
	if intruder_merge(attempts, profile.clips, "hacked"): landed.append("clips.merge")
	var changed := intruder_changed(before, profile)
	print(INTRUDER_MARKER, JSON.stringify({"landed":landed,"changed":changed,"attempts":attempts.size(),"frozen_fields":before.size()}))
	quit(0 if landed.is_empty() and changed.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func fire(rig: Node, weapon: int) -> void:
	volley += 1
	rig.apply_events([{"id":900000 + volley, "time":9000.0 + volley, "type":"shot", "actor":7, "weapon":weapon}], 7)

func rig_for(camera: Camera3D) -> Node:
	var rig := Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	return rig

func run() -> void:
	# 1. Stable source identity. The key is the source weapon name and its
	#    `game/data.mjs` WEAPONS order index; the Pulse Rifle is index 0.
	var names: Array[String] = Profile.ids()
	check(names.size() == 10 and String(Catalog.WEAPONS[0].name) == "Pulse Rifle", "Pulse Rifle is source weapon 0")
	for id: int in names.size():
		var entry: Dictionary = Catalog.WEAPONS[id]
		check(names[id] == String(entry.name), "profile key %d matches the source weapon name" % id)
		check(Profile.for_weapon(names[id]) == Profile.for_weapon(id), "name and index resolve to one shared profile %d" % id)
		check(Profile.for_weapon(id).source_index == id, "profile carries the source order index %d" % id)
		check(Profile.has_weapon(id), "source weapon %d has a profile" % id)
	var pulse := Profile.for_weapon(0)
	check(pulse.weapon_id == "Pulse Rifle" and pulse.source_index == 0, "Pulse Rifle profile is keyed by the stable source id")
	check(pulse.clip("reload") == "mechanism/reload_hardware", "Pulse Rifle authors the sampled reload clip")
	check(pulse.clip("switch").is_empty() and pulse.clip("pump").is_empty(), "Pulse Rifle keeps switch/pump procedural")
	# 2. Unknown ids resolve to the documented default: current behaviour.
	var fallback := Profile.default_for_weapon()
	for unknown: Variant in ["", "nope", "pulse rifle", "Pulse Rifle!", 99, -1, 1.5, INF, NAN, null, Vector2.ONE, {}]:
		check(Profile.for_weapon(unknown) == fallback, "unknown id resolves to the default: %s" % str(unknown))
	check(Profile.for_weapon("  Pulse Rifle  ") == pulse, "surrounding whitespace in a source name is tolerated")
	check(fallback.weapon_id.is_empty() and fallback.source_index == -1, "the default profile carries no source identity")
	check(fallback.clip("reload").is_empty(), "the default profile authors no mechanism clip")
	# 3. Parity: the authored numbers are the ones the helpers used before, and
	#    the rig composes exactly those numbers. Compared with `==`, not a
	#    tolerance, because parity here means bit-for-bit.
	var fallback_profile := fallback
	for id: int in 10:
		var entry: Dictionary = Catalog.WEAPONS[id]
		var kick: Array = entry.kick
		var profile := Profile.for_weapon(id)
		check(profile.recoil_scale(kick) == Handling.recoil_scale(kick), "profile kick scale equals the pre-profile formula %d" % id)
		check(profile.pitch_hold(kick) == Handling.pitch_hold(kick), "profile pitch hold equals the pre-profile formula %d" % id)
		check(profile.recover_rate(kick) == Handling.recover_rate(kick), "profile recover rate equals the pre-profile formula %d" % id)
		check(profile.punch_pitch(kick) == Handling.punch_pitch(kick), "profile punch pitch equals the pre-profile formula %d" % id)
		check(profile.punch_roll(kick) == Handling.punch_roll(kick), "profile punch roll equals the pre-profile formula %d" % id)
		check(profile.punch_back(kick) == Handling.punch_back(kick), "profile punch back equals the pre-profile formula %d" % id)
		check(profile.punch_rate(kick) == Handling.punch_rate(kick), "profile punch rate equals the pre-profile formula %d" % id)
		check(profile.recover_rate(kick) == float(kick[2]) * Handling.RECOIL_RECOVER, "recover rate still derives from the source recover %d" % id)
		check(fallback_profile.heft_weight_for(kick) == lerpf(0.75, 1.25, Handling.recoil_heft(kick)), "heft weight equals the pre-profile formula %d" % id)
	# 4. The rig consumes the profile, and composes exactly its numbers.
	var camera := Camera3D.new()
	root.add_child(camera)
	var rig := rig_for(camera)
	var actor := {"id":7,"weapon":0,"health":100}
	for id: int in 10:
		rig.reset()
		actor.weapon = id
		rig.apply_actor(actor,true)
		var entry: Dictionary = rig.manifest.weapons[id]
		var kick: Array = entry.kick
		var profile: Profile = rig.profile
		check(profile == Profile.for_weapon(id), "rig holds the shared profile for %s" % entry.name)
		check(rig.handling.kick_scale == profile.recoil_scale(kick), "handling consumed the profile scale %d" % id)
		check(rig.handling.lift_hold == profile.pitch_hold(kick), "handling consumed the profile pitch hold %d" % id)
		check(rig.handling.recover_speed == profile.recover_rate(kick), "handling consumed the profile recover rate %d" % id)
		check(rig.handling.transient_pitch == profile.punch_pitch(kick), "handling consumed the profile punch pitch %d" % id)
		check(rig.handling.transient_roll == profile.punch_roll(kick), "handling consumed the profile punch roll %d" % id)
		check(rig.handling.transient_back == profile.punch_back(kick), "handling consumed the profile punch back %d" % id)
		check(rig.handling.transient_rate == profile.punch_rate(kick), "handling consumed the profile punch rate %d" % id)
		check(rig.inertia.spring("lateral") == profile.spring("lateral"), "inertia consumed the profile spring %d" % id)
		check(rig.inertia.spring("vertical") == profile.spring("vertical"), "inertia consumed the profile vertical spring %d" % id)
		var bounds: Dictionary = rig.profile_pose()
		check(bounds.hip_offset == profile.hip_offset(), "the rig composed the profile hip offset %d" % id)
		check(bounds.switch_seconds == profile.switch_seconds() and bounds.switch_drop == profile.switch_drop(), "the rig composed the profile switch bounds %d" % id)
		check(bounds.reload_window == profile.reload_window() and bounds.reload_drop == profile.reload_drop() and bounds.reload_roll == profile.reload_roll(), "the rig composed the profile reload bounds %d" % id)
		check(bounds.shove_scale == profile.shove_scale() and bounds.lift_scale == profile.lift_scale(), "the rig composed the profile recoil bounds %d" % id)
		check(bounds.punch_limit == profile.punch_limit() and bounds.recoil_cap == profile.recoil_cap(), "the rig composed the profile caps %d" % id)
		check(bounds.sight_rear == String(profile.sight_corridor().get("rear", "")), "the rig composed the profile sight corridor %d" % id)
		check(rig.mechanism_clip == profile.clip("reload"), "the rig's pilot reads the profile clip %d" % id)
		measured.append({"weapon":id,"name":entry.name,"kick_scale":rig.handling.kick_scale,
			"lift_hold":rig.handling.lift_hold,"recover_speed":rig.handling.recover_speed,
			"punch_rate":rig.handling.transient_rate,"clip":rig.mechanism_clip})
	# 5. Same procedural result: the composed shove/lift and the transient punch
	#    decay equal what the profile's numbers prescribe, frame by frame.
	actor.weapon = 0
	rig.reset()
	rig.apply_actor(actor,true)
	for i: int in 20: rig.advance(1.0 / 60.0)
	var pulse_profile: Profile = Profile.for_weapon(0)
	var pulse_kick: Array = rig.manifest.weapons[0].kick
	var baseline: Transform3D = rig.pivot.transform
	var reference := Spring.new()
	fire(rig, 0)
	reference.value = rig.punch
	reference.velocity = rig.punch_spring.velocity
	var peak_shove := 0.0
	var peak_lift := 0.0
	var peak_travel := 0.0
	for frame: int in 240:
		rig.advance(1.0 / 240.0)
		var expected_shove: float = rig.recoil * float(pulse_kick[0]) * pulse_profile.shove_scale() * pulse_profile.recoil_scale(pulse_kick) \
			+ rig.punch * float(pulse_kick[0]) * pulse_profile.punch_back(pulse_kick)
		var expected_lift: float = rig.recoil * float(pulse_kick[1]) * pulse_profile.pitch_hold(pulse_kick) * pulse_profile.lift_scale() \
			+ rig.punch * float(pulse_kick[1]) * pulse_profile.punch_pitch(pulse_kick)
		check(rig.kick_shove == expected_shove, "composed shove equals the profile's numbers frame %d" % frame)
		check(rig.kick_lift == expected_lift, "composed lift equals the profile's numbers frame %d" % frame)
		peak_shove = maxf(peak_shove, absf(rig.kick_shove))
		peak_lift = maxf(peak_lift, absf(rig.kick_lift))
		peak_travel = maxf(peak_travel, rig.pivot.transform.origin.distance_to(baseline.origin))
		reference.advance(1.0 / 240.0, 0.0, pulse_profile.punch_rate(pulse_kick) * pulse_profile.punch_rate_scale(), pulse_profile.punch_limit())
		if rig.punch > 0.0:
			check(rig.punch == reference.value, "transient punch decays on the profile's spring frame %d" % frame)
	check(peak_shove > 0.0 and peak_lift > 0.0, "the scripted Pulse Rifle response was non-trivial (%.5f m, %.5f rad)" % [peak_shove, peak_lift])
	check(peak_travel > 0.001, "the scripted response moved the pose (%.5f m)" % peak_travel)
	measured.append({"pulse_peak_shove_m":peak_shove,"pulse_peak_lift_rad":peak_lift,"pulse_peak_travel_m":peak_travel,"punch_after_2s":rig.punch,"recoil_after_2s":rig.recoil})
	# 6. Helpers mirror the profile's documented default instead of authoring a
	#    second copy of the same numbers.
	check(Handling.RECOIL_MIN_SCALE == Profile.RECOIL_SCALE_LOW and Handling.RECOIL_MAX_SCALE == Profile.RECOIL_SCALE_HIGH, "handling mirrors the profile recoil band")
	check(Handling.RECOIL_PITCH_HOLD_MIN == Profile.PITCH_HOLD_LOW and Handling.RECOIL_PITCH_HOLD_MAX == Profile.PITCH_HOLD_HIGH, "handling mirrors the profile pitch band")
	check(Handling.RECOIL_RECOVER == Profile.RECOVER_SCALE, "handling mirrors the profile recover scale")
	check(Handling.PUNCH_RATE_LIGHT == Profile.PUNCH_RATE_LIGHT and Handling.PUNCH_RATE_HEAVY == Profile.PUNCH_RATE_HEAVY, "handling mirrors the profile punch rates")
	check(Handling.KICK_HEFT_LOW == Profile.HEFT_LOW and Handling.KICK_HEFT_HIGH == Profile.HEFT_HIGH, "handling mirrors the profile heft band")
	check(Handling.CHARGE_TIME == fallback.charge_time(), "handling mirrors the profile charge time")
	check(Handling.PUFF_LIFE == fallback.puff_life() and Handling.PUFFS == fallback.puff_pool(), "handling mirrors the profile FX pool")
	check(SprintFov.MAX_DEGREES == fallback.sprint_fov_degrees() and SprintFov.RATE == fallback.sprint_fov_rate(), "sprint cue mirrors the profile optics")
	var cue := SprintFov.new()
	cue.advance(0.5, true, true, false)
	check(absf(cue.compose(75.0, 0.0) - 78.0) < 0.6, "an unbound sprint cue still uses the default degrees")
	cue.bind(Profile.for_weapon(3))
	check(absf(cue.compose(75.0, 0.0) - (75.0 + cue.degrees)) < 0.000001, "binding a profile leaves the settled cue alone")
	cue.reset()
	check(cue.compose(30.0, 1.0) == 30.0, "ADS optics exactly preserve the aim FOV")
	var unbound := Inertia.new()
	check(unbound.spring("lateral") == Profile.default_for_weapon().spring("lateral"), "an unbound inertia helper uses the documented default")
	# 7. The shared resource is immutable: every exported field refuses writes and
	#    counts the refusal, and nothing a caller does can change the numbers.
	#    Refusing a property setter is only half the contract, so the tables the
	#    getters hand out are deep-frozen too and a nested in-place write is
	#    refused by the engine itself.
	var refusals := Profile.rejections()
	for field: String in ["weapon_id","source_index","pose","recoil","springs","impulses","handling","optics","clips","grammar","audio"]:
		match field:
			"weapon_id": pulse.weapon_id = "hacked"
			"source_index": pulse.source_index = 99
			"pose": pulse.pose = {"hip_offset": Vector3(9.0, 9.0, 9.0)}
			"recoil": pulse.recoil = {"scale": 99.0}
			"springs": pulse.springs = {}
			"impulses": pulse.impulses = {}
			"handling": pulse.handling = {}
			"optics": pulse.optics = {}
			"clips": pulse.clips = {"reload": "hacked"}
			"grammar": pulse.grammar = {}
			"audio": pulse.audio = {}
	check(Profile.rejections() - refusals == 11, "every exported field refused the write")
	check(pulse.weapon_id == "Pulse Rifle" and pulse.source_index == 0, "identity survived the refused writes")
	check(pulse.hip_offset() == Vector3(0.29, -0.26, -0.75), "pose survived the refused writes")
	check(pulse.recoil_scale(pulse_kick) == pulse_profile.recoil_scale(pulse_kick), "recoil survived the refused writes")
	check(pulse.clip("reload") == "mechanism/reload_hardware", "the clip reference survived the refused writes")
	fallback.weapon_id = "hacked"
	check(fallback.weapon_id.is_empty(), "the default profile is sealed too")
	check(rig.handling.kick_scale == pulse_profile.recoil_scale(pulse_kick), "a refused write cannot change a bound helper")
	# 7a. The tables are frozen at every nesting depth, not just the setters.
	#     `is_read_only()` is the engine's own refusal flag, so proving it true on
	#     each container proves the in-place write cannot land. An ordinary
	#     dictionary is asserted not read-only first, so this sweep can fail
	#     rather than passing vacuously.
	check(not {"probe": {"x": 1}}.is_read_only(), "an ordinary table is not read-only, so the freeze sweep can fail")
	check(not ({"probe": [[1]]}["probe"][0] as Array).is_read_only(), "an ordinary nested array is not read-only, so the freeze sweep can fail")
	check(pulse.get("pose") == pulse.pose and pulse.get("springs") == pulse.springs, "the dynamic property accessor reads the same frozen table")
	for group: String in FROZEN_GROUPS:
		check_frozen_table("pulse.%s" % group, pulse.get(group))
	for group: String in ["pose", "impulses", "recoil", "springs", "optics"]:
		check_frozen_table("default.%s" % group, fallback.get(group))
	# The accessor sub-tables are the same objects, so prove the ones a consumer
	# reaches through a method rather than a property are frozen as well.
	for channel: String in ["lateral", "forward", "vertical", "sprint", "strafe", "look_x", "look_y"]:
		check_frozen_table("pulse.spring(%s)" % channel, pulse.spring(channel))
	for channel: String in ["lateral", "forward", "vertical", "hurt", "strafe", "sprint", "look_x", "look_y"]:
		check_frozen_table("pulse.impulse(%s)" % channel, pulse.impulse(channel))
	check_frozen_table("pulse.sight_corridor()", pulse.sight_corridor())
	check_frozen_table("pulse.impulse_table()", pulse.impulse_table())
	check_frozen_table("pulse.impact_grammar()", pulse.impact_grammar())
	# 7b. Behavioural proof that the refused writes cannot land. Godot reports a
	#     write to a read-only container as an engine ERROR and aborts the writing
	#     function, so the attempt runs in an isolated child process whose output
	#     is captured rather than printed: this gate's own log must stay free of
	#     engine ERROR lines. The child performs exactly the nested writes a
	#     consumer could make and reports which of them landed.
	var intruder_line := ""
	var output: Array = []
	var intruder_code: int = OS.execute(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/first_person/presentation_profile.gd",
		"--", "--intruder"], output, true)
	for line: String in "\n".join(PackedStringArray(output)).split("\n"):
		if line.begins_with(INTRUDER_MARKER): intruder_line = line.strip_edges()
	check(intruder_code == 0, "the isolated nested-write probe exited cleanly (%d)" % intruder_code)
	check(not intruder_line.is_empty(), "the isolated nested-write probe reported a result")
	var intruder: Variant = JSON.parse_string(intruder_line.trim_prefix(INTRUDER_MARKER).strip_edges()) if not intruder_line.is_empty() else null
	check(intruder is Dictionary, "the isolated nested-write probe reported parseable JSON")
	if intruder is Dictionary:
		check(int((intruder as Dictionary).get("attempts", 0)) == INTRUDER_ATTEMPTS, "the isolated probe attempted all %d nested writes" % INTRUDER_ATTEMPTS)
		check(int((intruder as Dictionary).get("frozen_fields", 0)) > 0, "the isolated probe fingerprinted the exported tables before and after")
		check((intruder as Dictionary).get("landed", []) == [], "no nested write into pose/impulses/recoil/springs/optics landed: %s" % str((intruder as Dictionary).get("landed", [])))
		check((intruder as Dictionary).get("changed", []) == [], "no value a consumer reads moved: %s" % str((intruder as Dictionary).get("changed", [])))
	check(pulse.hip_offset() == Vector3(0.29, -0.26, -0.75), "the child's attempted pose write left the pose intact")
	check(pulse.sight_corridor().get("rear") == "SightRear", "the child's attempted sight-corridor write left the anchors intact")
	check(pulse.impulse("lateral").get("roll") == 0.9, "the child's attempted impulse write left the roll intact")
	check(pulse.recoil_heft_high() == Profile.HEFT_HIGH, "the child's attempted recoil write left the heft band intact")
	check(pulse.spring("lateral").get("limit") == 0.018, "the child's attempted spring write left the limit intact")
	check(pulse.spring("look_y").get("omega") == 22.0, "the child's attempted nested spring write left the omega intact")
	check(pulse.sprint_fov_degrees() == Profile.SPRINT_FOV_DEGREES, "the child's attempted optics write left the sprint cue intact")
	check(pulse.clip("reload") == "mechanism/reload_hardware", "the child's attempted clip write left the pilot reference intact")
	# 8. Two independent instances share one immutable profile and never share a
	#    pose, a recoil value or any other runtime state.
	var other := rig_for(camera)
	rig.reset()
	other.reset()
	rig.apply_actor({"id":7,"weapon":0,"health":100},true)
	other.apply_actor({"id":7,"weapon":0,"health":100},true)
	for i: int in 20: rig.advance(1.0 / 60.0)
	for i: int in 20: other.advance(1.0 / 60.0)
	check(rig.profile == other.profile, "two rigs share one immutable profile")
	check(rig.handling.kick_scale == other.handling.kick_scale, "the shared profile reaches both helpers")
	check(rig.pivot.transform == other.pivot.transform, "identical inputs produce an identical pose")
	fire(rig, 0)
	for i: int in 4: rig.advance(1.0 / 60.0)
	for burst: int in 30:
		other.apply_events([{"id":800000 + burst, "time":8000.0 + burst, "type":"shot", "actor":7, "weapon":0}], 7)
	for i: int in 4: other.advance(1.0 / 60.0)
	check(rig.recoil != other.recoil, "recoil age is per instance")
	check(rig.handling.heat != other.handling.heat, "barrel heat is per instance")
	check(rig.pivot.transform != other.pivot.transform, "the poses diverge")
	rig.apply_actor({"id":7,"weapon":0,"health":100,"reloading":true,"reloadDuration":2.0,"reloadTimer":1.0},true)
	rig.advance(1.0 / 60.0)
	check(rig.get_mechanism_state().armed and not other.get_mechanism_state().armed, "the sampled pilot is per instance")
	check(other.profile == rig.profile, "the shared profile is unchanged by one instance's reload")
	check(rig.pivot.transform != other.pivot.transform, "one instance's reload cannot move the other's pose")
	check(rig.get_mechanism_state().clip == Profile.for_weapon(0).clip("reload"), "the pilot reads its clip from the profile")
	rig.free()
	other.free()
	camera.free()
	print("FIRST_PERSON_PRESENTATION_PROFILE ", JSON.stringify({"checks":checks,"failures":failures,"weapons":measured}))
	quit(0 if failures.is_empty() else 1)
