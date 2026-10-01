extends SceneTree
## Stream one authoritative JSONL snapshot and PNG at a time; fixed 24 fps.
var source := ""
var output := ""
var limit := 0
var session: Node

func _initialize() -> void:
 seed(420930)
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--trailer-source="): source = arg.trim_prefix("--trailer-source=")
  if arg.begins_with("--trailer-output="): output = arg.trim_prefix("--trailer-output=")
  if arg.begins_with("--trailer-limit="): limit = int(arg.trim_prefix("--trailer-limit="))
 call_deferred("run")

func run() -> void:
 var file := FileAccess.open(source, FileAccess.READ)
 if file == null or output.is_empty():
  push_error("Trailer requires readable source and output directory")
  quit(1)
  return
 var header: Dictionary = JSON.parse_string(file.get_line())
 var shot: Dictionary = header.shot
 root.size = Vector2i(960, 540)
 Engine.max_fps = 24
 session = load("res://tests/campaign/trailer_session.gd").new()
 root.add_child(session)
 current_scene = session
 session.client.actor_id = 0
 session.client.set_process(false)
 session.presentation.interpolate_remote = false
 session.on_started({"mapId":shot.map,"geometryHash":header.geometryHash,"inputEpoch":1})
 session.campaign_hud.hide_brief()
 session.camera.fov = 65
 # Let all production nodes initialize before starting the frame clock.
 for i: int in range(4): await process_frame
 var index := 0
 while not file.eof_reached():
  var line := file.get_line()
  if line.is_empty(): continue
  var record: Dictionary = JSON.parse_string(line)
  session.client.last_ack = int(record.acks["0"])
  session.on_snapshot({"state":record.state})
  session.ground_tells.apply_events(record.events)
  session.combat.apply_events(record.events, 0)
  if session.phase != 3:
   push_error("Trailer production session rejected replay")
   quit(1)
   return
  var t := float(index) / maxf(1.0, float(shot.seconds * 24 - 1))
  var focus := Vector3(header.focus.x, header.focus.y, header.focus.z)
  var fp: bool = shot.get("camera", "") == "fp"
  session.campaign_hud.visible = fp
  session.story_widgets.visible = shot.kind in ["npc", "pet"]
  if is_instance_valid(session.first_person):
   session.first_person.set_process(false)
   session.first_person.rig.apply_actor(session.presentation.local_actor, fp)
   session.first_person.rig.apply_events(record.events, 0)
  if fp:
   var actor: Dictionary = record.state.actors[0]
   session.camera.position = Vector3(actor.x, actor.y + float(actor.get("eyeHeight", 1.45)), actor.z)
   session.camera.rotation = Vector3(float(actor.pitch), float(actor.yaw), 0)
  else:
   var distance := 8.0
   var height := 2.8
   if shot.kind == "terrain":
    distance = 45.0
    height = float(shot.get("height", 15))
   elif shot.kind == "pet":
    distance = 3.4
    height = 1.4
   elif shot.kind == "npc":
    distance = 5.0
    height = 2.2
   elif shot.kind == "artillery":
    distance = 14.0
    height = 9.0
   var angle := lerpf(-0.45, 0.35, t)
   var eye := focus + Vector3(sin(angle) * distance, height, cos(angle) * distance)
   eye.y = maxf(eye.y, float(session.world.height_at(eye.x, eye.z)) + 1.2)
   session.camera.position = eye
   session.camera.look_at(focus + Vector3(0, 0.8, 0))
  await RenderingServer.frame_post_draw
  var error := root.get_texture().get_image().save_png(output.path_join("%06d.png" % index))
  if error != OK:
   push_error("Trailer frame write failed")
   quit(1)
   return
  index += 1
  if limit > 0 and index >= limit: break
  await process_frame
 file.close()
 print("TRAILER_CAPTURE_OK ", shot.id, " frames=", index)
 quit(0)
