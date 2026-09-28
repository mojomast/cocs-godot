extends Node

# Credentials are capability material, never a profile cache. The source-backed
# welcome/profile frames alone supply XP, unlocks and gear to Career.
var _file_path := ""
var _scope := ""
var _endpoint := ""
var _active: Dictionary = {}
var _pending: Dictionary = {}
signal storage_error(message: String)
var status := ""

func _ready() -> void:
	_file_path = OS.get_environment("COCS_CAREER_CREDENTIALS_PATH")
	_scope = OS.get_environment("COCS_CAREER_SCOPE")
	_endpoint = OS.get_environment("COCS_CAREER_ENDPOINT")
	if _file_path.is_empty() or _scope.is_empty() or _endpoint.is_empty() or not _file_path.is_absolute_path(): return
	var data := _load()
	if data.is_empty(): return
	var value: Variant = data.scopes.get(_scope)
	if _valid_pair(value): _active = value.duplicate()

func _valid_pair(value: Variant) -> bool:
	return value is Dictionary and value.get("playerId") is String and value.get("progressToken") is String and value.playerId.length() >= 8 and value.playerId.length() <= 64 and value.progressToken.length() >= 16 and value.progressToken.length() <= 128 and _valid_chars(value.playerId, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-") and _valid_chars(value.progressToken, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")

func _valid_chars(value: String, allowed: String) -> bool:
	for i in value.length():
		if allowed.find(value[i]) < 0: return false
	return true

func _load() -> Dictionary:
	if not FileAccess.file_exists(_file_path):
		storage_failure("Career credentials are missing")
		return {}
	var file := FileAccess.open(_file_path, FileAccess.READ)
	if file == null or file.get_length() > 262144:
		storage_failure("Career credentials cannot be read")
		return {}
	var decoder := JSON.new()
	if decoder.parse(file.get_as_text()) != OK:
		storage_failure("Career credentials are malformed")
		return {}
	var value: Variant = decoder.data
	if not value is Dictionary or value.get("version") != 1 or not value.get("scopes") is Dictionary:
		storage_failure("Career credentials are malformed")
		return {}
	return value

func storage_failure(message: String) -> void:
	status = message
	storage_error.emit(message)

# Called only for a supervisor-admitted source-backed or explicitly scoped
# external endpoint. A bare direct engine invocation has no credential scope.
func request_fields(client_or_endpointScope: Variant) -> Dictionary:
	if _scope.is_empty() or _file_path.is_empty() or _endpoint.is_empty(): return {}
	if client_or_endpointScope is String and client_or_endpointScope != _scope: return {}
	if client_or_endpointScope is Node:
		if client_or_endpointScope.get("connection_endpoint") != _endpoint or not client_or_endpointScope.career_wire_open(): return {}
		_pending[client_or_endpointScope.get_instance_id()] = _scope
	else: return _active.duplicate() if client_or_endpointScope is String else {}
	return _active.duplicate()

func clear_connection(client: Node) -> void:
	_pending.erase(client.get_instance_id())

func accept_welcome(client: Node, frame: Dictionary) -> void:
	if _scope.is_empty() or _pending.get(client.get_instance_id()) != _scope or client.get("connection_endpoint") != _endpoint or not client.career_wire_open(): return
	_pending.erase(client.get_instance_id())
	if frame.get("v") != 3 or not frame.get("profile") is Dictionary: return
	var pair := {"playerId":frame.profile.get("id"), "progressToken":frame.get("progressToken")}
	if not _valid_pair(pair): return
	var data := _load()
	if data.is_empty(): return
	var scopes: Dictionary = data.scopes
	if not scopes.has(_scope) and scopes.size() >= 32:
		storage_failure("Career server identity limit reached")
		return
	scopes[_scope] = pair
	var temp := _file_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		storage_failure("Career credentials could not be saved")
		return
	if OS.get_name() in ["Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		if FileAccess.set_unix_permissions(temp, 384) != OK:
			file.close()
			DirAccess.remove_absolute(temp)
			storage_failure("Career credentials could not be secured")
			return
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temp)
		storage_failure("Career credentials could not be saved")
		return
	if DirAccess.rename_absolute(temp, _file_path) == OK:
		_active = pair
		status = ""
	else: storage_failure("Career credentials could not be saved")
