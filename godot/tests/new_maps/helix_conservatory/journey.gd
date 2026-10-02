extends "res://multiplayer_worlds/demo.gd"
## Test-only native driver. Real Input events -> ordinary session input sampler
## -> production WebSocket -> source simulation -> native snapshot/HUD.
var helix_out := ""
var guide_url := ""
var request: HTTPRequest
var requesting := false
var guide_elapsed := 0.0
var capture_elapsed := 0.0
var capture_index := 0
var finished := false
var guide_frames := 0
var input_events := 0
var native_events := {}
var budget_started := 0
var frame_times: Array[float] = []
var guide := {}
var capture_times: Array[int] = []
func _ready() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--helix-out="): helix_out=arg.trim_prefix("--helix-out=")
  if arg.begins_with("--helix-guide="): guide_url=arg.trim_prefix("--helix-guide=")
 get_window().size=Vector2i(760,520)
 get_window().content_scale_factor=1.5
 get_viewport().scaling_3d_scale=.5
 request=HTTPRequest.new()
 add_child(request)
 request.request_completed.connect(on_guide)
 budget_started=Time.get_ticks_msec()
 super._ready()
 # Explicit software-renderer capture preset; geometry/materials stay production.
 sun.shadow_enabled=false
 client.events.connect(func(items: Array) -> void:
  for item: Dictionary in items:
   var key: String=str(item.get("type","unknown"))
   native_events[key]=int(native_events.get(key,0))+1)
func on_lobby(frame: Dictionary) -> void:
 if phase==1:
  client.send_frame({"type":"host","mapId":"helix-conservatory","config":{"mode":selected_mode,"botCount":0,"timeLimit":900,"fragLimit":1 if selected_mode=="ctf" else 5,"startingWeapon":2,"unlimitedAmmo":true}})
  phase=2
  return
 if phase==2 and frame.get("players",[]).size()<2: return
 super.on_lobby(frame)
func key(code: int, pressed: bool) -> void:
 var event := InputEventKey.new()
 event.keycode=code
 event.physical_keycode=code
 event.pressed=pressed
 Input.parse_input_event(event)
 input_events+=1
func mouse(pressed: bool) -> void:
 var event := InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_LEFT
 event.pressed=pressed
 event.position=Vector2(480,200)
 Input.parse_input_event(event)
 input_events+=1
func _process(delta: float) -> void:
 super._process(delta)
 if finished: return
 if Time.get_ticks_msec()-budget_started>210000: fail("native journey watchdog"); return
 if not startup_error.is_empty(): fail(startup_error); return
 if phase==4:
  finished=true
  key(KEY_W,false)
  mouse(false)
  get_window().size=Vector2i(760,520)
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(helix_out.path_join("results.png"))
  get_window().size=Vector2i(1280,800)
  get_window().content_scale_factor=1.0
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(helix_out.path_join("results-normal.png"))
  frame_times.sort()
  var cadence := FileAccess.open(helix_out.path_join("capture-times.json"),FileAccess.WRITE)
  cadence.store_string(JSON.stringify({"monotonicMs":capture_times,"window":[760,520],"uiScale":150,"capture":"every rendered gameplay frame"}))
  var report := {"map":current_id,"mode":selected_mode,"geometryHash":expected_hash,"roundResults":round_results,"objectiveText":objective_text.text,"guideFrames":guide_frames,"inputEvents":input_events,"captures":capture_index,"nativeEvents":native_events,"lastAck":client.last_ack,"renderer":RenderingServer.get_video_adapter_name(),"drawCalls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"frameMsP50":frame_times[frame_times.size()/2] if not frame_times.is_empty() else 0,"frameMsP95":frame_times[int(frame_times.size()*.95)] if not frame_times.is_empty() else 0,"failures":[]}
  var file := FileAccess.open(helix_out.path_join("native-journey.json"),FileAccess.WRITE)
  file.store_string(JSON.stringify(report,"  "))
  print("HELIX_NATIVE_JOURNEY_OK ",JSON.stringify(report))
  client.disconnect_server()
  get_tree().quit()
  return
 if phase!=3 or not received_pose: return
 frame_times.append(delta*1000)
 guide_elapsed+=delta
 capture_elapsed+=delta
 if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED and can_capture_pointer(): mouse(true); mouse(false)
 if guide_elapsed>=.08 and not requesting:
  guide_elapsed=0
  requesting=true
  if request.request(guide_url+"/guide")!=OK: fail("guide request rejected")
 if capture_elapsed>=0.0:
  capture_elapsed=0
  capture_index+=1
  capture_frame(capture_index)
func capture_frame(index: int) -> void:
 await RenderingServer.frame_post_draw
 capture_times.append(Time.get_ticks_msec())
 get_viewport().get_texture().get_image().save_png(helix_out.path_join("frame-%04d.png"%index))
func on_guide(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
 requesting=false
 if finished or phase!=3: return
 if code!=200: fail("guide HTTP "+str(code)); return
 var response: Variant=JSON.parse_string(body.get_string_from_utf8())
 if not response is Dictionary: fail("invalid guide"); return
 guide=response
 guide_frames+=1
 var desired_yaw := float(guide.get("yaw",yaw))
 var desired_pitch := float(guide.get("pitch",0.0))
 var event := InputEventMouseMotion.new()
 event.relative=Vector2(-wrapf(desired_yaw-yaw,-PI,PI),-(desired_pitch-pitch))/(.003*SettingsAccess.sensitivity())
 event.position=Vector2(480,200)
 Input.parse_input_event(event)
 input_events+=1
 key(KEY_W,bool(guide.get("move",false)))
 key(KEY_CTRL,bool(guide.get("crouch",false)))
 mouse(bool(guide.get("fire",false)))
func fail(note: String) -> void:
 if finished: return
 finished=true
 printerr("HELIX_NATIVE_JOURNEY_FAIL ",note)
 client.disconnect_server()
 get_tree().quit(1)
