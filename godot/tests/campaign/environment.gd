extends SceneTree
## Real Demo map/start lifecycle with AV deliberately absent. Terrain geometry
## is real; no gallery light, weather service or fixture light can mask omissions.
const Atmosphere = preload("res://campaign/environment.gd")
var failures: Array[String] = []

class Probe extends "res://campaign/demo.gd":
	func _ready() -> void:
		phase = -2
		add_child(camera)
		camera.make_current()
	func _process(_delta: float) -> void:
		pass
	func av_start(_frame: Dictionary) -> bool:
		return true # demonstrate composition independence from AV/weather
	func bind_vehicle_shots() -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)
		printerr(description)

func inspect(probe: Node, stage: String) -> void:
	var environments := root.find_children("*", "WorldEnvironment", true, false)
	var suns := root.find_children("*", "DirectionalLight3D", true, false)
	check(environments.size() == 1 and suns.size() == 1, stage + ": exactly one environment and sun in the scene")
	if environments.size() != 1 or suns.size() != 1: return
	var sky_node := environments[0] as WorldEnvironment
	var sun := suns[0] as DirectionalLight3D
	check(probe.world.is_ancestor_of(sky_node) and probe.world.is_ancestor_of(sun), stage + ": map owns both nodes")
	var env: Environment = sky_node.environment
	check(env != null and env.background_mode == Environment.BG_SKY and env.sky != null, stage + ": live sky background")
	if env == null or env.sky == null: return
	check(env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and env.ambient_light_energy >= 0.35, stage + ": explicit daylight ambient fill")
	check(sun.visible and sun.light_energy >= 0.5 and sun.shadow_enabled, stage + ": enabled daylight shadow sun")
	check(probe.camera.get_world_3d().environment == env, stage + ": effective world environment is the campaign sky")
	var material := env.sky.sky_material as ProceduralSkyMaterial
	check(material != null, stage + ": procedural daylight sky")
	if material != null: check(material.sky_top_color.get_luminance() > 0.35, stage + ": sky is daylight, not near black")

func run() -> void:
	var probe := Probe.new()
	root.add_child(probe)
	if not probe.catalog.open():
		check(false, probe.catalog.error)
		quit(1)
		return
	check(probe.load_map("rootfall-verge"), "real briefing world builds")
	await process_frame
	inspect(probe, "briefing")
	check(probe.camera.position.y > probe.world.height_at(probe.camera.position.x, probe.camera.position.z), "brief camera above terrain")
	var previous: WeakRef
	var revision := 0
	for id: String in ["rootfall-verge", "siltwake-crossing", "emberline-ascent", "crown-array"]:
		var frame := {"mapId":id,"geometryHash":probe.catalog.entries[id].geometryHash,"roundRevision":revision}
		probe.on_started(frame)
		await process_frame
		if previous != null: check(previous.get_ref() == null, id + ": previous chapter atmosphere retired")
		var atmosphere: Node = probe.world.get_node("CampaignEnvironment")
		check(atmosphere.map_id == id, id + ": daylight profile belongs to current chapter")
		var identity := atmosphere.get_instance_id()
		inspect(probe, id + " start")
		check(atmosphere.build(probe.world.recipe), id + ": idempotent build")
		for retry: int in range(3):
			probe.phase = 4 # death/results boundary followed by real same-map start
			revision += 1
			frame.roundRevision = revision
			probe.on_started(frame)
			await process_frame
			check(probe.world.get_node("CampaignEnvironment").get_instance_id() == identity, id + ": retry/start preserves atmosphere instance")
			inspect(probe, id + " retry %d" % retry)
		probe._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		probe._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		inspect(probe, id + " focus cycle / AV absent")
		previous = weakref(atmosphere)
	# Detached eager children are not composed by this probe's deliberately small
	# _ready. Free those explicitly; its camera/world are owned children.
	for node: Node in [probe.label, probe.selector, probe.combat_label, probe.pickups, probe.presentation, probe.combat,
		probe.client, probe.ground_tells, probe.robot_voices, probe.story_director]:
		if node != probe.client: node.free()
	# _exit_tree still needs the client; free it only after removing the probe.
	root.remove_child(probe)
	probe.client.free()
	probe.free()
	check(previous.get_ref() == null, "scene retirement frees final atmosphere")
	check(root.find_children("*", "WorldEnvironment", true, false).is_empty() and root.find_children("*", "DirectionalLight3D", true, false).is_empty(), "no leaked environment or sun")
	var invalid := Atmosphere.new()
	check(not invalid.build({"id":"unknown"}), "unknown atmosphere identity rejected")
	invalid.free()
	print("CAMPAIGN_ENVIRONMENT_OK" if failures.is_empty() else "CAMPAIGN_ENVIRONMENT_FAILED")
	quit(0 if failures.is_empty() else 1)
