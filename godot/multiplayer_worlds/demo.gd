extends "res://world/session.gd"
const WorldCatalog = preload("res://multiplayer_worlds/catalog.gd")
const WorldMap = preload("res://multiplayer_worlds/map.gd")
const ZoneAdapter = preload("res://zone_modes/adapter.gd")
const ZoneRenderer = preload("res://zone_modes/renderer.gd")
const ObjectiveRenderer = preload("res://objectives/renderer.gd")
const AssaultState = preload("res://assault/state.gd")
const AssaultRenderer = preload("res://assault/renderer.gd")
var zones := ZoneAdapter.new()
var zone_renderer := ZoneRenderer.new()
var objective_renderer := ObjectiveRenderer.new()
var assault := AssaultState.new()
var assault_renderer := AssaultRenderer.new()
var objective_text := Label.new()
var evidence := false
var expected_hash := ""
var startup_error := ""
var auto_start := true
var fixture_retreat_elapsed := 0.0
var fixture_retreat_send := 0.0
var urban_guest_control_elapsed := 0.0
var urban_guest_control_send := 0.0
var urban_guest_control_count := 0
var urban_capture_path := ""
var urban_capture_queued := false

func urban_capture_objective() -> void:
 var review := Camera3D.new()
 review.fov = 74
 review.far = 300
 add_child(review)
 review.global_position = Vector3(14,10,18) if selected_mode == "ctf" else Vector3(-27,9,-17)
 review.look_at(Vector3(31,1,0) if selected_mode == "ctf" else Vector3(-34,0,-27))
 review.make_current()
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 var result := get_viewport().get_texture().get_image().save_png(urban_capture_path)
 if result != OK: push_error("Urban live objective screenshot failed: " + str(result))
 else: print("URBAN_NATIVE_CAPTURE ",urban_capture_path," ",expected_hash)
 review.queue_free()

func _process(delta: float) -> void:
 super._process(delta)
 if "--urban-fixture-move-guest" in OS.get_cmdline_user_args() and phase == 3:
  urban_guest_control_elapsed += delta
  urban_guest_control_send += delta
  if urban_guest_control_elapsed < 2.5 and urban_guest_control_send >= .05:
   urban_guest_control_send = 0.0
   if client.send_input({"x":-1.0 if selected_mode == "ctf" else 0.0,"z":0.0 if selected_mode == "ctf" else -1.0,"sprint":true}) == OK:
    urban_guest_control_count += 1
    if urban_guest_control_count in [1,30]: print("URBAN_NATIVE_CONTROL ",JSON.stringify({"map":current_id,"mode":selected_mode,"sent":urban_guest_control_count,"actor":client.actor_id}))
 if "--world-fixture-retreat" not in OS.get_cmdline_user_args() or phase != 3: return
 fixture_retreat_elapsed += delta
 fixture_retreat_send += delta
 if fixture_retreat_elapsed < 14.0 and fixture_retreat_send >= 0.05:
  fixture_retreat_send = 0.0
  client.send_input({"x":0.0,"z":1.0,"sprint":true})

func _init() -> void:
 catalog = WorldCatalog.new()

func _ready() -> void:
 add_child(camera)
 camera.far = 500
 camera.rotation_order = EULER_ORDER_YXZ
 camera.make_current()
 add_child(sun)
 add_child(environment)
 sun.rotation_degrees = Vector3(-44,-30,0)
 sun.light_energy = 1.25
 sun.shadow_enabled = true
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color("627985")
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("a0adb5")
 env.ambient_light_energy = 0.68
 environment.environment = env
 var layer := CanvasLayer.new()
 add_child(layer)
 var panel := VBoxContainer.new()
 panel.position = Vector2(16,12)
 panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 layer.add_child(panel)
 for control: Control in [label,selector,combat_label,objective_text]:
  panel.add_child(control)
  control.mouse_filter = Control.MOUSE_FILTER_IGNORE
 selector.hide()
 objective_text.custom_minimum_size.x = 600
 for child: Node in [pickups,presentation,combat,client,zone_renderer,objective_renderer,assault_renderer]: add_child(child)
 presentation.interpolate_remote = true
 if not catalog.open():
  on_error(catalog.error)
  return
 ids = catalog.entries.keys()
 var chosen := "switchyard-ward"
 selected_mode = "deathmatch"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--map="): chosen = arg.trim_prefix("--map=")
  if arg.begins_with("--mode="): selected_mode = arg.trim_prefix("--mode=")
  if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
  if arg.begins_with("--join-room="): join_room_id = arg.trim_prefix("--join-room=")
  if arg.begins_with("--bots="): selected_bot_count = arg.trim_prefix("--bots=").to_int()
  if arg == "--world-evidence": evidence = true
  if arg.begins_with("--urban-fixture-capture="): urban_capture_path = arg.trim_prefix("--urban-fixture-capture=")
  if arg == "--wait-for-peer": auto_start = false
 if not catalog.entries.has(chosen) or selected_mode not in catalog.entries[chosen].modes:
  on_error("Unsupported multiplayer world/mode")
  return
 if not load_map(chosen):
  on_error(catalog.error)
  return
 client.connection_error.connect(on_error)
 client.transport_dropped.connect(on_transport_dropped)
 client.lobby.connect(on_lobby)
 client.started.connect(on_started)
 client.snapshot.connect(on_snapshot)
 client.results.connect(on_results)
 client.events.connect(func(items: Array) -> void:
  if phase == 3:
   combat.apply_events(items,client.actor_id)
   av_events(items))
 if endpoint.is_empty():
  on_error("World scene requires a multiplayer authority endpoint")
  return
 connect_selected_match()

func load_map(id: String) -> bool:
 var data: Dictionary = catalog.recipes.get(id,{})
 if data.is_empty(): return false
 var next := WorldMap.new()
 next.name = "SelectedWorld"
 add_child(next)
 if not next.build(data):
  next.queue_free()
  return false
 if is_instance_valid(world):
  remove_child(world)
  world.free()
 world = next
 current_id = id
 expected_hash = str(data.geometryHash)
 return true

func on_lobby(frame: Dictionary) -> void:
 if "--world-fixture-three" in OS.get_cmdline_user_args() and phase == 1:
  # Direct scene-only bounded acceptance: two real native peers plus a third
  # wire-controlled human. No positions, objectives or scores are injected.
  var target := 3 if selected_mode == "assault" else 1
  if client.send_frame({"type":"host","mapId":current_id,"config":{"mode":selected_mode,"botCount":0,"timeLimit":900,"fragLimit":target}}) != OK:
   on_error("World fixture configuration could not be queued")
   return
  phase=2
  return
 if "--world-fixture-three" in OS.get_cmdline_user_args() and phase == 2 and frame.get("players",[]).size() < 3: return
 if not auto_start and phase == 2 and frame.get("players",[]).size() < 2: return
 super.on_lobby(frame)

func on_started(frame: Dictionary) -> void:
 if str(frame.get("geometryHash","")) != expected_hash:
  on_error("Multiplayer world geometry differs from authority")
  return
 zones.clear()
 zone_renderer.clear_round()
 objective_renderer.clear_round()
 assault.clear_round()
 assault_renderer.clear_round()
 super.on_started(frame)
 if selected_mode in ["ctf","payload"]: objective_renderer.configure_map(catalog.resolve_map(current_id), selected_mode)

func on_snapshot(frame: Dictionary) -> void:
 if phase != 3: return
 super.on_snapshot(frame)
 if selected_mode in ["ctf","payload"]:
  objective_renderer.apply_state(frame.state,client.actor_id)
  objective_text.text = objective_renderer.hud_text
 elif selected_mode == "assault":
  if assault.apply_state(frame.state):
   assault_renderer.apply_sector(assault.active_sector())
   objective_text.text = assault.text(presentation.local_actor.get("team"),false)
 elif selected_mode in ["domination","koth","uplink","holdout","combined-arms"]:
  if zones.apply(frame.state,client.actor_id,current_id,selected_mode):
   zone_renderer.apply(zones.projection)
   objective_text.text = "%s / %s | score %s" % [current_id,selected_mode,str(zones.projection.scores)]
 if evidence:
  print("WORLD_NATIVE ",JSON.stringify({"map":current_id,"mode":selected_mode,"hash":expected_hash,"round":round_starts,"peer":client.peer_id,"actor":client.actor_id,"ack":client.last_ack,"phase":phase,"state":frame.state.get("objectives",{})}))
 if not urban_capture_path.is_empty() and not urban_capture_queued:
  urban_capture_queued = true
  urban_capture_objective()

func on_results(frame: Dictionary) -> void:
 if evidence: print("WORLD_NATIVE_RESULTS ",JSON.stringify({"map":current_id,"mode":selected_mode,"hash":expected_hash,"peer":client.peer_id,"winner":frame.state.get("winner"),"state":frame.state.get("objectives",{})}))
 av_snapshot(frame.state)
 av_finish(frame.state)
 round_results += 1
 phase = 4
 presentation.apply_state(frame.state,client.actor_id)
 pickups.apply_state(frame.state)
 objective_renderer.apply_state(frame.state,client.actor_id)
 release_pointer()
 label.text = "Round ended · Enter: restart as host"
 if "--urban-fixture-restart" in OS.get_cmdline_user_args() and join_room_id.is_empty() and round_results == 1:
  get_tree().create_timer(2.0).timeout.connect(func() -> void: debug_restart())

func on_error(message: String) -> void:
 startup_error = message
 super.on_error(message)
