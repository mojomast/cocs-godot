extends "res://world/catalog.gd"
const WORLD_ROOT := "res://multiplayer_worlds/generated/"
const MODES := {
 "parallax-observatory": ["deathmatch","teamdeathmatch","ctf","koth","uplink","holdout"],
 "switchyard-ward": ["deathmatch","teamdeathmatch","instagib","rockets","armsrace","ctf","domination","koth","uplink","holdout","assault"],
 "rainmarket-exchange": ["deathmatch","teamdeathmatch","instagib","rockets","armsrace","domination","koth","uplink","holdout","assault","payload"]
 ,"breakwater-exchange": ["deathmatch","teamdeathmatch","domination","assault","payload","combined-arms"]
 ,"thermal-divide": ["deathmatch","teamdeathmatch","instagib","rockets","armsrace","ctf","domination","koth","uplink","holdout","assault"]
 ,"sirocco-circuit": ["puma-race"]
 ,"copper-bowl": ["puma-soccer"]
 ,"tern-archipelago": ["cocs","cocs-coop"]
}
var recipes := {}

func open() -> bool:
 entries.clear()
 recipes.clear()
 error = ""
 for id: String in MODES:
  var path := WORLD_ROOT + id + ".json"
  if not FileAccess.file_exists(path):
   error = "Missing multiplayer world " + id
   return false
  var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
  if not data is Dictionary or data.get("schemaVersion") != 1 or data.get("id") != id or data.get("arena", {}).get("id") != id:
   error = "Invalid multiplayer world " + id
   return false
  if not data.get("geometryHash") is String or str(data.geometryHash).length() != 64:
   error = "Missing geometry identity " + id
   return false
  recipes[id] = data
  entries[id] = {"id":id,"name":data.name,"modes":MODES[id],"geometryHash":data.geometryHash,"sha256":FileAccess.get_sha256(path)}
 return true

func resolve_map(id: String) -> Dictionary:
 if not entries.has(id):
  error = "Unregistered multiplayer world " + id
  return {}
 var path := WORLD_ROOT + id + ".json"
 if FileAccess.get_sha256(path) != entries[id].sha256:
  error = "Multiplayer world changed after registration " + id
  return {}
 return recipes[id].arena
