extends SceneTree
## Instantiates the actual independent _ready compositions and emits the real
## Client.events signal. No server/synthetic direct AV service invocation.
const Assault = preload("res://tests/audio_new/assault_no_network.gd")
const Zone = preload("res://tests/audio_new/zone_no_network.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for kind: String in ["assault", "zone"]:
		var scene = Assault.new() if kind == "assault" else Zone.new()
		root.add_child(scene)
		assert(scene.phase == 0 and scene.current_id != "", kind + " production ready/map binding failed")
		var links: Array = scene.client.events.get_connections()
		assert(links.size() == 1, kind + " must have exactly one actual event listener")
		scene.av_start({"roundRevision":12})
		scene.client.actor_id = 7
		scene.phase = 3
		var beat := "assault-sector-captured" if kind == "assault" else "zone-capture"
		scene.client.events.emit([{"id":99,"type":beat,"team":0,"time":0.9}])
		assert(scene.audiovisual.status().routing.remembered_events == 1)
		assert(scene.audiovisual.status().last_cue_id == "", "pre-snapshot recipient is not inferred")
		scene.snapshot_watch.observe()
		scene.audiovisual.apply_snapshot({"time":1.0,"over":false,"config":{"mode":scene.selected_mode,"timeLimit":300},
			"actors":[{"id":7,"team":0,"health":100,"maxHealth":100,"vehicleId":null,"x":0.0,"z":0.0}],"vehicles":[]},7,true)
		scene.client.events.emit([{"id":100,"type":beat,"team":0,"time":1.0}])
		var status: Dictionary = scene.audiovisual.status()
		assert(status.routing.remembered_events == 2, kind + " listener did not reach audiovisual router")
		assert(status.last_cue_id == beat + ":100", kind + " objective was not presented")
		scene.client.events.emit([{"id":100,"type":beat,"team":0,"time":1.0}])
		status = scene.audiovisual.status()
		assert(status.routing.remembered_events == 2 and status.routing.dropped_duplicate == 1,
			kind + " one listener, duplicate wire ID dropped once")
		scene.free()
	print("INDEPENDENT_AUDIO_EVENTS_OK assault=1 zone=1")
	quit(0)
