extends SceneTree
## F05: the sampled-animation pilot for the Pulse Rifle reload.
##
## Presentation only. The clip is one disjoint hardware/offset track whose
## playhead is the authoritative reload progress, read-only: it never free-runs,
## never gates, shortens or completes the reload, never touches ammunition or any
## source state, and aim/recoil/inertia keep their own procedural authority.
## Cancellation and RESET ownership are explicit and immediate.
const Rig = preload("res://first_person/rig.gd")
const Profile = preload("res://first_person/profiles/weapon_presentation_profile.gd")
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

func rig_for(camera: Camera3D) -> Node:
	var rig := Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	return rig

## Applies a source snapshot for the rig's held weapon unless the case names one.
func show(rig: Node, extra: Dictionary = {}) -> void:
	var held: int = rig.current_weapon if rig.current_weapon >= 0 else 0
	var actor := {"id":7,"weapon":held,"health":100}
	for field: String in extra: actor[field] = extra[field]
	rig.apply_actor(actor,true)

## Re-enters the authoritative reload window at `progress` of `duration`.
func window(rig: Node, progress: float, duration: float = 2.0) -> void:
	show(rig, {"reloading":true, "reloadDuration":duration, "reloadTimer":duration * (1.0 - progress)})

func fire(rig: Node) -> void:
	volley += 1
	rig.apply_events([{"id":700000 + volley, "time":7000.0 + volley, "type":"shot", "actor":7, "weapon":0}], 7)

func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	var rig := rig_for(camera)
	var pulse: Profile = Profile.for_weapon(0)
	# 1. The pilot is profile-driven and the clip is authored in normalised source
	#    progress, so it cannot outrun, shorten or complete the reload window.
	check(pulse.clip("reload") == "mechanism/reload_hardware", "the Pulse Rifle profile names the reload clip")
	show(rig)
	var clip_name: String = rig.mechanism_clip
	check(clip_name == pulse.clip("reload"), "the rig armed the clip the profile names")
	check(rig.mechanism_player.has_animation(clip_name), "the rig's own library holds the named clip")
	var clip: Animation = rig.mechanism_player.get_animation(clip_name)
	check(clip.length == 1.0 and clip.loop_mode == Animation.LOOP_NONE, "the clip is one normalised, non-looping window")
	check(clip.get_track_count() == 1 and clip.track_get_type(0) == Animation.TYPE_POSITION_3D, "the clip holds exactly one bounded offset track")
	check(clip.track_get_path(0) == NodePath("."), "the track writes the disjoint mechanism node, not the pose pivot")
	check(rig.mechanism_player.speed_scale == 0.0, "the player cannot free-run")
	check(rig.pivot.get_child_count() == 3, "the pivot keeps its three compositor children")
	check(rig.mechanism.get_parent() == rig.weapon, "the sampled node rides the live weapon")
	# 2. Inside the authoritative window the playhead *is* the source progress.
	window(rig, 0.5)
	check(rig.get_mechanism_state().armed, "the source window armed the pilot")
	var peak := 0.0
	for sample: int in 99:
		var progress := 0.01 + 0.98 * float(sample) / 98.0
		window(rig, progress)
		rig.advance(1.0 / 120.0)
		var state: Dictionary = rig.get_mechanism_state()
		check(state.armed, "still armed inside the window at %.3f" % progress)
		check(state.position == state.progress, "the playhead is exactly the source-derived progress at %.3f" % progress)
		check(state.position == rig.reload_progress, "the playhead and the snapshot progress never disagree at %.3f" % progress)
		check(absf(state.progress - progress) < 0.0000001, "the rig's reload progress tracks the source's %.3f" % progress)
		check(not state.playing, "the clip is paused, never self-advancing, at %.3f" % progress)
		peak = maxf(peak, state.offset.length())
	check(peak > 0.01 and peak < 0.1, "the sampled offset stays bounded (%.4f m)" % peak)
	measured.append({"clip":clip_name,"length_s":clip.length,"peak_offset_m":peak,"progress_samples":99})
	# 3. Window edges: the clip is exactly zero at 0.0 and 1.0, so the pose cannot
	# jump when the source opens or closes the window.
	for edge: float in [0.0, 1.0]:
		window(rig, edge)
		rig.advance(1.0 / 120.0)
		var state: Dictionary = rig.get_mechanism_state()
		check(state.offset == Vector3.ZERO, "no sampled offset at the window edge %.1f" % edge)
		check(state.armed == (edge > 0.0 and edge < 1.0), "armed only inside the open window at %.1f" % edge)
	# 4. The clip cannot free-run or drift: idle frames without a source update
	#    leave the playhead exactly where the source put it.
	window(rig, 0.42)
	rig.advance(1.0 / 120.0)
	var held: Dictionary = rig.get_mechanism_state()
	for frame: int in 30:
		await process_frame
	var idle: Dictionary = rig.get_mechanism_state()
	check(idle.position == held.position and idle.position == rig.reload_progress, "thirty idle frames cannot advance the playhead")
	check(idle.offset == held.offset, "thirty idle frames cannot move the sampled offset")
	# 5. The clip samples source timing, whatever the source duration is.
	for duration: float in [0.4, 2.5]:
		window(rig, 0.25, duration)
		rig.advance(1.0 / 120.0)
		var state: Dictionary = rig.get_mechanism_state()
		check(state.position == rig.reload_progress, "a %.1f s source reload maps to the same normalised playhead" % duration)
		check(absf(rig.reload_progress - 0.25) < 0.0000001, "the source still owns the %.1f s window" % duration)
	# A source restart rewinds the clip; it never runs ahead of the source.
	window(rig, 0.8)
	rig.advance(1.0 / 120.0)
	window(rig, 0.1)
	rig.advance(1.0 / 120.0)
	check(rig.get_mechanism_state().position == rig.reload_progress, "a rewound source window rewinds the clip")
	# 6. No source or ammunition state is written by the pilot.
	var actor := {"id":7,"weapon":0,"health":100,"ammo":32,"reloading":true,"reloadDuration":2.0,"reloadTimer":1.0}
	var before := actor.duplicate(true)
	for i: int in 60:
		actor.reloadTimer = 1.0 - 0.03 * float(i)
		rig.apply_actor(actor,true)
		rig.advance(1.0 / 60.0)
	check(actor.keys().size() == before.keys().size(), "the pilot added no source fields")
	for field: String in before: check(actor[field] == before[field] or field == "reloadTimer", "the pilot left the source field %s alone" % field)
	check(before.reloadTimer == 1.0, "the test owned the source timer, not the pilot")
	# 7. Aim, recoil and inertia stay procedural and authoritative inside the window.
	show(rig)
	fire(rig)
	rig.advance(1.0 / 60.0)
	window(rig, 0.35)
	var recoil_before: float = rig.recoil
	rig.advance(1.0 / 60.0)
	check(rig.recoil > 0.0 and rig.recoil < recoil_before, "the sustained recoil channel still settles inside the window")
	check(not rig.apply_aim(true), "the source window still blocks ADS")
	check(rig.handling.magazine_curve > 0.0, "the feed channel is still a pure function of the source window")
	# 8. The sampled layer is additive and disjoint: two otherwise identical rigs,
	#    one armed and one cancelled, differ by exactly the sampled offset.
	var twin := rig_for(camera)
	# Both rigs take the identical weapon lifecycle, so the only difference left
	# between them is the sampled layer.
	for pair: Node in [rig, twin]:
		show(pair, {"weapon":1})
		show(pair, {"weapon":0})
	window(rig, 0.5)
	window(twin, 0.5)
	twin.cancel_mechanism("evidence control")
	rig.advance(1.0 / 60.0)
	twin.advance(1.0 / 60.0)
	var offset: Vector3 = rig.get_mechanism_state().offset
	var difference: Vector3 = rig.pivot.position - twin.pivot.position
	check(rig.get_mechanism_state().armed and not twin.get_mechanism_state().armed, "only the armed rig samples")
	# The pivot stores its pose at Godot's single-precision vector precision, so
	# the only meaningful tolerance here is a fraction of a float32 ULP.
	check(difference.distance_to(rig.weapon.transform.basis * offset) < 0.000001, "the sampled layer is exactly its own offset")
	check(rig.pivot.basis == twin.pivot.basis, "the sampled layer never rotates the pose")
	check(rig.pivot.position.distance_to(twin.pivot.position) > 0.001, "the sampled offset was visible in the pose")
	measured.append({"disjoint_offset_m":offset.length(),"pose_delta_m":difference.length()})
	twin.free()
	# 9. Cancellation and RESET ownership, each with an immediate rest pose.
	var cancellations: Array[Dictionary] = [
		{"reason":"source reload window closed","run":func(target: Node) -> void: show(target)},
		{"reason":"source posture blocks aim","run":func(target: Node) -> void:
			show(target, {"sprinting":true,"reloading":true,"reloadDuration":2.0,"reloadTimer":1.0})},
		{"reason":"source melee","run":func(target: Node) -> void:
			target.apply_events([{"id":700500,"time":7100.0,"type":"melee","actor":7,"hit":null}], 7)},
		{"reason":"motion cleared","run":func(target: Node) -> void:
			target.apply_actor({"id":7,"weapon":0,"health":0},true)},
		{"reason":"motion cleared","run":func(target: Node) -> void: target.apply_actor({"id":7,"weapon":0,"health":100},false)},
		{"reason":"motion cleared","run":func(target: Node) -> void: target.reset()},
		{"reason":"motion cleared","run":func(target: Node) -> void: target.clear_round()},
	]
	for case: Dictionary in cancellations:
		show(rig)
		window(rig, 0.5)
		rig.advance(1.0 / 120.0)
		check(rig.get_mechanism_state().armed, "armed before cancelling: " + case.reason)
		var callable: Callable = case.run
		callable.call(rig)
		var state: Dictionary = rig.get_mechanism_state()
		check(not state.armed, "cancelled: " + case.reason)
		check(state.cancelled_by == case.reason, "cancellation owner recorded: %s (got %s)" % [case.reason, state.cancelled_by])
		check(rig.mechanism.transform == Transform3D.IDENTITY, "the sampled node returned to rest: " + case.reason)
		rig.advance(1.0 / 120.0)
		check(rig.get_mechanism_state().offset == Vector3.ZERO, "no stale offset after cancelling: " + case.reason)
	# A weapon switch mid-reload cancels and does not carry the clip over.
	show(rig)
	window(rig, 0.5)
	rig.advance(1.0 / 120.0)
	show(rig, {"weapon":1})
	var state: Dictionary = rig.get_mechanism_state()
	check(not state.armed and rig.mechanism_clip == Profile.for_weapon(1).clip("reload"), "a weapon switch cancelled the pilot and rebound the clip")
	check(rig.mechanism.transform == Transform3D.IDENTITY, "the sampled node reseated on the switch")
	show(rig, {"weapon":0})
	# 10. The pilot is a Pulse Rifle pilot: a weapon whose profile authors no clip
	#     stays purely procedural, even inside its own source reload window.
	show(rig, {"weapon":9})
	var before_plays: int = rig.get_mechanism_state().plays
	window(rig, 0.5)
	rig.advance(1.0 / 120.0)
	fire(rig)
	rig.advance(1.0 / 120.0)
	state = rig.get_mechanism_state()
	check(rig.profile.clip("reload").is_empty(), "the Submachine Gun authors no clip")
	check(not state.armed and state.plays == before_plays, "a procedural weapon never arms a sampled track")
	check(state.offset == Vector3.ZERO, "a procedural weapon never carries a sampled offset")
	measured.append({"smg_plays":state.plays,"smg_clip":rig.mechanism_clip})
	# 11. Reduced motion keeps the sampled hardware motion, scaled down.
	show(rig, {"weapon":0})
	rig.reduced_motion = true
	window(rig, 0.5)
	rig.advance(1.0 / 120.0)
	var reduced: Vector3 = rig.get_mechanism_state().applied
	rig.reduced_motion = false
	window(rig, 0.5)
	rig.advance(1.0 / 120.0)
	var full: Vector3 = rig.get_mechanism_state().applied
	check(reduced.length() > 0.0 and absf(reduced.length() - full.length() * pulse.mechanism_reduced_scale()) < 0.000001,
		"reduced motion scales the sampled offset by the profile's weight")
	measured.append({"reduced_offset_m":reduced.length(),"full_offset_m":full.length(),"reduced_weight":pulse.mechanism_reduced_scale()})
	rig.reduced_motion = false
	rig.free()
	camera.free()
	print("FIRST_PERSON_MECHANISM_PILOT ", JSON.stringify({"checks":checks,"failures":failures,"measured":measured}))
	quit(0 if failures.is_empty() else 1)
