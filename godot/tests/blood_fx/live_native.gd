extends SceneTree
## Live native-Deathmatch blood check on the REAL demo composition.
##
## Runs the actual native scene against a real authority and drives real source
## gameplay, then reports the blood controller's own counters and saves rendered
## frames. Two scenarios:
##
##   default        the local seat takes real damage through the authority's debug
##                  frame (wounds on the player)
##   --hunt         the harness aims the local seat at the nearest living bot and
##                  fires through the ordinary input contract, so the frames show a
##                  bot taking real damage in view
##
## The scene's own user args are passed through; this harness adds:
##   --capture=<path>   save one rendered frame beside the counters
##   --hits=<count>     self hits to take in the default scenario (default 5)
##   --hunt[=<count>]   fire at bots and stop after this many landed hits (default 3)
const Demo = preload("res://native_arenas/demo.tscn")

var demo: Node
var combat: Node
var client: Node
var signals_ready := false
var capture_path := ""
var hits_target := 5
var hunt := false
var hunt_target := 3
var hunt_hits := 0
var deaths_seen := 0
var death_frames_saved := 0
var hunt_frames: Array[String] = []
var last_state: Dictionary = {}
var epoch := 0
var input_seq := 0
var input_timer := 0.0
var elapsed := 0.0
var hit_timer := 1.0
var sent := 0
var settle := 0.0
var sent_reported := false
var finished := false

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--hits="): hits_target = maxi(1, int(arg.trim_prefix("--hits=")))
		if arg == "--hunt": hunt = true
		if arg.begins_with("--hunt="): hunt = true; hunt_target = maxi(1, int(arg.trim_prefix("--hunt=")))
	demo = Demo.instantiate()
	root.add_child(demo)

func bind_client() -> void:
	if signals_ready or not is_instance_valid(client): return
	signals_ready = true
	client.snapshot.connect(on_snapshot)
	client.events.connect(on_events)

func on_snapshot(frame: Dictionary) -> void:
	last_state = frame.get("state", {})
	epoch = int(frame.get("inputEpoch", epoch))

func on_events(items: Array) -> void:
	var local := int(client.actor_id)
	for value: Variant in items:
		if not value is Dictionary: continue
		var item: Dictionary = value
		if item.get("type") == "death" and int(item.get("actor", -1)) != local:
			deaths_seen += 1
			if not capture_path.is_empty() and deaths_seen <= 2 and deaths_seen > death_frames_saved:
				death_frames_saved = deaths_seen
				var death_path := capture_path.replace(".png", "-death%d.png" % deaths_seen)
				var death_image: Image = root.get_texture().get_image()
				if death_image.save_png(death_path) == OK: hunt_frames.append(death_path)
			continue
		if item.get("type") != "damage": continue
		if int(item.get("source", -1)) != local or int(item.get("actor", -1)) == local: continue
		hunt_hits += 1
		if not capture_path.is_empty() and hunt_hits <= 3:
			var path := capture_path.replace(".png", "-hit%d.png" % hunt_hits)
			var image: Image = root.get_texture().get_image()
			if image.save_png(path) == OK: hunt_frames.append(path)

## Aim at the nearest living bot's chest using the source's own conventions:
## aimVector(yaw, pitch) = (-sin(yaw)cos(pitch), sin(pitch), -cos(yaw)cos(pitch)).
func aim_at_bot() -> Array:
	var local := int(client.actor_id)
	var actors: Array = last_state.get("actors", [])
	var me: Dictionary = {}
	for value: Variant in actors:
		if value is Dictionary and int(value.get("id", -1)) == local: me = value
	if me.is_empty(): return []
	var best: Dictionary = {}
	var best_distance := INF
	for value: Variant in actors:
		if not value is Dictionary: continue
		var bot: Dictionary = value
		if int(bot.get("id", -1)) == local or bool(bot.get("dead", false)): continue
		if float(bot.get("health", 0.0)) <= 0.0: continue
		var distance := Vector2(float(bot.x) - float(me.x), float(bot.z) - float(me.z)).length()
		if distance < best_distance: best_distance = distance; best = bot
	if best.is_empty(): return []
	var eye_y := float(me.y) + float(me.get("eyeHeight", 1.6))
	var dx := float(best.x) - float(me.x)
	var dy := float(best.y) + 0.95 - eye_y
	var dz := float(best.z) - float(me.z)
	var flat := maxf(0.001, sqrt(dx * dx + dz * dz))
	var length := maxf(0.001, sqrt(dx * dx + dy * dy + dz * dz))
	return [atan2(-dx, -dz), asin(clampf(dy / length, -1.0, 1.0)), flat]

func _process(delta: float) -> bool:
	if finished: return false
	elapsed += delta
	if not is_instance_valid(combat):
		combat = demo.get("combat")
		client = demo.get("client")
	if not is_instance_valid(combat) or not is_instance_valid(client): return false
	bind_client()
	if int(demo.get("phase")) != 3:
		if elapsed > 60.0: return fail("no live round within 60 s (phase %s)" % [str(demo.get("phase"))])
		return false
	# A player engages the session by clicking into the window; under a bare Xvfb
	# there is no window manager to deliver that focus, so the harness asserts the
	# same state the click produces. Without it the effects stack is (correctly)
	# inactive and no fluid is emitted.
	demo.set("application_focused", true)
	if not sent_reported:
		sent_reported = true
		print("BLOOD_LIVE_STATE ", JSON.stringify({"phase":int(demo.get("phase")),
			"application_focused":demo.get("application_focused"), "hits_target":hits_target,
			"hunt":hunt, "hunt_target":hunt_target}))
	if hunt:
		input_timer += delta
		if input_timer >= 0.05:
			input_timer = 0.0
			var aim := aim_at_bot()
			if not aim.is_empty():
				input_seq += 1
				client.send_frame({"type":"input", "seq":input_seq, "inputEpoch":epoch,
					"input":{"x":0.0, "z":0.0, "yaw":aim[0], "pitch":aim[1], "fire":true}})
		if hunt_hits >= hunt_target:
			settle += delta
			if settle < 0.6: return false
			return finish()
		if elapsed > 90.0: return fail("bot hunt landed no hits within 90 s")
		return false
	if sent < hits_target:
		hit_timer += delta
		if hit_timer >= 0.7:
			hit_timer = 0.0
			sent += 1
			if client.send_frame({"type":"debug", "v":1, "testDamage":28}) != OK:
				return fail("debug frame could not be queued")
			print("BLOOD_LIVE_HIT ", sent)
		return false
	settle += delta
	if settle < 2.0: return false
	return finish()

func finish() -> bool:
	finished = true
	var blood: Node = combat.get("blood_fx")
	if not is_instance_valid(blood):
		return fail("blood controller never attached (map_error=%s)" % [str(combat.get("map_error"))])
	var snapshot: Dictionary = blood.snapshot()
	var report := {
		"events_seen":int(snapshot.get("events_seen", 0)), "spurts":int(snapshot.get("spurts", 0)),
		"mist_events":int(snapshot.get("mist_events", 0)), "arterial_hits":int(snapshot.get("arterial_hits", 0)),
		"stains_live":int(snapshot.get("stains_live", 0)), "stains_recycled":int(snapshot.get("stains_recycled", 0)),
		"rejected":int(snapshot.get("rejected", 0)), "no_bleed":int(snapshot.get("no_bleed", 0)),
		"unknown_actors":int(snapshot.get("unknown_actors", 0)), "absorbed_only":int(snapshot.get("absorbed_only", 0)),
		"absorbed_mist_events":int(snapshot.get("absorbed_mist_events", 0)),
		"duplicates":int(snapshot.get("duplicates", 0)), "self_hits":sent, "bot_hits":hunt_hits,
		"death_bursts":int(snapshot.get("death_bursts", 0)), "bot_deaths":deaths_seen,
		"map_error":str(combat.get("map_error")), "map":str(combat.get("map_key")),
		"frames":hunt_frames}
	if not capture_path.is_empty():
		var image: Image = root.get_texture().get_image()
		report["capture"] = capture_path
		report["capture_result"] = image.save_png(capture_path)
	if report.events_seen >= 1 and report.spurts + report.mist_events + report.absorbed_mist_events >= 1:
		print("BLOOD_LIVE_OK ", JSON.stringify(report))
		quit(0)
		return true
	print("BLOOD_LIVE_FAILED ", JSON.stringify(report))
	quit(1)
	return true

func fail(message: String) -> bool:
	finished = true
	print("BLOOD_LIVE_FAILED ", JSON.stringify({"error":message}))
	quit(1)
	return true
