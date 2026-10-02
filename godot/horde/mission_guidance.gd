extends RefCounted
## Read-only Blackwater mission projection. Distances are cues, never steering.
const NAMES := {"north-feeder":"NORTH FEEDER", "south-feeder":"SOUTH FEEDER", "switch-pump":"SWITCH PUMP", "relief-valve":"RELIEF VALVE"}

static func lock_reason(id: String, completed: Array, wave: int) -> String:
	if id == "switch-pump":
		if "north-feeder" not in completed or "south-feeder" not in completed: return "restore both feeders"
		if wave < 4: return "wave 4"
	if id == "relief-valve":
		if "switch-pump" not in completed: return "restore switch pump"
		if wave < 7: return "wave 7"
	return "await authority"

static func project(mission: Dictionary, stage: Dictionary, player: Dictionary) -> Dictionary:
	var completed: Array = mission.get("completed", [])
	var active := str(mission.get("active", ""))
	var rows: Array[Dictionary] = []
	var priority: Dictionary = {}
	var best := INF
	for value: Variant in mission.get("stations", []):
		if not value is Dictionary: continue
		var id := str(value.get("id", ""))
		if not NAMES.has(id): continue
		var distance := INF
		if not player.is_empty(): distance = Vector2(float(value.x)-float(player.x), float(value.z)-float(player.z)).length()
		var status := "COMPLETED" if id in completed else "RESTORING" if id == active else "AVAILABLE" if value.get("available", false) else "LOCKED"
		var row := {"id":id,"name":NAMES[id],"status":status,"distance":distance,"progress":float(value.get("progress",0)),"required":float(value.get("required",1)),"reason":lock_reason(id,completed,int(mission.get("wave",0)))}
		rows.append(row)
		var rank: float = -1.0 if status == "RESTORING" else distance if status == "AVAILABLE" else INF
		if rank < best: best = rank; priority = row
	var instruction := "All four systems restored · finish the waves"
	if not priority.is_empty():
		var range_text := " · %.0fm" % float(priority.distance) if is_finite(float(priority.distance)) else ""
		instruction = str(priority.name) + range_text
		if priority.status == "RESTORING":
			instruction += " · WORKING %.1f/%.1fs" % [priority.progress,priority.required]
			if float(priority.distance)>6.5: instruction += "\nReturn within 6.5m to resume"
			elif player.get("grounded",true) != true: instruction += "\nLand inside the repair area to resume"
			else: instruction += "\nDEFEND within 6.5m · no need to hold E"
		else:
			instruction += " · E TO ARM" if float(priority.distance)<=5.0 else " · approach within 5m, tap E"
			instruction += "\nStay grounded inside the repair area · %.1f/%.1fs" % [priority.progress,priority.required]
	elif completed.size()<4:
		for row: Dictionary in rows:
			if row.status == "LOCKED": instruction = str(row.name) + " LOCKED · " + str(row.reason); break
	var mask := int(stage.get("gateMask",0))
	var route := "SECTOR %s · WEST %s · EAST %s" % [str(stage.get("stageId","?")),"OPEN" if mask & 1 else "CLOSED","OPEN" if mask & 2 else "CLOSED"]
	var transit: Variant = stage.get("transit")
	if transit is Dictionary:
		route += "\nROUTE %s → %s · %s" % [str(transit.get("from","")),str(transit.get("to","")),"wait for floodgate" if transit.get("phase")=="warning" else "walk through the open floodgate"]
	return {"rows":rows,"priority":priority,"instruction":instruction,"route":route,"completed":completed.size()}
