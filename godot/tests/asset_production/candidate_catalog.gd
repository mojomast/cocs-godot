extends "res://multiplayer_worlds/catalog.gd"
## Direct-test scene only. Production catalog has no candidate/environment switch.
const PAIRS := {
	"vesper-viaduct": ["deathmatch","teamdeathmatch","ctf","domination","koth","uplink"],
	"abyssal-pressureworks": ["deathmatch","teamdeathmatch","ctf","koth","domination","holdout"],
	"stormglass-causeway": ["puma-race"]
}

func open() -> bool:
	entries.clear()
	recipes.clear()
	var id := ""
	var mode := ""
	var digest := ""
	var geometry := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): id = arg.trim_prefix("--map=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--candidate-sha="): digest = arg.trim_prefix("--candidate-sha=")
		if arg.begins_with("--candidate-geometry="): geometry = arg.trim_prefix("--candidate-geometry=")
	if not "--candidate-private" in OS.get_cmdline_user_args() or not PAIRS.has(id) or mode not in PAIRS[id]:
		error = "Unauthorized private candidate"
		return false
	var path := WORLD_ROOT + id + ".json"
	if digest.length() != 64 or FileAccess.get_sha256(path) != digest:
		error = "Candidate identity mismatch"
		return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data.get("id") != id or data.get("arena",{}).get("id") != id or data.get("geometryHash") != geometry or not data.arena.modeBindings.is_empty() or data.arena.candidateModes != PAIRS[id]:
		error = "Candidate geometry/admission mismatch"
		return false
	if not ResourceLoader.exists("res://multiplayer_worlds/art/worlds/" + id + ".glb"):
		error = "Candidate real exported/imported art missing"
		return false
	recipes[id] = data
	entries[id] = {"id":id,"name":data.name,"modes":[mode],"geometryHash":geometry,"sha256":digest}
	return true
