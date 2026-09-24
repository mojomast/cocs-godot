extends SceneTree
## Headless, deterministic authority/event contracts. No launcher or simulated
## damage: all effects below consume explicit received wire frames.
const Blood = preload("res://blood_fx/controller.gd")
const Horde = preload("res://horde/demo.gd")
class FakeBlood:
	extends Node3D
	var resets := 0
	var held := false
	func snapshot() -> Dictionary: return {"active_emitters":1}
	func set_active(active: bool, watchdog: bool = true) -> void:
		held = active and not watchdog
	func reset() -> void: resets += 1
var failures := 0
var checks := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func actor(health: float) -> Dictionary:
	return {"id": 17, "isNpc": true, "character": "chatgpt", "team": 1,
		"x": 2.0, "y": 0.0, "z": -4.0, "health": health,
		"maxHealth": 20.0, "armor": 0.0, "shots": 0, "npcType":"grunt"}

func run() -> void:
	var blood := Blood.new()
	# No emitter allocation or renderer needed: diagnostic counters verify wire
	# admission, while visual allocation is covered by the blood_fx suite.
	blood.configured = true
	blood.apply_state({"time": 1.0, "actors": [actor(20.0)]}, 0)
	blood.apply_state({"time": 1.1, "actors": [actor(0.0)]}, 0)
	blood.apply_events([{"type":"damage", "id":42, "time":1.1, "actor":17,
		"source":0, "amount":8.0, "shield":0.0}], 0)
	check(blood.last_event_id == 42 and blood.arterial_hits == 1,
		"authoritative lethal hit can spurt after zero-health snapshot")
	blood.apply_state({"time": 1.2, "actors": []}, 0)
	blood.apply_events([{"type":"death", "id":43, "time":1.1, "actor":17,
		"pos":{"x":2.0,"y":0.0,"z":-4.0}}], 0)
	check(blood.death_bursts == 1, "death with public position survives actor removal")
	blood.apply_events([{"type":"damage", "id":44, "time":1.2, "actor":17,
		"source":0, "amount":3.0, "shield":0.0}], 0)
	check(blood.no_bleed > 0, "known-dead victim does not bleed again")
	blood.reset()
	check(blood.departed_actors.is_empty() and blood.actors.is_empty(), "round reset drops cached actor poses")
	blood.apply_state({"time": 2.0, "actors": [actor(20.0)]}, 0)
	blood.apply_state({"time": 2.1, "actors": []}, 0)
	blood.apply_events([{"type":"damage", "id":45, "time":2.1, "actor":17,
		"source":0, "amount":8.0, "shield":0.0}], 0)
	check(blood.last_event_id == 45, "recently removed public NPC still anchors delayed wire hit")
	blood.apply_state({"time": 3.0, "actors": []}, 0)
	var old_id: int = blood.last_event_id
	blood.apply_events([{"type":"damage", "id":46, "time":2.1, "actor":17,
		"source":0, "amount":8.0, "shield":0.0}], 0)
	check(blood.last_event_id == old_id and blood.unknown_actors > 0,
		"expired pose cannot anchor a later hit")
	blood.apply_state({"time": 4.0, "actors": [actor(20.0)]}, 0)
	var before_detonation: int = blood.death_bursts
	blood.apply_events([{"type":"enemy-detonate", "id":47, "time":4.0,
		"actor":17, "x":2.0, "z":-4.0, "radius":3.0}], 0)
	check(blood.death_bursts == before_detonation + 1, "source sapper detonation also produces an authoritative death burst")
	blood.free()

	var horde := Horde.new()
	horde.phase = 3
	horde.client.actor_id = 0
	horde.remember_npcs({"actors":[actor(20.0)]})
	horde.apply_npc_deaths([{"type":"damage", "id":50, "actor":17, "amount":20.0}])
	check(horde.corpses.is_empty(), "damage does not invent a corpse or a kill")
	horde.apply_npc_deaths([{"type":"death", "id":51, "actor":999,
		"pos":{"x":2.0,"y":0.0,"z":-4.0}}])
	check(horde.corpses.is_empty(), "unknown actor death cannot become an NPC corpse")
	horde.apply_npc_deaths([{"type":"death", "id":52, "actor":17,
		"pos":{"x":2.0,"y":0.0,"z":-4.0}}])
	check(horde.corpses.size() == 1 and horde.corpses[0].node.death_active,
		"snapshot-identified NPC death starts a visible fall")
	horde.apply_npc_deaths([{"type":"death", "id":52, "actor":17}])
	check(horde.corpses.size() == 1, "duplicate event cannot spawn a second corpse")
	horde.remember_npcs({"actors":[actor(20.0).merged({"id": 18, "npcType":"sapper"})]})
	horde.apply_npc_deaths([{"type":"enemy-detonate", "id":53, "actor":18,
		"x":2.0, "z":-4.0, "radius":3.0}])
	check(horde.corpses.size() == 2, "authoritative sapper detonation preserves a fall")
	horde.advance_corpses(Horde.CORPSE_SECONDS + 0.01)
	check(horde.corpses.is_empty(), "corpse retires after its visible lifetime")
	horde.clear_npc_deaths()
	check(horde.corpse_events.is_empty() and horde.npc_actors.is_empty(), "round boundary clears death identities")
	horde.add_child(horde.combat)
	var fx := FakeBlood.new()
	horde.combat.add_child(fx)
	horde.combat.blood_fx = fx
	horde.combat.effects_active = true
	horde.hold_terminal_blood()
	check(horde.combat.blood_fx == null and horde.terminal_blood == fx and fx.held,
		"terminal result retains received burst without cloning blood or changing authority")
	horde.release_terminal_blood()
	check(horde.combat.blood_fx == fx and fx.resets == 1,
		"returning shared controller drains and restores normal round ownership")
	horde.free()
	print("HORDE_DEATH_CONTRACTS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
