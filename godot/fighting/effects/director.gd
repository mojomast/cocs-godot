extends Node3D
## Event-only world FX. Call advance explicitly; no _process or authority callbacks.
const Geometry = preload("res://fighting/effects/geometry.gd")
const CATALOG_PATH := "res://fighting/assets/effects/catalog.json"
const AUDIO_ROOT := "res://fighting/assets/effects/audio/"
const EVENT_MODES := {
	"move_start": "startup", "attack_start": "startup", "startup": "startup",
	"hit": "impact", "counter_hit": "counter", "block": "guard", "guard": "guard",
	"projectile_spawn": "projectile", "projectile_hit": "impact", "projectile_clash": "clash",
	"projectile_reflect": "reflect", "reflect": "reflect", "clash": "clash",
	"throw_start": "grapple", "throw_grab": "grapple", "throw_hit": "throw",
	"throw_release": "release", "throw_end": "release", "throw_tech": "tech", "throw_break": "tech",
	"super": "super", "mobility": "movement", "land": "movement", "dash": "movement",
	"whiff": "whiff", "counter": "counter", "guard_start": "guard", "jump":"movement", "anchor_end":"release",
	"anchor_trigger":"grapple", "anchor_set":"movement", "stance_change":"movement"
}
var _catalog: Dictionary = {}
var _slots: Array[Dictionary] = []
var _voices: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _seen: Dictionary = {}
var _order: Array[int] = []
var _highest_id := -1
var _options: Dictionary = {}
var _tier: Dictionary = {}
var _material: StandardMaterial3D
var _fighters: Dictionary = {}
var _trails: Dictionary = {}
var _session: String = ""
var counters: Dictionary = {}

func configure(options: Dictionary) -> void:
	_dispose_pool()
	reset()
	_options = options.duplicate(true)
	_catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if _catalog.is_empty(): return
	var quality := str(options.get("quality", "high"))
	_tier = _catalog.budgets.get(quality, _catalog.budgets.low)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = false
	_material.disable_receive_shadows = true
	for i in range(int(_tier.slots)):
		var node := MeshInstance3D.new()
		var mesh := ImmediateMesh.new()
		node.mesh = mesh
		node.material_override = _material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		add_child(node)
		_slots.append({"node":node, "mesh":mesh, "active":false})
	for i in range(int(_tier.voices)):
		var voice := AudioStreamPlayer.new()
		voice.bus = "Master"
		voice.volume_db = -24.0
		add_child(voice)
		_voices.append(voice)
	_session = str(options.get("session_id", ""))

func consume(events: Array, fighters: Array) -> void:
	_fighters.clear()
	for fighter in fighters:
		if fighter is Dictionary: _fighters[int(fighter.get("id", -1))] = fighter.duplicate(true)
	for raw in events:
		if not raw is Dictionary: continue
		var event: Dictionary = raw
		if not _valid_event(event):
			counters.invalid += 1
			continue
		var id := int(event.id)
		if _seen.has(id) or id <= _highest_id - 4096:
			counters.duplicates += 1
			continue
		_seen[id] = true
		_order.append(id)
		_highest_id = maxi(_highest_id, id)
		if _order.size() > 4096: _seen.erase(_order.pop_front())
		counters.accepted += 1
		var type := str(event.type)
		if not EVENT_MODES.has(type):
			counters.unsupported += 1
			continue
		var actor := int(event.actor)
		var attack_operator := str(_fighters.get(actor, {}).get("operator_id", ""))
		if type in ["block", "guard"] or bool(event.get("blocked", false)):
			actor = int(event.target) if int(event.target) >= 0 else actor
		# Reflection uses new_owner if supplied, otherwise actor is the reflector.
		if type in ["projectile_reflect", "reflect"]: actor = int(event.get("new_owner", actor))
		var fighter: Dictionary = _fighters.get(actor, {})
		var operator := str(fighter.get("operator_id", ""))
		var move := str(event.move_id)
		if move.is_empty():
			# Core state events have no attack ID; these named cue IDs are catalogued.
			move = {"throw_tech":"throw_tech","throw_break":"throw_tech","land":"land", "jump":"jump_rise", "dash":"dash_f", "guard_start":"guard_hi"}.get(type, "")
		var effect_id := operator + ":" + move
		if type in ["block", "guard"] or bool(event.get("blocked", false)):
			# Guard uses defender form with the actual attack recipe/level, including
			# Gemini palm keys absent from the defender's own move list.
			effect_id = attack_operator + ":" + move
		if not _catalog.get("effects", {}).has(effect_id):
			counters.unsupported += 1
			continue
		var mode: String = EVENT_MODES[type]
		var recipe: Dictionary = _catalog.effects[effect_id]
		if bool(event.get("blocked", false)): mode = "guard"
		if bool(event.get("counter_hit", false)): mode = "counter"
		# Level is an optional contact annotation. Position remains the event's point.
		var level := str(event.get("level", ""))
		if level.is_empty():
			level = str(recipe.get("level", "mid"))
		if move == "super" and mode == "startup": mode = "super"
		var contact := Vector3(float(event.x) / 1000.0, float(event.y) / 1000.0, 0.0)
		var slot := _spawn(operator, recipe, mode, contact, int(fighter.get("facing", 1)))
		if not slot.is_empty(): slot.level = level
		if not slot.is_empty() and operator in ["chatgpt", "qwen"] and move == "special2":
			var source := Vector3(float(fighter.get("x", 0)) / 1000.0, float(fighter.get("y", 0)) / 1000.0 + 1.0, 0)
			if source.distance_to(contact) <= 6.5:
				slot.cable = Vector2(source.x - contact.x, source.y - contact.y)
		_sound(operator, mode)
	_present_states(fighters)

## Persistent affordances use explicit snapshot fields and declared frame windows.
## No stance, anchor or counter lifetime is inferred from presentation delta.
func _present_states(fighters: Array) -> void:
	var live: Dictionary = {}
	for fighter in fighters:
		if not fighter is Dictionary: continue
		var actor := int(fighter.get("id",-1))
		var operator := str(fighter.get("operator_id", ""))
		var requests: Array = []
		if operator == "qwen" and int(fighter.get("anchor_left",0)) > 0 and fighter.has("anchor_x"):
			requests.append({"name":"anchor","move":"special2","x":fighter.anchor_x,"y":180})
		if operator == "gemini" and int(fighter.get("stance_left",0)) > 0:
			requests.append({"name":"stance","move":"palm_l","x":fighter.get("x",0),"y":float(fighter.get("y",0))+650})
		var move := str(fighter.get("move_id", ""))
		var key := operator+":"+move
		if _catalog.get("effects",{}).has(key):
			var counter: Dictionary = _catalog.effects[key].get("declared_windows",{}).get("counter",{})
			var frame := int(fighter.get("move_frame",-1))
			if not counter.is_empty() and frame >= int(counter.get("from",0)) and frame <= int(counter.get("to",-1)):
				requests.append({"name":"counter_window","move":move,"x":fighter.get("x",0),"y":float(fighter.get("y",0))+1000})
		for request in requests:
			var state_id := str(actor)+":"+str(request.name)
			var effect_key := operator+":"+str(request.move)
			if not _catalog.get("effects",{}).has(effect_key): continue
			var contact := Vector3(float(request.x)/1000.0,float(request.y)/1000.0,0)
			if not contact.is_finite() or absf(contact.x)>100.0 or absf(contact.y)>100.0: continue
			live[state_id] = true
			var slot: Dictionary = {}
			for candidate in _slots:
				if candidate.active and candidate.get("state_id", "") == state_id:
					slot = candidate
					break
			if slot.is_empty():
				var recipe: Dictionary = _catalog.effects[effect_key].duplicate(true)
				recipe.scale = 0.4
				recipe.lifetime = 0.32
				slot = _spawn(operator,recipe,"guard" if request.name == "counter_window" else "movement",contact,int(fighter.get("facing",1)))
			if slot.is_empty(): continue
			slot.state_id = state_id
			slot.age = 0.05
			slot.node.position = contact+Vector3(0,0,-0.06)
			if request.name == "anchor":
				var source := Vector2(float(fighter.get("x",0))/1000.0-contact.x,float(fighter.get("y",0))/1000.0+1.0-contact.y)
				if source.length() <= 6.5: slot.cable = source
				else: slot.erase("cable")
			_draw(slot)
	for slot in _slots:
		if slot.has("state_id") and not live.has(slot.state_id):
			slot.active = false
			slot.node.visible = false
			slot.mesh.clear_surfaces()

func _valid_event(event: Dictionary) -> bool:
	for key in ["id", "tick", "type", "actor", "target", "move_id", "x", "y"]:
		if not event.has(key): return false
	for key in ["id", "tick", "actor", "target", "x", "y"]:
		if not (event[key] is int or event[key] is float): return false
		if not is_finite(float(event[key])) or float(event[key]) != floorf(float(event[key])): return false
	if int(event.id) < 0 or int(event.tick) < 0: return false
	return absf(float(event.x)) <= 100000.0 and absf(float(event.y)) <= 100000.0

func _spawn(operator: String, recipe: Dictionary, mode: String, contact: Vector3, facing: int) -> Dictionary:
	var slot: Dictionary = {}
	for candidate in _slots:
		if not candidate.active:
			slot = candidate
			break
	if slot.is_empty():
		counters.dropped += 1
		return {}
	var life := float(recipe.lifetime)
	if mode == "startup": life = clampf(float(recipe.get("startup_frames", 10)) / 60.0, 0.06, 0.6)
	if mode == "tech": life = 0.38
	if mode == "super": life = 0.72
	var size := float(recipe.scale)
	if mode == "whiff": size *= 0.65
	if mode == "startup": size *= 0.7
	slot.erase("cable")
	slot.erase("projectile_id")
	slot.erase("state_id")
	slot.erase("level")
	slot.merge({"active":true,"operator":operator,"mode":mode,"age":0.0,"life":life,
		"scale":size,"facing":1 if facing >= 0 else -1,
		"shape_variant":str(recipe.get("shape_variant", "")) if operator == "gemini" else ""}, true)
	# Behind hands/head, in front of scenery. Camera is on positive Z.
	slot.node.position = contact + Vector3(0, 0, -0.06)
	slot.node.visible = true
	counters.spawned += 1
	counters.peak_active = maxi(int(counters.peak_active), _active_count())
	_draw(slot)
	return slot

## Optional shell bridge: detached authoritative projectile snapshots, never extrapolated.
func present_projectiles(projectiles: Array, fighters: Array) -> void:
	var owners: Dictionary = {}
	for fighter in fighters:
		if fighter is Dictionary: owners[int(fighter.get("id", -1))] = fighter
	var live: Dictionary = {}
	for projectile in projectiles:
		if not projectile is Dictionary: continue
		if not projectile.has("id") or not projectile.has("x") or not projectile.has("y"): continue
		var id := int(projectile.id)
		var owner: Dictionary = owners.get(int(projectile.get("owner", -1)), {})
		var operator := str(owner.get("operator_id", ""))
		var key := operator + ":" + str(projectile.get("move_id", "special1"))
		if not _catalog.get("effects", {}).has(key): continue
		var contact := Vector3(float(projectile.x)/1000.0, float(projectile.y)/1000.0, 0)
		if not contact.is_finite() or absf(contact.x) > 100.0 or absf(contact.y) > 100.0: continue
		live[id] = true
		var slot: Dictionary = {}
		for candidate in _slots:
			if candidate.active and candidate.get("projectile_id", -1) == id:
				slot = candidate
				break
		if slot.is_empty(): slot = _spawn(operator, _catalog.effects[key], "projectile", contact, int(owner.get("facing", 1)))
		if slot.is_empty(): continue
		slot.projectile_id = id
		slot.operator = operator
		slot.facing = int(owner.get("facing", 1))
		slot.node.position = contact + Vector3(0,0,-0.06)
		slot.age = minf(float(slot.age), float(slot.life) * 0.4)
		_draw(slot)
	for slot in _slots:
		if slot.has("projectile_id") and not live.has(slot.projectile_id):
			slot.active = false
			slot.node.visible = false
			slot.mesh.clear_surfaces()

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or bool(_options.get("paused", false)): return
	for slot in _slots:
		if not slot.active: continue
		slot.age += minf(delta, 1.0)
		if float(slot.age) >= float(slot.life):
			slot.active = false
			slot.node.visible = false
			slot.mesh.clear_surfaces()
		else: _draw(slot)

func _draw(slot: Dictionary) -> void:
	var count := Geometry.draw(slot.mesh, _catalog.families[slot.operator], slot, int(_tier.segments), bool(_options.get("reduced_motion", false)))
	counters.peak_segments_per_effect = maxi(int(counters.peak_segments_per_effect), count)

func _active_count() -> int:
	var total := 0
	for slot in _slots:
		if slot.active: total += 1
	return total

func _sound(operator: String, mode: String) -> void:
	if bool(_options.get("muted", false)) or bool(_options.get("paused", false)): return
	var role := "attack"
	if mode == "guard": role = "guard"
	elif mode in ["impact", "counter", "clash", "reflect"]: role = "impact"
	elif mode in ["throw", "grapple", "release"]: role = "throw"
	elif mode == "tech": role = "tech"
	elif mode == "super": role = "super"
	if mode == "whiff": return
	var key := operator + "_" + role
	if not _streams.has(key):
		var bytes := FileAccess.get_file_as_bytes(AUDIO_ROOT + key + ".wav")
		if bytes.size() < 44: return
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.stereo = false
		stream.data = bytes.slice(44)
		_streams[key] = stream
	for voice in _voices:
		if voice.playing: continue
		voice.stream = _streams[key]
		voice.volume_db = -24.0 + linear_to_db(clampf(float(_options.get("volume", 1.0)), 0.0001, 1.0))
		voice.play()
		counters.audio_played += 1
		return
	counters.audio_dropped += 1

## Optional runner bridge, after fighter_visual.present(). Cosmetic trails only.
## Pass provider.socket_world; seek/facing/teleport discontinuities clear history.
func present_fighter(fighter: Dictionary, provider: Node3D, seeking: bool = false) -> void:
	var actor := int(fighter.get("id", -1))
	if seeking or not is_instance_valid(provider) or not provider.has_method("socket_world"):
		_trails.erase(actor)
		return
	var facing := int(fighter.get("facing", 1))
	var frame := int(fighter.get("animation_frame", 0))
	var origin := Vector3(float(fighter.get("x", 0)) / 1000.0, float(fighter.get("y", 0)) / 1000.0, 0)
	var old: Dictionary = _trails.get(actor, {})
	var move := str(fighter.get("move_id", ""))
	var key := str(fighter.get("operator_id", "")) + ":" + move
	if not _catalog.get("effects", {}).has(key):
		_trails.erase(actor)
		return
	if bool(_options.get("paused", false)) or int(fighter.get("hitstop",0)) > 0: return
	var socket: Vector3 = provider.call("socket_world", str(_catalog.effects[key].socket))
	if not socket.is_finite() or socket.distance_to(origin) > 3.0:
		_trails.erase(actor)
		return
	var discontinuity := old.is_empty()
	if not old.is_empty():
		discontinuity = old.facing != facing or old.move != move or frame < int(old.frame) or socket.distance_to(old.socket) > 0.6
	if not discontinuity and frame != int(old.frame) and not bool(_options.get("reduced_motion", false)):
		# Small authored form at the socket; no segment ever joins distant samples.
		var recipe: Dictionary = _catalog.effects[key].duplicate(true)
		recipe.scale = 0.22
		recipe.lifetime = 0.09
		_spawn(str(fighter.operator_id), recipe, "whiff", socket, facing)
	_trails[actor] = {"socket":socket,"facing":facing,"frame":frame,"move":move}

func set_paused(paused: bool) -> void:
	_options.paused = paused
	for voice in _voices: voice.stream_paused = paused

func _dispose_pool() -> void:
	for slot in _slots:
		remove_child(slot.node)
		slot.node.queue_free()
	for voice in _voices:
		voice.stop()
		remove_child(voice)
		voice.queue_free()
	_slots.clear()
	_voices.clear()

func reset() -> void:
	for slot in _slots:
		slot.active = false
		slot.node.visible = false
		slot.mesh.clear_surfaces()
	for voice in _voices:
		voice.stop()
		voice.stream = null
	_streams.clear()
	_seen.clear()
	_order.clear()
	_fighters.clear()
	_trails.clear()
	_highest_id = -1
	counters = {"accepted":0,"duplicates":0,"invalid":0,"unsupported":0,"spawned":0,"dropped":0,
		"peak_active":0,"peak_segments_per_effect":0,"audio_played":0,"audio_dropped":0}

## Seek/new-match clear FX and dedup but preserve configured capacities/options.
func restart_session(session_id: String = "") -> void:
	var options := _options.duplicate(true)
	options.session_id = session_id
	configure(options)

func metrics() -> Dictionary:
	var result := counters.duplicate(true)
	result.merge({"active":_active_count(),"pool_nodes":_slots.size()+_voices.size(),"mesh_slots":_slots.size(),
		"voice_slots":_voices.size(),"dedup_size":_seen.size(),"session_id":_session})
	return result
