extends Node
## Bounded, speech-free earcons for source objective/LATTICE vocabulary.
## Each event spends at most one of four preallocated voices. Text/dialogue is
## never pronounced; no TTS and no ordinary shot/explosion double-dispatch.
const Router = preload("res://audio/event_router.gd")
const RATE := 22050
const MAX_VOICES := 4
const SHAPES := {
	"secured":[0,7,12], "lost":[7,3,-2], "wave":[0,-5,0], "cleared":[0,5,7,12],
	"siege":[0,-1,0,-1], "boss":[0,-5,-12], "phase":[0,-3,-7], "refused":[9,4,2],
	"terminal":[0,4,7,12], "order":[0,7], "spend":[12,7], "coin":[12,19],
	"capture":[0,7,12], "loss":[12,7,0], "hold":[0,5], "contest":[0,-1,0], "generic":[0,4,7]
}
var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var muted := false
var volume := 1.0
var focused := true
var dropped := 0

func _ready() -> void:
	for i in MAX_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"Effects"
		add_child(player)
		players.append(player)
	for kind: String in SHAPES: streams[kind] = _render(SHAPES[kind])

func _render(notes: Array) -> AudioStreamWAV:
	var length := 0.34
	var count := roundi(length * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / RATE
		var value := 0.0
		for n in range(notes.size()):
			var onset := n * 0.067
			var age := t - onset
			if age < 0.0 or age > 0.16: continue
			var hz := 440.0 * pow(2.0, (60.0 + float(notes[n]) - 69.0) / 12.0)
			value += sin(TAU * hz * age) * sin(PI * age / 0.16) * 0.16
		var word := int(clampf(value, -0.65, 0.65) * 32767.0) & 0xffff
		data[i * 2] = word & 255
		data[i * 2 + 1] = (word >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream

func _family(event: Dictionary) -> String:
	var kind := str(event.get("type", ""))
	if kind in ["cocs-capture", "cocs-depot-capture"]:
		return "secured" if event.get("team") == event.get("listener_team") else "lost"
	if kind in ["zone-capture", "assault-sector-captured", "uplink-capture", "flag-return", "payload-delivered", "objective-win", "mission-won", "vip-extracted", "cocs-prime"]: return "capture"
	if kind in ["assault-sector-lost", "zone-neutralized", "mission-lost", "vip-down", "elimination-life"]: return "loss"
	if kind in ["director-wave", "horde-wave", "director-init", "director-escalation"]: return "wave"
	if kind in ["director-wave-cleared", "horde-wave-cleared", "director-siege-lifted"]: return "cleared"
	if kind in ["director-siege", "director-hq-damage", "director-overrun", "boss-slam"]: return "siege"
	if kind in ["director-boss", "boss-summon", "director-spawn-telegraph"]: return "boss"
	if kind in ["boss-phase", "director-phase"]: return "phase"
	if kind in ["cocs-order-rejected", "coop-spend-rejected"]: return "refused"
	if kind.begins_with("cocs-terminal-") or kind in ["cocs-prime-start", "cocs-prime-interrupt"]: return "terminal"
	if kind in ["cocs-order-complete", "cocs-command", "cocs-role-rally"]: return "order"
	if kind in ["cocs-buy", "coop-spend", "cocs-depot-purchase"]: return "spend"
	if kind in ["cocs-terminal-shard", "coop-bonus", "cocs-siphon"]: return "coin"
	if kind in ["zone-contested", "flag-contest", "payload-contest", "assault-breach"]: return "contest"
	if kind in ["assault-hold", "payload-hold", "holdout-progress", "uplink-stage"]: return "hold"
	return "generic"

func apply_settings(settings: Dictionary) -> void:
	var value: Variant = settings.get("effects_volume", 100)
	volume = clampf(float(value) / 100.0, 0.0, 1.0) if value is int or value is float else 1.0
	muted = settings.get("mute", false) == true or volume <= 0.0
	if muted: stop_all()

func set_focus(value: bool) -> void:
	focused = value
	if not value: stop_all()

func stop_all() -> void:
	for player: AudioStreamPlayer in players: player.stop()

func event_plan(plan: Dictionary) -> bool:
	if muted or not focused: dropped += 1; return false
	var event: Dictionary = {"type":plan.get("type"), "team":plan.get("team"), "listener_team":plan.get("listener_team")}
	var family := _family(event)
	for player: AudioStreamPlayer in players:
		if player.playing: continue
		player.stream = streams[family]
		player.volume_db = linear_to_db(0.18)
		player.play()
		return true
	dropped += 1
	return false

func status() -> Dictionary:
	var active := 0
	for player: AudioStreamPlayer in players:
		if player.playing: active += 1
	return {"active_voices":active, "voice_limit":MAX_VOICES, "prepared_motifs":streams.size(), "dropped":dropped}
