extends SceneTree
## Decoded recipient transitions + actual neutral queue; no authority simulation.
const Demo = preload("res://lattice/world_demo.gd")
const Guidance = preload("res://lattice/world_guidance.gd")
class QueueProbe extends "res://lattice/world_transport.gd":
	var frames: Array[Dictionary] = []
	func connection_open() -> bool: return true
	func send_frame(frame: Dictionary) -> Error:
		frames.append(frame.duplicate(true))
		return OK

var checks := 0
var failures := 0
var demo: Node
var client: Node
var seq := 0
var actor := {"id":0,"team":0,"x":0,"y":0,"z":0,"yaw":0,"pitch":0,"health":100,"eyeHeight":1.45}
var node := {"id":"front","label":"FRONT","x":0,"z":-20,"owner":null,"progress":[0.25,0],"live":true}
var source := {"mapId":"asterion-relay"}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
	print("USABILITY_CHECK ", message, " ", ok)

func wire(frame: Dictionary) -> void:
	if not client.decode_text(JSON.stringify(frame)):
		failures += 1
		push_error("Fixture rejected")

func snapshot() -> void:
	seq += 1
	wire({"type":"snapshot","seq":seq,"state":source})
	demo.refresh_world_hud()

func status(id: String, eligible: bool) -> bool:
	return Guidance.control_state(demo).id == id and demo.can_capture_pointer() == eligible

func _initialize() -> void:
	demo = Demo.new()
	demo.client.free()
	demo.client = QueueProbe.new()
	client = demo.client
	demo.current_id = "asterion-relay"
	client.allowlist = {demo.current_id:{"modes":["cocs"]}}
	client.requested_map = demo.current_id
	client.lobby.connect(demo.on_lobby)
	client.started.connect(demo.on_started)
	client.snapshot.connect(demo.on_snapshot)
	client.results.connect(demo.on_results)
	demo.lattice_hud.heights.front = 0.0
	check(status("waiting", false), "no round means waiting and capture denied")
	wire({"type":"welcome","v":3,"roomId":"fixture","peerId":1})
	wire({"type":"lobby","players":[{"peerId":1,"actorId":0}]})
	wire({"type":"start","mapId":demo.current_id,"config":{"mode":"cocs"},"roundRevision":1})
	check(status("unavailable", false), "start does not borrow a previous pose")
	source.actors = [actor]
	source.cocs = {"roundRevision":1,"nodes":[node]}
	snapshot()
	check(status("released", true), "fresh healthy wire enables click but remains released")
	check(demo.world_label.text.contains("25%") and demo.world_label.text.contains("Neutral") and demo.world_label.text.contains("Ahead"), "source objective and camera-relative goal use decoded public state")
	var original: String = demo.world_label.text
	client.actions.append({"kind":"hold","status":"confirmed"})
	client.projection.command = {"executor":0,"leaseUntil":9999}
	demo.refresh_world_hud()
	check(demo.world_label.text == original and node.owner == null, "confirmed HOLD and executor lease cannot alter goal ownership/progress")
	demo._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	demo.refresh_world_hud()
	var neutral: Dictionary = client.frames.back().input
	check(status("unfocused", false) and demo.label.text.contains("UNFOCUSED"), "focus boundary labels update without a new snapshot")
	check(neutral.x == 0 and neutral.z == 0 and not neutral.fire and not neutral.jump and not neutral.reload and not neutral.sprint and not neutral.crouch and not neutral.interact and not neutral.mobility and not neutral.has("weapon"), "unfocused feedback corresponds to actual same-adapter neutral queue")
	demo._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(status("released", false) and demo.world_wait_release, "focus return requires release before recapture")
	demo.world_wait_release = false
	demo.snapshot_watch.advance(2)
	demo.refresh_world_hud()
	check(status("stale", false) and demo.world_label.text.is_empty(), "stale state cannot keep showing actionable old objective guidance")
	snapshot()
	actor.health = 0
	actor.dead = 2.5
	snapshot()
	check(status("dead", false) and demo.label.text.contains("2.5s") and demo.world_label.text.is_empty(), "decoded death shows source respawn timer and hides goals")
	actor.dead = 0
	snapshot()
	check(status("dead", false), "zero timer with zero health does not claim living actor")
	actor.health = 100
	snapshot()
	check(status("released", true), "healthy respawn remains released until fresh click")
	node.owner = 0
	node.progress = [0,0]
	snapshot()
	check(demo.world_label.text.contains("Source node: Team 0") and demo.world_label.text.contains("0%"), "only received ownership transition updates source node label")
	node.erase("progress")
	node.erase("live")
	snapshot()
	check(demo.world_label.text.contains("progress unknown") and demo.world_label.text.contains("activity unknown") and demo.world_label.text.contains("FLUX unknown"), "withheld progress/activity/wallet remain unknown")
	source.erase("cocs")
	snapshot()
	check(status("unavailable", false) and demo.world_label.text.is_empty() and demo.lattice_hud.nearest.is_empty(), "missing projection clears goal and control together")
	source.cocs = {"roundRevision":1,"nodes":[node]}
	snapshot()
	wire({"type":"lobby","players":[]})
	demo.refresh_world_hud()
	check(status("unavailable", false) and demo.world_label.text.is_empty(), "revoked recipient cannot retain goal")
	wire({"type":"results","state":source})
	demo.refresh_world_hud()
	check(status("results", false) and demo.label.text.contains("Enter") and demo.world_label.text.is_empty(), "results replaces approach with restart instruction")
	demo.on_error("fixture disconnect")
	demo.refresh_world_hud()
	check(status("stopped", false) and demo.world_label.text == "fixture disconnect", "disconnect preserves error and releases controls")
	# Compare with real camera basis at several yaws, including wrapping.
	var bearings_ok := true
	for yaw: float in [0.0, PI / 2, -PI / 2, PI, 2.8]:
		var basis := Basis(Vector3.UP, yaw)
		for entry: Array in [[basis.x,"Right"],[-basis.x,"Left"],[-basis.z,"Ahead"],[basis.z,"Behind"]]:
			var offset: Vector3 = entry[0] * 20
			bearings_ok = bearings_ok and Guidance.bearing(actor, {"x":offset.x,"z":offset.z}, yaw) == entry[1]
	check(bearings_ok, "20 camera-basis bearings remain correct under yaw")
	var hud: Node = demo.lattice_hud
	var own := {"id":"hq","x":0,"z":-1,"owner":0,"live":false}
	var inactive := {"id":"inactive","x":0,"z":-2,"owner":null,"live":false}
	var far_live := {"id":"far","x":0,"z":-80,"owner":1,"live":true}
	var near_live := {"id":"near","x":0,"z":-30,"owner":null,"live":true}
	var objectives := {"team":0,"nodes":[own,inactive,far_live,near_live]}
	hud.apply_projection(objectives, actor)
	check(hud.nearest.id == "hq" and hud.approach_node(objectives, actor).id == "near", "approach prefers nearest live non-owned node over inactive headquarters")
	near_live.owner = 0
	check(hud.approach_node(objectives, actor).id == "far", "public capture retargets guidance to next live non-owned node")
	far_live.live = false
	check(hud.approach_node(objectives, actor).id == "hq", "no live candidate falls back to known nearest without inventing eligibility")
	hud.clear_round()
	var coop := {"team":0,"coop":true,"recruitment":{}}
	check(hud.text(coop).contains("Wave unknown") and hud.text(coop).contains("window unknown"), "missing co-op context is not a fabricated wave or closed window")
	coop.recruitment = {"wave":2,"phase":"intermission","open":true}
	check(hud.text(coop).contains("Wave 2") and hud.text(coop).contains("window open"), "co-op context reflects supplied public fields")
	for item: Node in [client,demo.camera,demo.sun,demo.environment,demo.label,demo.selector,demo.world_label,demo.combat_label,demo.pickups,demo.presentation,demo.combat,demo.lattice_hud]: item.free()
	demo.free()
	print("USABILITY_CONTRACT checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
