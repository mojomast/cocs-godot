extends SceneTree
## Bounded first-person handling contract: authored anchors for all ten source
## weapons, carrier/charging cycles, authoritative reload feed handling and
## barrel heat micro-FX. Presentation only; no gameplay value is asserted.
const Rig = preload("res://first_person/rig.gd")
const Handling = preload("res://first_person/handling.gd")
const EPSILON := 0.000001
## Worst-case cosmetic displacement (plume rise plus puff half-extent) above the
## authored station, used when measuring clearance from the sight corridor.
const PLUME_BUDGET := 0.05
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

func barrel(rig: Node) -> Node3D:
	return rig.parts.get("barrel-assembly", rig.parts.get("shock-emitter", rig.parts.get("flak-barrel")))

func station(anchors: Dictionary) -> String:
	for name: String in ["Magazine","Cell","Drum","Feed"]:
		if anchors.has(name): return name
	return ""

## Unique public shot, exactly like the source event stream (ids never repeat
## inside a round, so the rig's bounded dedup accepts each one once).
func fire(rig: Node) -> void:
	volley += 1
	rig.apply_events([{"id":100000 + volley, "time":1000.0 + volley, "type":"shot", "actor":7, "weapon":rig.current_weapon}], 7)

func step(rig: Node, frames: int, delta: float = 1.0 / 60.0) -> void:
	for i: int in frames: rig.advance(delta)

func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	var rig := Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	var fx_root: Node3D = rig.viewport.get_node("WeaponHandlingFx")
	var haze: MeshInstance3D = fx_root.get_node("HeatHaze")
	check(is_instance_valid(fx_root) and is_instance_valid(haze), "handling FX root lives in the isolated viewport")
	var actor := {"id":7,"weapon":0,"health":100,"reloadDuration":2.0,"reloadTimer":1.0}
	for id: int in 10:
		rig.reset()
		actor.weapon = id
		rig.apply_actor(actor,true)
		step(rig,8,0.05)
		var info: Dictionary = rig.manifest.weapons[id]
		var anchors: Dictionary = info.anchors
		var handling: Dictionary = info.handling
		var feed_name := station(anchors)
		# 1. Authored anchor contract and measured rest error.
		check(anchors.has("Bolt") and anchors.has("Charging") and anchors.has("HeatZone"), "authored handling anchors weapon %d" % id)
		check(anchors.has("Ejection") == bool(handling.eject), "casing port only on mechanisms that have one weapon %d" % id)
		check(feed_name != "", "authored feed station weapon %d" % id)
		check(rig.anchors.Bolt.get_parent() == rig.parts["bolt"], "Bolt rides the reciprocating carrier weapon %d" % id)
		check(rig.anchors.Charging.get_parent() == rig.parts["bolt"], "Charging rides the reciprocating carrier weapon %d" % id)
		check(rig.anchors.HeatZone.get_parent() == barrel(rig), "HeatZone rides the moving barrel weapon %d" % id)
		check(rig.anchors[feed_name].get_parent() == rig.parts["feed"], "feed station rides the moving feed weapon %d" % id)
		if anchors.has("Ejection"):
			check(rig.anchors.Ejection.get_parent() == rig.weapon.find_child("weapon", true, false), "casing port stays on the receiver weapon %d" % id)
		check(handling.has("cycle") and handling.has("stroke") and handling.has("charge") and handling.has("reload") and handling.has("heat"), "handling profile exported weapon %d" % id)
		check(rig.handling.cycle_duration == float(handling.cycle) and rig.handling.cycle_stroke == float(handling.stroke), "rig consumes the exported cycle profile weapon %d" % id)
		var worst := 0.0
		for name: String in anchors:
			var authored: Array = anchors[name].weaponPosition
			var expected: Vector3 = rig.weapon.global_transform * Vector3(authored[0], authored[1], authored[2])
			worst = maxf(worst, expected.distance_to(rig.anchors[name].global_position))
		check(worst < 0.0001, "authored anchor rest error bounded weapon %d (%.7f m)" % [id,worst])
		# The authored stations must follow their assembly, not the bare body.
		var barrel_before: Vector3 = rig.anchors.HeatZone.global_position
		var bolt_before: Vector3 = rig.anchors.Bolt.global_position
		var eject_before: Vector3 = rig.anchors.Ejection.global_position if anchors.has("Ejection") else Vector3.ZERO
		rig.handling.advance(1.0 / 60.0, true, 0.5, 0.0, false)
		var hinge := float(handling.reload.hinge)
		if hinge > 0.0:
			check(rig.anchors.HeatZone.global_position.distance_to(barrel_before) > 0.01, "heat station follows the hinged barrel weapon %d" % id)
		else:
			check(rig.anchors.HeatZone.global_position.distance_to(barrel_before) < 0.02, "heat station stays on the barrel line weapon %d" % id)
		if anchors.has("Ejection"):
			check(rig.anchors.Ejection.global_position.distance_to(eject_before) < 0.001, "casing port holds its receiver station during reload weapon %d" % id)
		rig.handling.advance(1.0 / 60.0, false, 0.0, 0.0, false)
		check(rig.anchors.HeatZone.global_position.distance_to(barrel_before) < 0.001, "heat station reseats after reload weapon %d" % id)
		# 2. Carrier cycle: reaches the authored stroke, never overshoots, and
		#    returns exactly to the imported rest pose.
		var stroke := float(handling.stroke)
		var cycle := float(handling.cycle)
		var rest: Transform3D = rig.rest["bolt"]
		fire(rig)
		var peak := 0.0
		var dt := minf(1.0 / 240.0, cycle / 24.0)
		var span := maxf(cycle, Handling.CHARGE_TIME) * 1.2
		var frames := int(ceil(span / dt)) + 2
		for frame: int in frames:
			rig.advance(dt)
			var offset: float = rig.parts["bolt"].position.z - rest.origin.z
			peak = maxf(peak, offset)
			check(offset <= stroke + EPSILON, "carrier travel bounded weapon %d" % id)
			check(offset >= -EPSILON, "carrier cannot travel forward weapon %d" % id)
		check(rig.parts["bolt"].transform == rest, "carrier returns to imported rest weapon %d" % id)
		check(peak > stroke * 0.9, "carrier reaches the authored stroke weapon %d (%.5f/%.5f m)" % [id,peak,stroke])
		check(rig.handling.bolt_offset == 0.0 and rig.handling.charge_offset == 0.0, "both carrier channels retire weapon %d" % id)
		check(bolt_before.distance_to(rig.anchors.Bolt.global_position) < 0.02, "carrier returns the bolt station weapon %d" % id)
		# 3. Feed handling is a pure function of the authoritative window.
		var feed_rest: Transform3D = rig.rest["feed"]
		rig.handling.advance(1.0 / 60.0, false, 0.5, 0.0, false)
		check(rig.parts["feed"].transform == feed_rest, "feed stays seated without the authoritative reload weapon %d" % id)
		var maximum := 0.0
		var charge_seen := 0.0
		for sample: int in 101:
			var progress := sample / 100.0
			rig.handling.advance(1.0 / 60.0, true, progress, 0.0, false)
			var offset: Vector3 = rig.parts["feed"].transform.origin - feed_rest.origin
			maximum = maxf(maximum, absf(offset.y) + absf(offset.z))
			charge_seen = maxf(charge_seen, rig.handling.charge_offset)
			check(absf(offset.x) < EPSILON, "feed never drifts sideways weapon %d" % id)
			if progress == 0.0 or progress == 1.0:
				check(rig.parts["feed"].transform.is_equal_approx(feed_rest), "authoritative window edges hold the feed weapon %d" % id)
				check(rig.handling.magazine_curve == 0.0, "reload curve closed at the window edge weapon %d" % id)
		check(maximum > 0.02 or hinge > 0.0, "feed mechanism visibly moves inside the window weapon %d (%.4f m)" % [id,maximum])
		if float(handling.charge) > 0.0:
			check(charge_seen > 0.001, "charging handle racks inside the window weapon %d" % id)
		if hinge > 0.0:
			rig.handling.advance(1.0 / 60.0, true, 0.5, 0.0, false)
			check(absf(rig.parts["barrel-assembly"].rotation.x - rig.rest["barrel-assembly"].basis.get_euler().x) > 0.2, "break-action hinge opens inside the window weapon %d" % id)
		rig.handling.advance(1.0 / 60.0, false, 0.0, 0.0, false)
		check(rig.parts["feed"].transform == feed_rest, "reload cancel reseats the feed weapon %d" % id)
		if hinge > 0.0:
			check(rig.parts["barrel-assembly"].transform == rig.rest["barrel-assembly"], "break-action hinge closes outside the window weapon %d" % id)
		# 4. Charging handle: once on the first shot after a pause, silent under
		#    sustained fire, released inside its own pull.
		if float(handling.charge) > 0.0:
			var racks_before: int = rig.handling.racks
			fire(rig)
			step(rig,21)
			var racks_spent: int = rig.handling.racks
			check(racks_spent == racks_before + 1, "first shot racks the charging handle weapon %d" % id)
			for burst: int in 90:
				fire(rig)
				rig.advance(1.0 / 30.0)
			check(rig.handling.racks == racks_spent, "sustained fire does not re-rack weapon %d" % id)
			step(rig,60)
			fire(rig)
			step(rig,6)
			check(rig.handling.racks == racks_spent + 1, "first shot after a pause racks again weapon %d" % id)
			check(rig.handling.charge_offset > 0.0, "charging handle visibly pulled weapon %d" % id)
			step(rig,18)
			check(rig.handling.charge_offset == 0.0, "charging handle releases after its pull weapon %d" % id)
		# 5. Heat builds with sustained fire, cools when idle, stays bounded.
		for burst: int in 120:
			fire(rig)
			rig.advance(1.0 / 60.0)
		var cap := float(handling.heat.cap)
		check(rig.handling.heat <= cap + EPSILON and rig.handling.heat > 0.5, "sustained fire builds bounded heat weapon %d (%.3f)" % [id,rig.handling.heat])
		var hot := rig.handling.heat
		step(rig,300)
		check(rig.handling.heat < hot * 0.5, "idle barrel cools weapon %d" % id)
		step(rig,1200)
		check(rig.handling.heat < 0.01, "cold barrel holds no heat weapon %d" % id)
		# 6. Sight picture: no haze at settled ADS, and the micro-effect stays
		#    outside the reticle corridor by measured angle in hip and ADS.
		for burst: int in 60:
			fire(rig)
			rig.advance(1.0 / 60.0)
		var hip_angle := corridor_clearance(rig, haze, PLUME_BUDGET)
		var hip_need := corridor_threshold(rig)
		check(hip_angle > hip_need, "heat station outside the reticle corridor in hip weapon %d (%.2f/%.2f deg)" % [id,hip_angle,hip_need])
		rig.apply_aim(true)
		step(rig,120)
		# The session owns the aim FOV (source policy); the isolated viewport copies
		# it, so measure the corridor at the ADS magnification it actually renders.
		camera.fov = rig.get_aim_state(75.0).fov
		rig.advance(0)
		check(rig.aim_weight >= 0.98, "settled ADS weapon %d" % id)
		check(rig.handling.haze_alpha == 0.0 and not haze.visible, "no heat haze in the settled sight picture weapon %d" % id)
		# The settled sight picture suppresses every heat quad, so no plume can be
		# emitted there: measure the station itself, not the suppressed plume budget.
		var ads_angle := corridor_clearance(rig, haze, 0.0)
		var ads_need := corridor_threshold(rig)
		check(ads_angle > ads_need, "heat station outside the reticle corridor in ADS weapon %d (%.2f/%.2f deg)" % [id,ads_angle,ads_need])
		check(rig.anchors.HeatZone.global_position.distance_to(haze.global_position) < 0.001, "heat micro-effect locked to the authored station weapon %d" % id)
		rig.apply_aim(false)
		camera.fov = 75.0
		rig.advance(0)
		measured.append({"weapon":id,"name":info.name,"anchors":anchors.size(),"feed":feed_name,"casing_port":anchors.has("Ejection"),"cycle_s":cycle,"stroke_m":stroke,"rest_error_m":worst,"feed_travel_m":maximum,"hip_corridor_deg":hip_angle,"hip_need_deg":hip_need,"ads_corridor_deg":ads_angle,"ads_need_deg":ads_need})
	# 7. Fixed pool: sustained fire cannot allocate handling nodes.
	rig.reset()
	actor.weapon = 9
	rig.apply_actor(actor,true)
	step(rig,8,0.05)
	var mesh_nodes := 0
	for node: Node in fx_root.get_children(): if node is MeshInstance3D: mesh_nodes += 1
	check(mesh_nodes == 4, "fixed handling FX pool (1 haze + 3 puffs)")
	var weapon_meshes: int = rig.weapon.find_children("*", "MeshInstance3D").size()
	for burst: int in 600:
		fire(rig)
		rig.advance(1.0 / 60.0)
		check(rig.handling.active_puffs <= 3, "puff pool bounded")
		check(rig.handling.haze_alpha <= 0.161, "haze alpha bounded")
	var after := 0
	for node: Node in fx_root.get_children(): if node is MeshInstance3D: after += 1
	check(after == mesh_nodes, "no handling node growth under sustained fire")
	check(rig.weapon.find_children("*", "MeshInstance3D").size() == weapon_meshes, "no handling mesh added to the imported weapon")
	check(rig.handling.puffs_spawned > 0, "sustained fire emits bounded smoke")
	check(rig.handling.heat >= 0.99, "automatic fire reaches the heat cap")
	# 8. Lifecycle: death, spectator, focus/stale, switch and restart drain FX.
	fire(rig)
	rig.advance(1.0 / 60.0)
	check(rig.handling.bolt_offset > 0.0, "carrier mid-cycle before the reset")
	rig.apply_actor({"id":7,"weapon":9,"health":0},true)
	check(rig.handling.heat == 0.0 and rig.parts["bolt"].transform == rig.rest["bolt"], "death clears handling state")
	check(not haze.visible and rig.handling.active_puffs == 0 and rig.handling.haze_alpha == 0.0, "death clears handling FX")
	rig.apply_actor(actor,true)
	step(rig,8,0.05)
	for burst: int in 60:
		fire(rig)
		rig.advance(1.0 / 60.0)
	check(rig.handling.heat > 0.3, "heat rebuilds after recovery")
	rig.apply_actor({"id":7,"weapon":9,"health":100,"spectating":true},true)
	check(rig.handling.heat == 0.0 and not haze.visible, "spectator clears handling")
	rig.apply_actor(actor,true)
	step(rig,8,0.05)
	for burst: int in 60:
		fire(rig)
		rig.advance(1.0 / 60.0)
	rig.apply_actor(actor,false)
	check(rig.handling.heat == 0.0 and rig.parts["bolt"].transform == rig.rest["bolt"] and not haze.visible, "focus/stale gate clears handling")
	rig.apply_actor(actor,true)
	step(rig,8,0.05)
	fire(rig)
	rig.advance(0.005)
	check(rig.handling.bolt_offset > 0.0, "carrier mid-cycle before the switch")
	actor.weapon = 0
	rig.apply_actor(actor,true)
	check(rig.handling.bolt_offset == 0.0 and rig.handling.heat == 0.0 and rig.parts["bolt"].transform == rig.rest["bolt"], "weapon switch clears handling")
	check(not haze.visible and rig.handling.active_puffs == 0, "weapon switch clears handling FX")
	rig.advance(0.05)
	check(rig.showing and rig.current_weapon == 0 and rig.anchors.has("Ejection"), "fresh weapon exposes its own casing port")
	rig.reset()
	check(rig.handling.heat == 0.0 and rig.handling.active_puffs == 0 and not haze.visible, "round restart drains handling")
	rig.free()
	camera.free()
	print("FIRST_PERSON_HANDLING ", JSON.stringify({"checks":checks,"failures":failures,"weapons":measured}))
	quit(0 if failures.is_empty() else 1)

## Measured clearance of the heat micro-effect from the view axis: the angular
## distance from the camera forward ray to the station, minus the angular radius
## of the widest live cosmetic quad plus the authored plume budget. Must exceed
## the sight-corridor half-angle at the live FOV.
func corridor_clearance(rig: Node, quad: MeshInstance3D, budget: float) -> float:
	var eye: Vector3 = rig.weapon_camera.global_position
	var to_heat: Vector3 = rig.anchors.HeatZone.global_position - eye
	if to_heat.length() < 0.05: return -1.0
	var forward: Vector3 = -rig.weapon_camera.global_transform.basis.z
	var offset: float = rad_to_deg(forward.angle_to(to_heat.normalized()))
	var radius: float = rad_to_deg(atan2(maxf(quad.scale.x, quad.scale.y) * 0.5 + budget, to_heat.length()))
	return offset - radius

## The corridor half-angle at the live FOV: half of the 64 px reticle box at the
## tighter capture height (32 px of 320 px), so every capture size clears it.
func corridor_threshold(rig: Node) -> float:
	return rad_to_deg(atan(0.10 * tan(deg_to_rad(rig.weapon_camera.fov) * 0.5)))
