class_name PortPickups
extends Node3D

# Native supply visuals, keyed by authority IDs (never array order).
# Snapshot wait controls visibility. No local countdown or collection authority.
const PickupVisual = preload("res://world/pickup_visual.gd")
var markers: Dictionary = {}

func clear_round() -> void:
	for marker: Node3D in markers.values():
		remove_child(marker)
		marker.free()
	markers.clear()

func apply_state(state: Dictionary) -> void:
	var present: Dictionary = {}
	for pickup: Dictionary in state.get("pickups", []):
		var id: int = int(pickup.id)
		present[id] = true
		if not markers.has(id):
			var marker := PickupVisual.new()
			marker.name = "Pickup_%d" % id
			add_child(marker)
			markers[id] = marker
		var node: Node3D = markers[id]
		node.apply_kind(str(pickup.kind))
		node.position = Vector3(pickup.x, float(pickup.get("y", 0)) + 1.0, pickup.z)
		node.visible = float(pickup.get("wait", 0)) <= 0
		node.set_meta("kind", str(pickup.kind))
	for id: int in markers.keys():
		if not present.has(id):
			var node: Node3D = markers[id]
			remove_child(node)
			node.free()
			markers.erase(id)
