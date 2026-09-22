extends "res://tests/combined_arms/observe.gd"
## Independent evidence only: inherited ordinary input route, passive identity,
## and requested small capture dimensions. No authority or product writes.
var round_revision := -1

func _initialize() -> void:
	super._initialize()
	demo.net.started.connect(func(frame: Dictionary) -> void:
		round_revision = int(frame.get("roundRevision", -1))
		print("INDEPENDENT_START ", JSON.stringify(frame)))

func sample() -> void:
	if demo.net.last_snapshot_seq == last_seq: return
	super.sample()
	print("INDEPENDENT_IDENTITY ", JSON.stringify({"seq":last_seq,
		"room":demo.net.room_id,"peer":demo.net.peer_id,"actor":demo.net.actor_id,
		"roundRevision":round_revision}))

func capture(size: Vector2i, label: String) -> void:
	if size.x == 960: size.y = 640
	await super.capture(size, label)
