extends SceneTree
## F05: one presentation profile per source weapon.
##
## Presentation only; no aim, spread, ammo, damage or reload value is asserted or
## written. Proves three things: the Pulse Rifle profile reproduces the current
## procedural response *exactly* (same numbers, same composed result), the shared
## profile is immutable while every rig keeps its own runtime state, and two rigs
## that share one profile never share a pose.
const Rig = preload("res://first_person/rig.gd")
const Profile = preload("res://first_person/profiles/weapon_presentation_profile.gd")
const Handling = preload("res://first_person/handling.gd")
const Inertia = preload("res://first_person/inertia.gd")
const SprintFov = preload("res://first_person/sprint_fov.gd")
const Catalog = preload("res://first_person/generated/catalog.gd")
const Spring = preload("res://animation/critical_spring.gd")
var failures: Array[String] = []
var checks := 0
var measured: Array[Dictionary] = []
var volley := 0

func _initialize() -> void: call_deferred("run")

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