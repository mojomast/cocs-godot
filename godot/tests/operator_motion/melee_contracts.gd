extends SceneTree
## Native regression: prepared only; run after an assigned engine/import slot.
const Presentation = preload("res://world/presentation.gd")
const Catalog = preload("res://source_operators/generated/catalog.gd")
const Audio = preload("res://world/audio_feedback.gd")
const Feedback = preload("res://world/melee_feedback.gd")
var failures: Array[String] = []
var measured: Array[Dictionary] = []

class EventClient:
	extends Node
	signal events(items: Array)

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr(message)

func actor(identity: String) -> Dictionary:
	return {"id":2,"character":identity,"health":100,"weapon":0,"x":0.0,"y":0.0,"z":0.0,"vx":0.0,"vy":0.0,"vz":0.0,"grounded":true,"yaw":0.0,"bodyYaw":0.0,"deaths":0}

func event(id: int, time: float, who: int = 2, hit: Variant = 3) -> Dictionary:
	return {"id":id,"type":"melee","time":time,"actor":who,"hit":hit,"pos":{"x":0.0,"y":0.8,"z":0.0},"impact":{"x":0.0,"y":0.8,"z":-0.65},"direction":{"x":0.0,"y":0.0,"z":-1.0}}

func observe(view: Node3D, a: Dictionary, time: float) -> void:
	view.apply_state({"time":time,"actors":[a]},1)
	view.actors[2].automatic_animation = false

func run() -> void:
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(50,0.2,50)
	shape.shape = box
	floor.add_child(shape)
	floor.position.y = -0.1
	root.add_child(floor)
	await physics_frame
	await physics_frame
	var view := Presentation.new()
	var client := EventClient.new()
	root.add_child(client)
	root.add_child(view)
	view.bind_melee_events(client)
	view.bind_melee_events(client)
	check(client.get_signal_connection_list("events").size()==1,"duplicate pose event subscription")
	view.set_process(false)
	for identity: String in Catalog.OPERATORS:
		view.clear_round()
		var a := actor(identity)
		observe(view,a,1.0)
		var visual: Node3D = view.actors[2]
		for frame in 60: visual.advance(1.0/60)
		for strike in 3:
			var time := 1.0+strike*0.32
			observe(view,a,time)
			var input := event(strike+1,time)
			var before_input := input.duplicate(true)
			var before_actor := a.duplicate(true)
			var transform_before := visual.transform
			var side := "R" if strike==1 else "L"
			var support := "L" if strike==1 else "R"
			var rest: Vector3 = visual.nodes["foot"+side].global_position
			client.events.emit([input])
			client.events.emit([input])
			visual.advance(0.095)
			check(visual.world_melee.sequence.step==strike,identity+" accepted chain order")
			check(visual.world_melee.sequence.accepted==strike+1,identity+" duplicate accepted kick")
			var travel: float = rest.distance_to(visual.nodes["foot"+side].global_position)
			check(travel>0.25,identity+" world kick never extended")
			check(not visual.locomotion.contacts[side].planted,identity+" kicking foot still pinned")
			var support_error: float = visual.locomotion.contacts[support].error
			check(support_error<0.015,identity+" support foot drift after pelvis overlay")
			for hand: String in visual.grip_error:
				check(visual.grip_error[hand]-visual.grip_clamp.get("clamped"+hand,0)<0.003,identity+" kick breaks hand constraint")
			check(visual.transform.is_equal_approx(transform_before),identity+" kick moved authoritative root")
			check(a==before_actor and input==before_input,identity+" kick mutated source data")
			measured.append({"operator":identity,"strike":strike+1,"ankleTravel":travel,"supportError":support_error})
			if strike == 2: visual.hide()
			visual.advance(0.225)
			if strike == 2:
				visual.show()
				check(visual.world_melee.side().is_empty(),identity+" hidden active kick resumed")
		check(view.melee_events.counters.dispatched==3,identity+" event/animation count mismatch")
		# Foreign, malformed, stale, hidden and locally-owned events are consumed.
		observe(view,a,2.0)
		var malformed := event(6,2.0); malformed.pos.x = NAN
		view.apply_events([event(4,2.0,99),event(5,2.0,1),malformed,event(7,0.0)])
		check(visual.world_melee.sequence.accepted==3,identity+" invalid/foreign event animated")
		visual.hide()
		view.apply_events([event(8,2.0)])
		visual.show()
		view.apply_events([event(8,2.0)])
		check(visual.world_melee.sequence.accepted==3,identity+" hidden event replayed on reveal")
		view.apply_events([event(9,2.0)],false)
		view.apply_events([event(9,2.0)],true)
		check(visual.world_melee.sequence.accepted==3,identity+" suspended event replayed")
		# Miss/block/protection break continuation with the same shared rules as FPS.
		observe(view,a,2.32)
		view.apply_events([event(10,2.32)])
		observe(view,a,2.64)
		var blocked := event(11,2.64); blocked.blocked = true
		view.apply_events([blocked])
		check(visual.world_melee.sequence.step==1 and not visual.world_melee.sequence.continuing,identity+" blocked chain parity")
		observe(view,a,2.96)
		view.apply_events([event(12,2.96,2,null)])
		check(visual.world_melee.sequence.step==0 and not visual.world_melee.sequence.continuing,identity+" miss chain parity")
		observe(view,a,3.28)
		var protected := event(13,3.28); protected.protected = true
		view.apply_events([protected])
		check(not visual.world_melee.sequence.continuing,identity+" protected hit continued chain")
		# Death/respawn invalidates delayed events even within the normal age limit.
		a.health = 0; observe(view,a,3.4)
		check(visual.world_melee.side().is_empty(),identity+" dead operator keeps kicking")
		a.health = 100; a.deaths = 1; observe(view,a,3.5)
		var count: int = visual.world_melee.sequence.accepted
		view.apply_events([event(14,3.35)])
		check(visual.world_melee.sequence.accepted==count,identity+" pre-respawn event applied to new life")
		view.apply_events([event(15,3.5)])
		a.vehicleId = 7; observe(view,a,3.6)
		check(visual.world_melee.side().is_empty(),identity+" mounted operator keeps kicking")
		a.erase("vehicleId"); observe(view,a,3.7)
		view.apply_events([event(16,3.7)])
		visual.seek_pose(a,3.7)
		view.apply_events([event(16,3.7)])
		check(visual.world_melee.side().is_empty(),identity+" seek replayed consumed event")
		# Running retains authoritative travel while the kicking leg releases IK.
		a.vz = -8.0; a.z = -0.76; observe(view,a,4.0)
		view.apply_events([event(17,4.0)])
		var sprint_root := visual.transform
		visual.advance(0.095)
		check(visual.transform.is_equal_approx(sprint_root),identity+" sprint kick altered root")
		check(not visual.locomotion.contacts[visual.world_melee.side()].planted,identity+" sprint kick still pinned")
		# No fabricated support while jumping.
		a.grounded = false; a.y = 1.0; a.vy = 2.0; a.z -= 0.3; observe(view,a,4.32)
		view.apply_events([event(18,4.32)])
		visual.advance(0.095)
		check(not visual.locomotion.contacts.L.planted and not visual.locomotion.contacts.R.planted,identity+" air kick invented support")
		var root_before := visual.transform
		check(not visual.world_melee.side().is_empty(),identity+" accepted air kick suppressed")
		visual.advance(0.05)
		check(visual.transform.is_equal_approx(root_before),identity+" air kick altered root")
		view.apply_state({"time":4.42,"actors":[]},1)
		observe(view,a,4.52)
		visual = view.actors[2]
		view.apply_events([event(19,4.37)])
		check(visual.world_melee.sequence.accepted==0,identity+" old actor event reached reused ID")
		view.melee_events.advance(0.6)
		view.apply_events([event(20,4.52)])
		check(visual.world_melee.sequence.accepted==0,identity+" stale transport kick queued")
		observe(view,a,5.0)
		view.set_melee_clock(5.095)
		view.apply_events([event(21,5.0)])
		visual.advance(1.0/30)
		var replay_age: float = visual.world_melee.sequence.age
		visual.advance(1.0/144)
		check(is_equal_approx(replay_age,0.095) and is_equal_approx(visual.world_melee.sequence.age,replay_age),identity+" replay kick drifted with render clock")
		view.interrupt_melee()
		visual.advance(1.0/60)
		check(visual.world_melee.side().is_empty(),identity+" replay interruption revived clocked kick")
	# A fresh round permits source IDs to restart, while the existing audio path
	# still emits only its one whoosh and one confirmed impact per accepted event.
	view.clear_round()
	var audio := Audio.new()
	var feedback := Feedback.new()
	root.add_child(audio); root.add_child(feedback)
	feedback.configure(audio)
	var a := actor("chatgpt")
	for strike in 3:
		var time := 0.1+strike*0.32
		observe(view,a,time)
		var input := event(strike+1,time)
		feedback.consume([input],[a])
		view.apply_events([input])
		feedback.consume([input],[a])
		view.apply_events([input])
	check(view.actors[2].world_melee.sequence.accepted==3,"round reset failed to admit fresh event IDs")
	check(feedback.counters.whoosh==3 and feedback.counters.impact==3,"world pose bridge duplicated audio or impact")
	check(client.get_signal_connection_list("events").size()==1,"round resets duplicated event subscription")
	feedback.free(); audio.free(); view.free(); floor.free()
	check(client.get_signal_connection_list("events").is_empty(),"freed presentation retained event subscription")
	client.free()
	print(JSON.stringify({"gate":"operator-world-melee","passed":failures.is_empty(),"failures":failures,"measurements":measured}))
	quit(0 if failures.is_empty() else 1)
