extends SceneTree
## Real-time native key-event driver. Reads source gates/accepted vehicle only.
## No packets, state, actors, clocks or controls are assigned by this observer.
const Demo = preload("res://sports/demo.gd")
var demo
var age := 0.0
var directory := ""
var captures: Dictionary = {}
var busy := false
var held: Dictionary = {}
var round_number := 0
var drive_age := 0.0
var results_age := 0.0
var control_age := 0.0
var restart_age := 0.0
var stage := 0
var stopped := false
var origin := Vector3.ZERO
var last_gate := -1
var max_laps := 0
var goals: Array = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--progression-out="): directory = arg.trim_prefix("--progression-out=")
	demo = Demo.new()
	root.add_child.call_deferred(demo)
	call_deferred("connect_observer")

func connect_observer() -> void:
	demo.net.started.connect(func(_f: Dictionary) -> void: round_number += 1)
	demo.net.events.connect(func(items: Array) -> void:
		for item: Dictionary in items:
			if item.get("type") == "soccer-goal":
				goals.append(item)
				print("PROGRESSION_GOAL ", JSON.stringify(item)))

func key(code: int, pressed: bool) -> void:
	if bool(held.get(code, false)) == pressed: return
	held[code] = pressed
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: int) -> void:
	key(code, true)
	key(code, false)

func release() -> void:
	for code in held.keys(): key(code, false)
	tap(KEY_ESCAPE)

func position() -> Vector3:
	return Vector3(demo.vehicle.get("x",0), demo.vehicle.get("y",0), demo.vehicle.get("z",0))

func _process(delta: float) -> bool:
	age += delta
	if age > 220:
		push_error("Progression deadline")
		quit(1)
		return false
	if not is_instance_valid(demo) or not demo.is_node_ready(): return false
	if demo.phase == "error":
		push_error(demo.error)
		quit(1)
		return false
	var race: Dictionary = demo.state.get("race", {})
	if round_number == 1:
		if race.get("phase") in ["countdown", "kickoff"] and age > 1: capture("countdown")
		if demo.eligible():
			drive_age += delta
			if not stopped:
				if not demo.controls.engaged: tap(KEY_ENTER)
				control_age += delta
				if control_age > 0.07:
					control_age = 0
					drive(race)
			if drive_age > 2: capture("driving")
			if not goals.is_empty(): capture("goal")
			for row: Dictionary in race.get("standings", []):
				if row.get("actorId") != demo.net.actor_id or not row.has("nextGate"): continue
				max_laps = maxi(max_laps, int(row.get("completedLaps",0)))
				if int(row.nextGate) != last_gate:
					last_gate = int(row.nextGate)
					print("PROGRESSION_GATE ", JSON.stringify({"elapsed":race.elapsed,"row":row,"vehicle":demo.vehicle,"seq":demo.net.last_snapshot_seq,"ack":demo.net.last_ack}))
					if last_gate > 0: capture("checkpoint")
			if (max_laps >= 1 or drive_age > (45 if demo.mode == "puma-soccer" else 80)) and not stopped:
				release()
				stopped = true
			if max_laps >= 1: capture("lap")
		if demo.phase == "results":
			results_age += delta
			if results_age < 0.2: release()
			assert(not demo.controls.engaged and demo.controls.keys.is_empty())
			assert(demo.state.get("overReason") == "time", "ordinary time-limit results required")
			capture("results")
			if results_age > 1.5 and captures.has("results"):
				key(KEY_W, true) # ignored across results/countdown; deliberately keep held
				tap(KEY_F5)
				assert(demo.state.is_empty() and demo.vehicle.is_empty() and demo.actor.is_empty())
				assert(not demo.chase.seeded and demo.chase.eye == Vector3.ZERO)
				assert(not demo.ball.visible and not demo.guidance.visible and demo.progression.message.is_empty())
				print("PROGRESSION_RESTART_CLEARED ", JSON.stringify({"phase":demo.phase,"engaged":demo.controls.engaged,"keys":demo.controls.keys,"send_age":demo.send_age,"camera_seeded":demo.chase.seeded}))
	elif round_number == 2:
		if race.get("phase") in ["countdown", "kickoff"]: capture("restart-countdown")
		if demo.eligible():
			restart_age += delta
			if stage == 0:
				origin = position()
				stage = 1
			if stage == 1 and restart_age > 1:
				assert(not demo.controls.engaged and position().distance_to(origin) < 0.15, "held W cannot resume on restart")
				capture("restart-held-blocked")
				if captures.has("restart-held-blocked"):
					print("PROGRESSION_INPUT_STAGE ", JSON.stringify({"stage":"enter-only","round":round_number,"input_seq":demo.net.input_seq,"ack":demo.net.last_ack,"vehicle":demo.vehicle}))
					tap(KEY_ENTER)
					stage = 2
			if stage == 2 and restart_age > 2:
				assert(demo.controls.engaged and position().distance_to(origin) < 0.15, "Enter alone must not resurrect held movement")
				capture("restart-enter-neutral")
				if captures.has("restart-enter-neutral"):
					print("PROGRESSION_INPUT_STAGE ", JSON.stringify({"stage":"fresh-movement","round":round_number,"input_seq":demo.net.input_seq,"ack":demo.net.last_ack,"vehicle":demo.vehicle}))
					key(KEY_W, false)
					key(KEY_W, true)
					stage = 3
			if stage == 3 and restart_age > 3.2:
				assert(position().distance_to(origin) > 0.5, "fresh movement applies to accepted vehicle")
				capture("restart-fresh-driving")
				if captures.has("restart-fresh-driving"):
					release()
					stage = 4
			if stage == 4 and restart_age > 4.2 and not busy:
				print("PROGRESSION_ENDED ", JSON.stringify({"map":demo.map_id,"max_laps":max_laps,"last_gate":last_gate,"goals":goals,"captures":captures,"last_seq":demo.net.last_snapshot_seq,"ack":demo.net.last_ack}))
				quit()
	return false

func drive(race: Dictionary) -> void:
	var v: Dictionary = demo.vehicle
	var p := Vector2(v.x, v.z)
	var speed := Vector2(v.vx, v.vz).length()
	var target := p
	if demo.mode == "puma-race":
		var selected: Dictionary = demo.guidance.expected(race, demo.net.actor_id)
		if selected.is_empty(): return
		var gates: Array = race.gates
		var index: int = selected.index
		var a := Vector2(gates[(index+gates.size()-1)%gates.size()].x, gates[(index+gates.size()-1)%gates.size()].z)
		var b := Vector2(gates[index].x, gates[index].z)
		var along := clampf((p-a).dot((b-a).normalized()), 0, a.distance_to(b))
		var look := maxf(5, speed*0.6)
		if along+look < a.distance_to(b): target = a+(b-a).normalized()*(along+look)
		else:
			var c := Vector2(gates[(index+1)%gates.size()].x, gates[(index+1)%gates.size()].z)
			target = b+(c-b).normalized()*minf(look-(a.distance_to(b)-along), b.distance_to(c))
	else:
		var ball: Dictionary = race.get("ball", {})
		if ball.is_empty(): return
		var ball_pos := Vector2(ball.x, ball.z)
		var goal := Vector2(44, 0) # destination source opponent goal for Red
		for g: Dictionary in race.get("goals", []):
			if g.team != demo.actor.get("team", 0): goal = Vector2(g.x, g.z)
		var approach := ball_pos-(goal-ball_pos).normalized()*4
		target = ball_pos if p.distance_to(approach) < 5 else approach
	var error := wrapf(atan2(target.x-p.x,target.y-p.y)-float(v.yaw), -PI, PI)
	key(KEY_D, error > 0.075)
	key(KEY_A, error < -0.075)
	var cap := 11.0 if absf(error) > 0.5 else 16.0
	key(KEY_W, speed < cap)
	key(KEY_SPACE, speed > cap+2)

func capture(label: String) -> void:
	if busy or captures.has(label): return
	if label == "goal" and not demo.hud.text.contains("GOAL · Ball reset to centre"): return
	busy = true
	capture_image.call_deferred(label)

func capture_image(label: String) -> void:
	await RenderingServer.frame_post_draw
	check_ui(demo.hud)
	var path := directory.path_join(label + ".png")
	assert(root.get_texture().get_image().save_png(path) == OK)
	captures[label] = true
	print("PROGRESSION_CAPTURE ", JSON.stringify({"label":label,"round":round_number,"seq":demo.net.last_snapshot_seq,"ack":demo.net.last_ack,"vehicle":demo.vehicle,"race":demo.state.get("race"),"engaged":demo.controls.engaged,"keys":demo.controls.keys,"hud":demo.hud.text,"path":path}))
	busy = false

func check_ui(node: Node) -> void:
	if node is Control:
		assert(node.mouse_filter == Control.MOUSE_FILTER_IGNORE and node.focus_mode == Control.FOCUS_NONE)
		if node is Label and node.is_visible_in_tree():
			assert(root.get_visible_rect().encloses(node.get_global_rect()), "HUD label fits viewport")
	for child: Node in node.get_children(): check_ui(child)
