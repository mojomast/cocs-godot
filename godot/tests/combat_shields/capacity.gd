extends SceneTree
## Regression for independent SHIELD-CAP-ORDER; renderer capacity is not history.
const Controller = preload("res://combat_shields/controller.gd")
var failed := false
var assertions := 0
var results: Array = []
var fx: Node3D
var camera: Camera3D
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failed = true
		push_error("SHIELD_CAPACITY: " + message)

func actor(id: int, extra: Dictionary = {}) -> Dictionary:
	var value := {"id":id,"x":0.0,"y":0.0,"z":0.0,"yaw":0.0,"health":100.0,"dead":0.0,"armor":0.0,"grounded":true,"protection":0.0,"vehicleId":null}
	value.merge(extra,true)
	return value

func snapshot(actors: Array) -> Dictionary: return {"actors":actors,"time":1.0}

func owners() -> Array:
	var ids: Array = []
	for slot: Dictionary in fx.slots:
		if slot.owner >= 0: ids.append(slot.owner)
	ids.sort()
	return ids

func node_ids() -> Array:
	var ids: Array = []
	for slot: Dictionary in fx.slots: ids.append(slot.node.get_instance_id())
	ids.sort()
	return ids

func run() -> void:
	camera = Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0,0.9,6)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	fx = Controller.new()
	root.add_child(fx)
	fx.configure(camera)
	fx.set_process(false)
	for level in [0,1]:
		fx.reset()
		fx.set_quality(level)
		var capacity: int = fx.actor_limit()
		var crowded: Array = []
		for id in range(capacity): crowded.append(actor(id))
		crowded.append(actor(capacity,{"protection":1.0}))
		var original := JSON.stringify(crowded)
		fx.apply_state(snapshot(crowded),-1)
		check(JSON.stringify(crowded) == original,"source ordering and dictionaries preserved")
		check(owners() == [capacity] and fx.debug_state().visible_shells == 1,"only protected actor renders after low/high irrelevant prefix")
		check(fx.factory.state().materials == 1 and fx.get_child_count() == 1,"irrelevant prefix reserves zero materials or nodes")
		check(fx.tracks.size() == capacity+1,"unprotected histories retained independently")
		var first: Dictionary = fx.debug_state()
		var existing_nodes := node_ids()
		crowded.reverse() # Test-owned fixture; controller must not mutate it.
		fx.apply_state(snapshot(crowded),-1)
		check(owners() == [capacity] and node_ids() == existing_nodes,"same-controller reordering keeps identity and node stable")
		check(fx.counters.phase == 0 and fx.counters.recovery == 0,"roster or slot appearance never fabricates transitions")
		fx.reset()
		fx.apply_state(snapshot(crowded),-1)
		check(owners() == [capacity] and fx.factory.state().materials == 1,"reset plus reversed order has identical visibility/allocation")
		results.append({"quality":level,"prefix":first,"reversed":fx.debug_state()})

		# More eligible actors than either budget: local/dead/seated/near/behind
		# camera cannot reserve slots. Real pools outrank even nearer ordinary armor.
		fx.reset()
		var pressure: Array = [actor(0,{"protection":1}),actor(1,{"protection":1,"health":0,"dead":2}),actor(2,{"protection":1,"vehicleId":0}),actor(3,{"protection":1,"z":5}),actor(4,{"protection":1,"z":10})]
		for id in range(capacity+8): pressure.append(actor(10+id,{"armor":20,"z":-float(id)*0.1}))
		pressure.append(actor(900,{"temporaryShield":30,"z":-20}))
		fx.apply_state(snapshot(pressure),0)
		var expected: Array = []
		for id in range(capacity-1): expected.append(10+id)
		expected.append(900)
		check(owners() == expected,"pool/visibility/distance priority precedes capacity")
		var pressure_nodes := node_ids()
		pressure.reverse()
		fx.apply_state(snapshot(pressure),0)
		check(owners() == expected and node_ids() == pressure_nodes,"oversubscribed winner set is source-order independent")
		check(fx.slots.size() == capacity and fx.get_child_count() == capacity,"oversubscribed allocation stays within shell budget")
		for excluded in [0,1,2,3,4]: check(fx.tracks[excluded].slot.is_empty(),"excluded actor consumes no shell slot " + str(excluded))

		# Slot-starved armor still observes genuine event + state depletion, healing,
		# and respawn. Acquiring a recycled slot does not reset any of that history.
		var target_id := capacity+17
		check(fx.tracks[target_id].slot.is_empty(),"transition target starts outside render budget")
		fx.apply_events([{"id":1,"type":"damage","actor":target_id,"source":10,"amount":40,"shieldBreak":false}],0)
		var target: Dictionary
		for a: Dictionary in pressure:
			if a.id == target_id: target = a
		target.armor = 0.0
		target.health = 80.0
		fx.apply_state(snapshot(pressure),0)
		check(fx.counters.shatters == 1 and fx.tracks[target_id].slot.is_empty(),"starved armor depletion still produces one genuine break")
		fx.apply_events([{"id":1,"type":"damage","actor":target_id,"amount":40,"shieldBreak":false}],0)
		check(fx.counters.shatters == 1,"starved damage replay deduplicates")
		target.health = 90.0
		fx.apply_state(snapshot(pressure),0)
		check(fx.counters.recovery == 1,"unprotected slotless history still observes recovery")
		target.health = 0.0
		target.dead = 2.0
		fx.apply_state(snapshot(pressure),0)
		target.health = 100.0
		target.dead = 0.0
		target.protection = 1.0
		fx.apply_state(snapshot(pressure),0)
		check(fx.counters.phase == 1 and not fx.tracks[target_id].slot.is_empty(),"slotless dead-to-alive history gives one real respawn and wins recycled slot")
		check(node_ids() == pressure_nodes,"eligibility change recycles existing nodes instead of allocating")
		fx.apply_events([{"id":2,"type":"spawn","actor":target_id}],0)
		check(fx.counters.phase == 1,"source spawn event coalesces with observed respawn after recycle")
		target.protection = 0.0
		fx.apply_state(snapshot(pressure),0)
		var previous_counters: Dictionary = fx.counters.duplicate()
		target.protection = 1.0
		fx.apply_state(snapshot(pressure),0)
		check(fx.counters == previous_counters,"reacquisition alone never replays phase/break/recovery")

		# Camera-only selection changes run without a new state and keep histories.
		camera.position.z = -30.0
		fx._process(0.01)
		check(owners().is_empty(),"camera behind actors releases all shell owners")
		camera.position.z = 6.0
		fx._process(0.01)
		check(owners().size() == capacity and fx.counters == previous_counters,"camera return reacquires without fake state transitions")
		check(fx.debug_state().materials <= capacity+fx.burst_limit() and fx.factory.state().materials == fx.get_child_count(),"shell plus transient material/node registrations remain bounded")
		var held_nodes: Array = []
		var material_refs: Array[WeakRef] = []
		for slot: Dictionary in fx.slots+fx.bursts:
			held_nodes.append(slot.node.get_instance_id())
			material_refs.append(weakref(slot.material))
		fx.reset()
		check(fx.get_child_count() == 0 and fx.factory.state().materials == 0,"reset frees all render nodes and registrations")
		for id: int in held_nodes: check(not is_instance_id_valid(id),"render node ID freed by reset")
		for ref: WeakRef in material_refs: check(ref.get_ref() == null,"render material freed by reset")
		var tied: Array = []
		var tie_winners: Array = []
		for id in range(capacity+4):
			tied.append(actor(id,{"temporaryShield":20}))
			if id < capacity: tie_winners.append(id)
		fx.apply_state(snapshot(tied),-1)
		check(owners() == tie_winners,"equal-distance protected actors use numeric ID tie-break")
		tied.reverse()
		fx.apply_state(snapshot(tied),-1)
		check(owners() == tie_winners,"reversed equal-distance roster retains the same winner set")
		fx.reset()

	# Quality shrink must only evict render ownership, never observation history.
	fx.set_quality(1)
	var large: Array = []
	for id in range(48): large.append(actor(id,{"protection":1.0,"z":-float(id)*0.1}))
	fx.apply_state(snapshot(large),-1)
	var high_nodes := node_ids()
	fx.set_quality(0)
	check(fx.tracks.size() == 48 and owners().size() == 16,"quality shrink preserves every observation")
	var freed := 0
	for id: int in high_nodes:
		if not is_instance_id_valid(id): freed += 1
	check(freed == 16 and fx.factory.state().materials == 16,"quality shrink frees exactly the excess nodes/material registrations")
	fx.set_quality(1)
	check(owners().size() == 32 and fx.counters.phase == 0,"quality increase reassigns without fabricated first-seen spawns")
	fx.reset()
	large.clear()
	for id in range(Controller.MAX_OBSERVATIONS+32): large.append(actor(id))
	large.append(actor(999,{"protection":1.0}))
	fx.apply_state(snapshot(large),-1)
	check(fx.tracks.size() == Controller.MAX_OBSERVATIONS and owners() == [999],"observation overflow is bounded and still prioritizes the sole shield")
	fx.free()
	camera.free()
	if not output.is_empty(): FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"assertions":assertions,"ordering_cases":results},"\t")+"\n")
	print("SHIELD_CAPACITY_%s assertions=%d" % ["OK" if not failed else "FAIL",assertions])
	quit(1 if failed else 0)
