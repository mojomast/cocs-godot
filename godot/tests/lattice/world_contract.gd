extends SceneTree
const Demo = preload("res://lattice/world_demo.gd")
const Transport = preload("res://lattice/world_transport.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
	print("WORLD_CHECK ", message, " ", value)

func wire(c: Node, frame: Dictionary) -> bool:
	return c.decode_text(JSON.stringify(frame))

func _initialize() -> void:
	var demo := Demo.new()
	var c: Node = demo.client
	demo.current_id = "asterion-relay"
	c.allowlist = {"asterion-relay":{"modes":["cocs"]}}
	c.requested_map = demo.current_id
	c.lobby.connect(demo.on_lobby)
	c.started.connect(demo.on_started)
	c.snapshot.connect(demo.on_snapshot)
	c.results.connect(demo.on_results)
	# Avoid geometry lookup in this detached state/control contract fixture.
	demo.lattice_hud.heights["front-0"] = 0.0
	wire(c, {"type":"welcome", "v":3, "roomId":"fixture", "peerId":1})
	wire(c, {"type":"lobby", "players":[{"peerId":1,"actorId":0}]})
	wire(c, {"type":"start", "mapId":demo.current_id, "config":{"mode":"cocs"}, "roundRevision":1})
	var actor := {"id":0,"team":0,"x":-100,"y":2,"z":4,"yaw":1,"pitch":0,"health":100,"eyeHeight":1.45}
	var other: Dictionary = actor.duplicate(true)
	other.id = 1
	other.x = -90
	var state := {"mapId":demo.current_id,"actors":[actor,other],"cocs":{"roundRevision":1,"nodes":[{"id":"front-0","x":-52,"z":-8,"owner":null,"progress":[0,0]}],"flux":{"1":99}}}
	check(wire(c, {"type":"snapshot","seq":1,"state":state,"acks":{"0":4}}), "valid wire accepted")
	check(demo.received_pose and demo.can_capture_pointer(), "owned living pose enables capture")
	check(demo.camera.position.is_equal_approx(Vector3(-100,3.45,4)), "camera uses exact source eye position")
	check(c.projection.flux == null and c.projection.req == null, "withheld wallets remain unknown")
	check(demo.presentation.actors.size() == 2, "only received actors rendered")
	demo._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var yaw_before: float = demo.yaw
	demo.update_look(Vector2(100,30))
	check(not demo.can_capture_pointer() and demo.yaw == yaw_before, "focus loss blocks look/capture")
	demo._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	demo.snapshot_watch.advance(2)
	check(not demo.can_capture_pointer(), "stale pose blocks capture")
	state.actors = [actor]
	wire(c, {"type":"snapshot","seq":2,"state":state})
	check(demo.presentation.actors.size() == 1 and not demo.presentation.actors.has(1), "absent remote retired without reconstruction")
	state.erase("cocs")
	wire(c, {"type":"snapshot","seq":3,"state":state})
	check(not demo.received_pose and not demo.can_capture_pointer() and demo.presentation.actors.is_empty() and demo.lattice_hud.markers.is_empty(), "missing projection clears controls and visuals")
	state.cocs = {"roundRevision":1,"nodes":[]}
	wire(c, {"type":"snapshot","seq":4,"state":state})
	wire(c, {"type":"lobby","players":[]})
	check(c.actor_id == -1 and not demo.received_pose and demo.presentation.actors.is_empty(), "revoked owner cannot retain old pose")
	wire(c, {"type":"lobby","players":[{"peerId":1,"actorId":1}]})
	wire(c, {"type":"snapshot","seq":5,"state":state})
	check(not demo.can_capture_pointer(), "new owner absent from snapshot cannot borrow actor zero")
	var invalid := {"type":"snapshot","seq":6,"state":state.duplicate(true)}
	invalid.state.actors = ["not an actor"]
	check(not c.valid_envelope(invalid), "typed actor consumer guarded")
	invalid.state.actors = [actor.duplicate(true)]
	invalid.state.actors[0].x = INF
	check(not c.valid_envelope(invalid), "nonfinite pose rejected")
	invalid.state.actors = [actor,actor]
	check(not c.valid_envelope(invalid), "duplicate actor identity rejected")
	invalid.state.actors = [actor]
	invalid.state.cocs.nodes = [{"id":"node","x":0,"z":0,"progress":"bad"}]
	check(not c.valid_envelope(invalid), "malformed objective projection rejected")
	wire(c, {"type":"lobby","players":[{"peerId":1,"actorId":0}]})
	wire(c, {"type":"snapshot","seq":7,"state":state})
	state.over = true
	wire(c, {"type":"results","state":state})
	check(demo.phase == 4 and not demo.can_capture_pointer() and c.projection.is_empty(), "results reset control and private projection")
	wire(c, {"type":"start","mapId":demo.current_id,"config":{"mode":"cocs"},"roundRevision":2})
	check(not demo.received_pose and demo.presentation.actors.is_empty(), "restart requires fresh owned pose")
	demo.on_error("fixture disconnect")
	check(demo.phase == -1 and not demo.received_pose and c.actor_id == -1, "error disconnect clears identity/control")
	for node: Node in [demo.client,demo.camera,demo.sun,demo.environment,demo.label,demo.selector,demo.world_label,demo.combat_label,demo.pickups,demo.presentation,demo.combat,demo.lattice_hud]: node.free()
	demo.free()
	print("WORLD_CONTRACT checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
