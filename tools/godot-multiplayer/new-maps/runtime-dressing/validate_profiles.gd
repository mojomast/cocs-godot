extends SceneTree
## Headless validator for the runtime Moth dressing profiles.
##
## Runs profile.gd's own Profile.validate() - the exact authority the binder
## calls - so a profile that passes here cannot be rejected at map load.
##
## The assigned worktree is a sparse checkout that skips godot/material_language
## and godot/moth_scenery, and godot/project.godot registers autoloads that are
## also skipped, so this is normally run against a sandbox project that symlinks
## the needed res:// paths. See README.md in this directory.
##
##   godot --headless --path <sandbox> --script res://validate_profiles.gd -- vesper-viaduct abyssal-pressureworks stormglass-causeway

const Profile = preload("res://multiplayer_worlds/dressing/profile.gd")

func _initialize() -> void:
	var map_ids := PackedStringArray()
	for argument in OS.get_cmdline_user_args():
		map_ids.append(argument)
	if map_ids.is_empty():
		map_ids = PackedStringArray(Profile.IDENTITIES.keys())
	var failures := 0
	for map_id: String in map_ids:
		failures += _check(map_id)
	print("DRESSING_HEADLESS_FAILURES=%d" % failures)
	quit(1 if failures else 0)

func _check(map_id: String) -> int:
	var geometry_hash: String = Profile.IDENTITIES.get(map_id, "")
	if geometry_hash == "":
		printerr("FAIL %s: no Profile.IDENTITIES entry" % map_id)
		return 1
	var path := "res://multiplayer_worlds/dressing/profiles/" + map_id + ".json"
	if not FileAccess.file_exists(path):
		printerr("FAIL %s: %s is missing" % [map_id, path])
		return 1
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var errors: Array[String] = Profile.validate(parsed, map_id, geometry_hash)
	if not errors.is_empty():
		printerr("FAIL %s: %s" % [map_id, ", ".join(errors)])
		return 1
	var p: Dictionary = parsed
	var motes := 0
	for pocket: Dictionary in p.pockets: motes += int(pocket.count)
	print("PASS %s: materials=%d/%d panels=%d/%d signs=%d/%d motes=%d/%d preserve=%d" % [
		map_id, p.materials.size(), int(p.budgets.material_variants),
		p.panels.size(), int(p.budgets.panels),
		p.signs.size(), int(p.budgets.signs),
		motes, int(p.budgets.motes), p.preserve_materials.size()])
	return 0