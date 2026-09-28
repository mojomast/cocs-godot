extends SceneTree

class FakeClient extends Node:
	var connection_endpoint := ""
	var open := true
	func career_wire_open() -> bool: return open

var failed := false

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _initialize() -> void: call_deferred("run_checks")

func run_checks() -> void:
	var identity: Node = root.get_node("Identity")
	var endpoint := OS.get_environment("COCS_CAREER_ENDPOINT")
	var client := FakeClient.new()
	client.connection_endpoint = endpoint
	root.add_child(client)
	var path := OS.get_environment("COCS_CAREER_CREDENTIALS_PATH")
	var first := {"playerId":"11111111-1111-4111-8111-111111111111", "progressToken":"0123456789abcdef0123456789abcdef0123456789abcdef"}
	check(identity.request_fields(client).is_empty(), "initial identity must be empty")
	identity.accept_welcome(client, {"v":3,"profile":{"id":first.playerId},"progressToken":first.progressToken})
	check(identity.request_fields(client) == first, "welcome must persist the identity")
	check(FileAccess.get_unix_permissions(path) & 511 == 384, "credentials must be private")
	identity.clear_connection(client)
	client.connection_endpoint = "ws://unrelated.example:4000"
	check(identity.request_fields(client).is_empty(), "switched endpoint must not receive owned credentials")
	client.connection_endpoint = endpoint
	identity.accept_welcome(client, {"v":3,"profile":{"id":"22222222-2222-4222-8222-222222222222"},"progressToken":first.progressToken})
	check(identity.request_fields(client) == first, "late welcome must not replace identity")
	client.connection_endpoint = "ws://unrelated.example:4000"
	identity.accept_welcome(client, {"v":3,"profile":{"id":"22222222-2222-4222-8222-222222222222"},"progressToken":first.progressToken})
	client.connection_endpoint = endpoint
	check(identity.request_fields(client) == first, "wrong endpoint welcome must not replace identity")
	identity.clear_connection(client)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	identity.request_fields(client)
	identity.accept_welcome(client, {"v":3,"profile":{"id":"22222222-2222-4222-8222-222222222222"},"progressToken":first.progressToken})
	check(identity.status == "Career credentials are malformed", "malformed file must produce visible failure")
	var raw := FileAccess.get_file_as_string(path)
	check(raw == "{broken", "malformed credential file must remain untouched")
	quit(1 if failed else 0)
