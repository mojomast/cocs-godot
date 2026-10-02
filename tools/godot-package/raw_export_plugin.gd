@tool
extends EditorPlugin
## Staged export-only hook: retain reviewed original bytes alongside imports.
var exporter: EditorExportPlugin

class RawExport extends EditorExportPlugin:
	var files: Dictionary = {}
	func _get_name() -> String:
		return "RecordedRawResources"
	func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://addons/package_raw/files.json"))
		if not value is Dictionary:
			push_error("PACKAGE_RAW_INVENTORY_INVALID")
			return
		files = value
	func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
		if not files.has(path): return
		if FileAccess.get_sha256(path) != files[path]:
			push_error("PACKAGE_RAW_RESOURCE_CHANGED " + path)
			return
		# remap=false preserves the usual imported resource too. Godot 4.5.2's
		# exporter otherwise writes only the remap/converted resource for imports.
		add_file(path, FileAccess.get_file_as_bytes(path), false)

func _enter_tree() -> void:
	exporter = RawExport.new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
