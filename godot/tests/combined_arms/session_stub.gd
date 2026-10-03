extends "res://world/session.gd"
## Exercises the real shared session's vehicle hooks without opening a socket.
func _ready() -> void:
	# The production _ready owns these eagerly constructed nodes. This fixture
	# skips network startup, but must still own and release their resources.
	for node in [camera,label,selector,environment,sun,combat,combat_label,pickups,client,presentation]:
		if node is Node and node.get_parent()==null: add_child(node)
