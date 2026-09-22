extends SceneTree

const FX = preload("res://graphics_fx/moth_world.gd")
const Fixtures = preload("res://tests/graphics_fx/fixture_library.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var fx := FX.new()
	root.add_child(fx)
	fx.set_process(false)
	var resources := Fixtures.resources()
	fx.configure(func(key: String) -> Dictionary: return resources.get(key, {}))
	var fixture := Fixtures.events()
	var frozen := JSON.stringify(fixture)
	fx.consume(fixture.events, 7, fixture.actors)
	check(fx.spawned == 6, "damage, explosion, teleport both ends, pickup, source mender with omitted y")
	check(fx.slots[0].node.position == Vector3(-5.4, 1.5, 0), "impact uses authoritative actor position plus presentation height")
	check(fx.slots[0].node.top_level, "pooled nodes preserve world coordinates under transformed parents")
	check(fx.slots[5].node.position == Vector3(5.4, 1.5, -8), "mender uses event xz and authoritative actor y")
	check(JSON.stringify(fixture) == frozen, "input snapshots/events must not mutate")
	fx.consume(fixture.events, 7, fixture.actors)
	check(fx.spawned == 6 and fx.duplicates == 5, "retained events do not replay")
	fx.advance(0.11)
	check(fx.slots[1].frame == 1, "source 14 fps frame selection")
	fx.advance(0.11)
	check(fx.slots[1].frame == 2, "source third frame reached")
	fx.advance(2.0)
	check(fx.active_count() == 0 and fx.get_child_count() == 6, "long delta expires all, retains bounded pool")
	for slot: Dictionary in fx.slots:
		check(not slot.node.visible and slot.material.get_shader_parameter("frame_texture") == null, "expired slot releases texture binding")
	fx.consume(fixture.events, 7, fixture.actors)
	check(fx.active_count() == 0, "retained history after lifetime does not restart")
	fx.reset()
	fx.consume(fixture.duplicates, 7, fixture.actors)
	check(fx.spawned == 4, "identical source events must preserve distinct adapter IDs")
	fx.consume(fixture.duplicates, 7, fixture.actors)
	check(fx.spawned == 4, "adapter IDs dedup independently of sourceId")
	fx.reset()
	var identity_events: Array = []
	for id: Variant in [0, 0.0, 2147483648, 2147483647, 9007199254740991, 9007199254740992]:
		identity_events.append({"id":id,"type":"explosion","pos":{"x":0,"y":0,"z":0}})
	fx.consume(identity_events)
	check(fx.spawned == 4, "zero, large safe IDs, out-of-order within window and int/JSON-float equality")
	fx.reset()
	var bad: Array = [
		{"id":null,"type":"explosion","pos":{"x":0,"y":0,"z":0}},
		{"id":true,"type":"explosion","pos":{"x":0,"y":0,"z":0}},
		{"id":"pad","type":"teleport","actor":7,"to":{"x":0,"y":0,"z":0}},
		{"id":1,"type":"explosion","pos":{"x":NAN,"y":0,"z":0}},
		{"id":2,"type":"damage","actor":7,"amount":0},
		{"id":3,"type":"damage","actor":null,"amount":9},
		{"id":4,"type":"damage","actor":7,"amount":"30"},
		{"id":5,"type":"shot","actor":7,"hit":8,"to":{"x":0,"y":0,"z":0}},
		{"id":6,"type":"launch","actor":7,"pos":{"x":0,"y":0,"z":0}},
		{"id":7,"type":"explosion","pos":{"x":1e9,"y":0,"z":0}},
		{"id":8,"type":"mender-heal","actor":10,"x":0,"z":0,"radius":3,"healed":1},
	]
	fx.consume(bad, 7, fixture.actors)
	check(fx.spawned == 0, "invalid fields, unsupported shot/launch and absent authoritative height skip")
	fx.reset()
	var burst: Array = []
	for id: int in range(1, 101): burst.append({"id":id,"type":"explosion","pos":{"x":id,"y":1,"z":0}})
	fx.consume(burst)
	check(fx.spawned == 100 and fx.active_count() == FX.CAP and fx.get_child_count() == FX.CAP, "burst hard cap")
	check(fx.overflow == 68, "oldest overflow replacement")
	for slot: Dictionary in fx.slots: check(slot.event_id >= 69, "newest events survive overflow")
	fx.advance(NAN)
	fx.advance(-1)
	check(fx.active_count() == FX.CAP, "invalid delta cannot affect lifetime")
	fx.advance(3)
	fx.consume([{"id":101,"type":"explosion","pos":{"x":0,"y":1,"z":0}}])
	check(fx.get_child_count() == FX.CAP and fx.active_count() == 1, "pool reuse without allocation")
	for group: int in range(12):
		var history: Array = []
		for index: int in range(512): history.append({"id":102 + group * 512 + index,"type":"ignored"})
		fx.consume(history)
	check(fx.seen.size() <= FX.ID_WINDOW, "dedup memory bounded")
	var before: int = fx.spawned
	fx.consume(burst)
	check(fx.spawned == before, "evicted stale history cannot replay")
	var references: Array = []
	for slot: Dictionary in fx.slots: references.append(weakref(slot.node))
	fx.reset()
	check(fx.get_child_count() == 0 and fx.seen.is_empty(), "round reset frees nodes and IDs")
	for reference: WeakRef in references: check(reference.get_ref() == null, "reset really frees, not just hides")
	fx.consume(fixture.events, 7, fixture.actors)
	check(fx.spawned == 6, "same IDs accepted in next round")
	fx.configure_resources({})
	fx.consume(fixture.events, 7, fixture.actors)
	check(fx.spawned == 0, "absent external lane is safe")
	fx.configure_resources(resources)
	fx.consume(fixture.events, 7, fixture.actors)
	var stress_start := Time.get_ticks_usec()
	for step: int in range(300):
		var batch: Array = []
		for index: int in range(16): batch.append({"id":10000 + step * 16 + index,"type":"explosion","pos":{"x":index,"y":1,"z":0}})
		fx.consume(batch)
		fx.advance(1.0 / 60.0)
	var stress_usec := Time.get_ticks_usec() - stress_start
	check(fx.active_count() <= FX.CAP and fx.seen.size() <= FX.ID_WINDOW, "sustained saturation stays bounded")
	var child: WeakRef = weakref(fx.slots[0].node)
	fx.free()
	check(child.get_ref() == null, "parent freeing releases pooled children")
	print("MOTH_VFX_REGRESSION failures=", failures, " cap=32 id_window=4096 source_frames=11 stress_300_frames_4800_events_usec=",stress_usec," (headless CPU only, not GPU frame time)")
	quit(0 if failures == 0 else 1)
