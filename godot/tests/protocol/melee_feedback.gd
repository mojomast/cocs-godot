extends SceneTree
const Feedback = preload("res://world/melee_feedback.gd")
const Audio = preload("res://world/audio_feedback.gd")
const Buses = preload("res://audio/buses.gd")
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func _initialize() -> void:
	call_deferred("run")

func event(id: int, hit: Variant = null) -> Dictionary:
	return {"type":"melee", "id":id, "time":float(id) * 0.2, "actor":7, "hit":hit,
		"pos":{"x":0.0,"y":1.0,"z":0.0}, "impact":{"x":0.0,"y":1.0,"z":-1.2},
		"direction":{"x":0.0,"y":0.0,"z":-1.0}}

func visible_count(fx: Node) -> int:
	var count := 0
	for slot: Dictionary in fx.rings:
		if slot.node.visible: count += 1
	return count

func run() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	var fx := Feedback.new()
	root.add_child(fx)
	fx.configure(audio)
	fx.consume([event(1)], [])
	check(fx.counters.whoosh == 1 and fx.counters.impact == 0 and visible_count(fx) == 0, "accepted miss has movement only")
	fx.consume([event(1), {"type":"melee-rejected","id":2}], [])
	check(fx.counters.whoosh == 1, "duplicate and rejection never replay")
	var malformed := event(2, 8)
	malformed.id = null
	var invalid_time := event(2, 8)
	invalid_time.time = NAN
	fx.consume([malformed, invalid_time], [])
	check(fx.counters.whoosh == 1 and visible_count(fx) == 0, "malformed accepted-event envelope cannot create feedback")
	fx.clear_transient()
	fx.consume([event(3, 8)], [])
	check(fx.counters.whoosh == 2 and fx.counters.impact == 1 and visible_count(fx) == 1, "confirmed contact adds one smack and ring")
	var slot: Dictionary = fx.rings[0]
	check(slot.node.global_position.is_equal_approx(Vector3(0, 1, -1.16)), "explicit contact wins, offset toward attacker")
	check(slot.node.basis.y.normalized().is_equal_approx(Vector3.FORWARD), "ring world normal follows contact direction")
	var initial: float = slot.node.scale.x
	fx.advance(0.1)
	check(slot.node.scale.x > initial and slot.material.albedo_color.a < 0.85, "contact ring expands and fades")
	fx.advance(0.2)
	check(visible_count(fx) == 0, "short ring expires")
	fx.clear_transient()
	for hit: Variant in [null, false, "8", -1, 7]:
		fx.consume([event(10 + fx.highest, hit)], [])
	var blocked := event(100, 8)
	blocked.blocked = true
	var protected := event(101, 8)
	protected.protected = true
	fx.consume([blocked, protected], [])
	check(fx.counters.impact == 1 and visible_count(fx) == 0, "miss, invalid/self hit, blocked and protected results cannot impact")
	var legacy := event(102, 8)
	legacy.erase("impact")
	legacy.erase("direction")
	var actors := [{"id":8,"x":1.0,"y":0.0,"z":-1.0}]
	check(Feedback.contact(legacy, actors).is_equal_approx(Vector3(1, 0.9, -1)), "legacy actual hit uses public target centre")
	fx.clear_transient()
	fx.consume([legacy], actors)
	check(fx.counters.impact == 2 and visible_count(fx) == 1, "legacy confirmed hit receives feedback")
	fx.set_muted(true)
	var before: int = fx.counters.whoosh
	fx.consume([event(103, 8)], [])
	check(fx.counters.whoosh == before and fx.counters.impact == 2, "mute suppresses both sounds")
	for voice: AudioStreamPlayer3D in fx.voices:
		check(not voice.playing and voice.stream == null and voice.bus == &"Effects" and voice.max_distance == Feedback.MAX_DISTANCE, "muted voices drained; spatial Effects routing")
	fx.set_muted(false)
	fx.consume([event(103, 8)], [])
	check(fx.counters.whoosh == before, "unmute cannot replay consumed events")
	Buses.apply({"mute":true})
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")) and AudioServer.get_bus_send(AudioServer.get_bus_index("Effects")) == &"Master", "settings mute covers spatial Effects voices routed through Master")
	Buses.apply({"mute":false})
	fx.clear_transient()
	fx.consume([event(104, 8)], [], false)
	fx.consume([event(104, 8)], [], true)
	check(visible_count(fx) == 0, "suspended events drain without recovery replay")
	fx.set_muted(true)
	for id: int in range(200, 250): fx.consume([event(id, 8)], [])
	check(fx.rings.size() == Feedback.MAX_RINGS and visible_count(fx) == Feedback.MAX_RINGS and fx.voices.size() == Feedback.MAX_VOICES, "burst cannot grow node pools")
	fx.set_quality(0)
	check(visible_count(fx) <= 4, "Low quality immediately caps rings")
	fx.advance(1.0)
	fx.consume([event(251, 8)], [])
	check(is_equal_approx(float(fx.rings[0].life), 0.16), "Low uses short essential contact cue")
	fx.advance(0.17)
	check(visible_count(fx) == 0, "Low contact expires")
	fx.set_quality(2)
	fx.set_reduced_motion(true)
	fx.consume([event(252, 8)], [])
	check(fx.ring_limit() == 4 and is_equal_approx(float(fx.rings[0].life), 0.16), "reduced-motion preference retains small brief confirmation at Extreme")
	fx.consume([event(5000)], [])
	fx.consume([event(1, 8)], [])
	check(not fx.seen.has(1) and fx.seen.size() <= Feedback.EVENT_WINDOW, "old event cannot reenter bounded dedup window")
	fx.clear_round()
	check(fx.seen.is_empty() and visible_count(fx) == 0 and fx.highest == -1, "round reset drains and permits new ID epoch")
	fx.set_muted(false)
	var no_contact := event(1, 8)
	no_contact.erase("impact")
	fx.consume([no_contact], [])
	check(fx.counters.whoosh == 1 and fx.counters.impact == 0 and visible_count(fx) == 0, "missing legacy victim cannot invent an impact at origin")
	var hit := event(9, 8)
	var damage := {"type":"damage","id":8,"time":hit.time,"source":7,"actor":8,"amount":30}
	check(audio._melee_damage(damage, [damage, hit]), "melee smack replaces last-gun generic confirmation")
	damage.time = 99.0
	check(not audio._melee_damage(damage, [damage, hit]), "unrelated gun damage retains own confirmation")
	for impact: bool in [false, true]:
		var sound: AudioStreamWAV = audio.melee_sound(impact)
		check(sound == audio.melee_sound(impact), "melee PCM cached")
		check(sound.data == audio._make_sound("melee-impact" if impact else "melee-whoosh", 0.22 if impact else 0.16).data, "original PCM deterministic")
		var peak := 0.0
		for index: int in sound.data.size() / 2:
			peak = maxf(peak, absf(float(sound.data.decode_s16(index * 2)) / 32768.0))
		check(peak > 0.4 and peak <= 0.65, "audible PCM within peak ceiling")
		check(sound.data.decode_s16(0) == 0 and sound.data.decode_s16(sound.data.size()-2) == 0, "no hard PCM endpoints")
	check(audio.melee_sound(false).data != audio.melee_sound(true).data, "swoosh and smack have distinct PCM")
	fx.free()
	audio.free()
	print("MELEE_FEEDBACK_OK checks=", checks)
	quit(0)
