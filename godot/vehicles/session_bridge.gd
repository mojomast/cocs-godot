extends RefCounted
## Shared source-snapshot lease and wire-input adapter. No simulation or seat requests.
const Lease = preload("res://combined_arms/lease.gd")
var actor: Dictionary = {}
var vehicle: Dictionary = {}
var state: Dictionary = {}
var identity := ""
var jump_down := false

func reset() -> void:
	actor = {}
	vehicle = {}
	state = {}
	identity = ""
	# The owning input adapter clears held controls at this boundary and requires
	# a fresh physical press; do not carry a stale edge into the next round.
	jump_down = false

func observe(value: Dictionary, actor_id: int) -> bool:
	var was_mounted := mounted()
	state = value
	actor = Lease.actor_for(state, actor_id)
	vehicle = Lease.vehicle_for(state, actor)
	var next := "%s/%s/%s/%s/%s/%s" % [actor_id, actor.get("vehicleId"), actor.get("vehicleSeat"), actor.get("vehicleSeatIndex"), vehicle.get("id"), Lease.alive(actor)]
	# Infantry life/identity transitions belong to the infantry lifecycle. Only
	# mounted transitions invalidate this separate vehicle input lease.
	var changed := next != identity and (was_mounted or mounted())
	identity = next
	return changed

func eligible(actor_id: int, age: float, active: bool, spectating: bool) -> bool:
	return active and not spectating and actor_id >= 0 and actor.get("id") == actor_id and Lease.permitted(state, actor, vehicle, age)

func mounted() -> bool:
	return actor.get("vehicleId") != null

func adapt(packet: Dictionary, allowed: bool, jump_is_edge: bool = false) -> Dictionary:
	var result := packet.duplicate()
	var jump: bool = packet.get("jump", false)
	result.jump = allowed and jump and (jump_is_edge or not jump_down)
	jump_down = jump
	if not allowed or (mounted() and vehicle.is_empty()):
		for field: String in result:
			if result[field] is bool: result[field] = false
		result.x = 0.0
		result.z = 0.0
		result.erase("weapon")
		return result
	if not mounted(): return result
	var seat: String = actor.get("vehicleSeat", "")
	if seat != "driver":
		result.x = 0.0
		result.z = 0.0
		result.jump = false
		result.sprint = false
		result.crouch = false
	if seat != "passenger":
		for field in ["ads", "reload", "altFire", "melee", "grenade", "mobility", "power"]: result[field] = false
		result.erase("weapon")
	if seat == "driver" and vehicle.get("gunner") != null: result.fire = false
	return result

func crew_visibility(presentation: Node) -> void:
	# Source mounted actors are still individually targetable. Their snapshot seat
	# anchors are already drawn by Presentation; never blanket-hide hull riders.
	for member: Dictionary in state.get("actors", []):
		if not Lease.vehicle_for(state, member).is_empty() and presentation.actors.has(int(member.id)):
			presentation.actors[int(member.id)].visible = int(member.id) != presentation.local_actor_id and Lease.alive(member)
