extends SceneTree
# Synthetic transport, real decoder/context sequencing. Runs on the old client
# too: the first acceptance assertion reproduces the specific fatal-notice bug.
const Network = preload("res://net/client.gd")
const NOTICE := "Match in progress — you joined as a spectator."
class Probe extends Network:
	var sent: Array = []
	func send_frame(frame: Dictionary) -> Error:
		if get("spectating") == true: return super.send_frame(frame)
		sent.append(frame)
		return OK
var checks := 0
var failures := 0
func check(value: bool, name: String) -> bool:
	checks += 1
	if not value:
		failures += 1
		push_error("LOBBY_SPECTATOR_CONTEXT " + name)
	return value
func fresh(join := true) -> Probe:
	var n := Probe.new()
	n.allowlist = {"meridian-exchange":{"modes":["teamdeathmatch"]}}
	n.requested_map = "meridian-exchange"
	if join: n.join_room("ROOM", "Guest")
	return n
func welcome() -> Dictionary:
	return {"type":"welcome","v":3,"peerId":7,"roomId":"ROOM","spectate":true,"host":false}
func roster() -> Dictionary:
	return {"type":"lobby","roomId":"ROOM","hostId":1,"mapId":"meridian-exchange","started":true,"roundRevision":1,"lifecycle":{"phase":"live"},"config":{"mode":"teamdeathmatch"},"players":[{"peerId":1,"connected":true,"spectate":false,"actorId":0},{"peerId":7,"connected":true,"spectate":true,"actorId":null}]}
func decode(n: Node, frame: Dictionary) -> bool:
	return n.decode_text(JSON.stringify(frame))
func notice(n: Node, message: String = NOTICE) -> bool:
	return decode(n,{"type":"error","message":message})
func snapshot() -> Dictionary:
	return {"type":"snapshot","seq":1,"acks":{"-1":999,"0":25},"state":{"mapId":"meridian-exchange","actors":[],"pickups":[]}}
func run_negative(name: String, w: Dictionary, r: Dictionary, join := true, message: String = NOTICE) -> void:
	var n := fresh(join)
	var accepted := decode(n,w) and decode(n,r) and notice(n,message)
	check(not accepted,name+" stays fatal")
	n.free()
func _initialize() -> void:
	var n := fresh()
	check(decode(n,welcome()) and decode(n,roster()),"valid welcome and full roster")
	if not check(notice(n),"known notice after validated active spectator join must be informational"):
		n.free()
		print("LOBBY_SPECTATOR_CONTEXT checks=",checks," failures=",failures)
		quit(1)
		return
	check(n.get("spectating") == true and n.actor_id == -1,"explicit spectator identity without actor")
	for type: String in ["input","host","start","create","join"]:
		check(n.send_frame({"type":type}) == ERR_UNAUTHORIZED,"spectator cannot queue "+type)
	check(not notice(n),"duplicate informational notice is fatal")
	n.free()
	for key: String in ["spectate","host","v","roomId","peerId"]:
		var w := welcome()
		w.erase(key)
		run_negative("missing welcome "+key,w,roster())
	for pair: Array in [["spectate",false],["spectate","true"],["host",true],["v",2],["roomId","OTHER"],["peerId",8],["reconnected",true]]:
		var w := welcome()
		w[pair[0]] = pair[1]
		run_negative("wrong welcome "+str(pair),w,roster())
	for pair: Array in [["spectate",false],["spectate",1],["connected",false],["connected","true"],["actorId",0],["peerId",8]]:
		var r := roster()
		r.players[1][pair[0]] = pair[1]
		run_negative("wrong self roster "+str(pair),welcome(),r)
	for key: String in ["actorId","spectate","connected"]:
		var r := roster()
		r.players[1].erase(key)
		run_negative("missing self roster "+key,welcome(),r)
	for pair: Array in [["roomId","OTHER"],["mapId","other-map"],["started",false],["roundRevision",0],["lifecycle",{}],["lifecycle",{"phase":"results"}],["config",null],["config",{"mode":"unknown"}],["hostId",7],["players",[]]]:
		var r := roster()
		r[pair[0]] = pair[1]
		run_negative("wrong active context "+str(pair),welcome(),r)
	run_negative("no explicit join",welcome(),roster(),false)
	for message: String in ["room is full","spectator limit reached","Protocol version mismatch","Unknown error",NOTICE+" extra",NOTICE.to_lower(),"spectator"]:
		run_negative("other/extraneous notice "+message,welcome(),roster(),true,message)
	for boundary: String in ["before_welcome","before_roster","another_roster","start","snapshot","disconnect"]:
		n = fresh()
		if boundary != "before_welcome": decode(n,welcome())
		if boundary not in ["before_welcome","before_roster"]: decode(n,roster())
		match boundary:
			"another_roster": decode(n,roster())
			"start": decode(n,{"type":"start","mapId":"meridian-exchange"})
			"snapshot": decode(n,snapshot())
			"disconnect": n.disconnect_server()
		check(not notice(n),"notice outside adjacent handshake: "+boundary)
		n.free()
	for extra: String in ["code","roomId"]:
		n = fresh()
		decode(n,welcome()); decode(n,roster())
		var extended := {"type":"error","message":NOTICE}
		extended[extra] = "protocol-mismatch" if extra == "code" else "OTHER"
		check(not decode(n,extended),"extended error envelope not the known notice: "+extra)
		n.free()
	n = fresh()
	decode(n,welcome())
	decode(n,roster())
	notice(n)
	check(decode(n,{"type":"start","mapId":"meridian-exchange"}),"authoritative spectator start")
	check(decode(n,snapshot()) and n.last_ack == 0 and n.input_seq == 0 and n.actor_id == -1,"invalid ACK owner never adopted")
	decode(n,{"type":"results","state":{"mapId":"meridian-exchange"}})
	var r := roster()
	r.roundRevision = 2
	check(decode(n,r) and decode(n,{"type":"start","mapId":"meridian-exchange"}),"normal host restart remains valid")
	check(n.get("spectating") == true and n.actor_id == -1,"restart never promotes spectator")
	r.players[1].spectate = false
	r.players[1].actorId = 1
	check(not decode(n,r),"same connection cannot gain a player assignment")
	n.disconnect_server()
	check(n.get("spectating") == false,"explicit disconnect clears spectator state")
	check(n.join_room("ROOM") == OK,"fresh explicit join after disconnect")
	var player_welcome := welcome()
	player_welcome.spectate = false
	check(decode(n,player_welcome) and decode(n,r) and n.actor_id == 1 and n.get("spectating") == false,"only fresh non-spectator join can accept a player assignment")
	n.free()
	for kind: String in ["start","snapshot"]:
		n = fresh()
		decode(n,welcome()); decode(n,roster()); notice(n)
		var bad := {"type":"start","mapId":"other-map"} if kind == "start" else {"type":"snapshot","seq":1,"state":{"mapId":"other-map"}}
		check(not decode(n,bad),kind+" map substitution stays fatal")
		n.free()
	print("LOBBY_SPECTATOR_CONTEXT checks=",checks," failures=",failures," synthetic_transport=true")
	quit(1 if failures else 0)
