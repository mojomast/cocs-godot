extends RefCounted
const LatticeCaption = preload("res://lattice/event_caption.gd")
## Plain, non-live text. No speech, audio playback, positional inference or input.
const TTL := 2.2
const CATALOG_PATH := "res://experience/source_catalog.json"
const LOCAL_TYPES := ["damage", "pickup", "powerup", "spawn", "reload", "dryfire", "weapon-switch", "loadout-switch", "power", "grenade", "melee", "shot", "launch", "alt-state", "alt-mode", "alt-fire", "alt-toggle", "move-start", "move-end", "windup-start", "windup-end", "charge-start", "charge-release", "charge-cancel", "slam-launch", "slam-impact", "grapple-hook", "grapple-release", "rope-place", "rope-expire", "move-miss", "rope-miss", "move-blocked", "fuel-empty", "no-lift", "chain-cancel", "landing-recovery", "threat-ping"]
const TELEGRAPHS := {"overseer":"overseer aura", "mender":"mender pulse", "flanker":"flanker push", "phalanx":"phalanx shield", "sapper":"sapper charge", "artillery":"artillery", "boss":"boss slam"}
const SpectatorEvents = preload("res://experience/spectator_events.gd")
const TEAM_CAPTIONS := ["cocs-terminal-shard", "cocs-terminal-vault", "cocs-terminal-sabotage", "cocs-terminal-hack", "cocs-terminal-deploy", "cocs-depot-purchase", "cocs-sapper", "cocs-siphon", "cocs-scan", "cocs-role-spawn", "cocs-role-killed", "cocs-role-expire", "cocs-command", "cocs-order-complete", "cocs-order-rejected"]
var catalog: Dictionary = {}
var current: Dictionary = {}
var repeated: Dictionary = {}

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Dictionary: catalog = parsed

static func clean(value: Variant, limit: int = 180) -> String:
	if not value is String: return ""
	return " ".join(value.replace("\n", " ").replace("\r", " ").replace("\t", " ").split(" ", false)).left(limit)

static func accept(shown: Dictionary, candidate: Dictionary, at: float) -> Dictionary:
	var text := clean(candidate.get("text"))
	if text.is_empty(): return {}
	var rank := int(candidate.get("priority", 80))
	var age := at - float(shown.get("at", -1000))
	if not shown.is_empty() and age >= 0 and age < TTL:
		if shown.get("text") == text: return {}
		if int(shown.get("priority", 80)) >= 109 and rank <= int(shown.get("priority", 80)): return {}
	return {"text":text, "priority":rank, "at":at}

func text_for(event: Dictionary) -> String:
	var kind := str(event.get("type", ""))
	if kind == "pickup":
		var supply := str(event.get("kind", ""))
		return {"health":"Health acquired", "armor":"Armor acquired", "ammo":"Ammo acquired", "megahealth":"Mega health acquired"}.get(supply, "Pickup" if supply.is_empty() else "Weapon acquired")
	if kind == "spawn": return "Respawn" if event.get("actor") != null or event.get("pos") != null else ""
	if kind == "damage": return "Damage taken" # No invented bearing from a hidden attacker.
	if kind == "enemy-telegraph":
		var detail := str(TELEGRAPHS.get(str(event.get("kind", "")).to_lower(), ""))
		return "Incoming attack" + (" · " + detail if not detail.is_empty() else "")
	if kind == "charge": return "Charged shot ready" if event.get("state") == "ready" else "Charging shot"
	if kind in ["weather-change", "time-change"]:
		var detail := clean(event.get("kind" if kind == "weather-change" else "phase"), 40)
		return ("Weather" if kind == "weather-change" else "Time of day") + (" · " + detail if not detail.is_empty() else " change")
	if kind == "alt-toggle": return "Alt fire off" if event.get("on") == false or event.get("alt") == false else "Alt fire on"
	if kind in ["alt-state", "alt-mode", "alt-fire"] or (kind in ["shot", "launch"] and event.get("alt") == true):
		var weapon: Variant = event.get("mode", event.get("altMode", event.get("altId", event.get("weapon"))))
		var ids := ["salvo", "cluster", "overload", "slug", "mortar", "mine", "chain", "bomb", "double", "twin"]
		var index := ids.find(weapon) if weapon is String else -1
		if (weapon is float or weapon is int) and is_finite(float(weapon)) and float(weapon) == floorf(float(weapon)): index = int(weapon)
		var label := clean(event.get("modeLabel", event.get("label", ""))).to_upper()
		if index >= 0 and index < catalog.get("alt", []).size(): label = str(catalog.alt[index]).trim_prefix("Alt fire · ")
		var prefix := "Alt fire"
		if kind in ["alt-state", "alt-mode"]: prefix = "Alt mode off" if event.get("alt") == false or event.get("on") == false else "Alt mode"
		return prefix + (" · " + label if not label.is_empty() else "")
	var lattice_text := LatticeCaption.text_for(event)
	if not lattice_text.is_empty(): return lattice_text
	return str(catalog.get("captions", {}).get(kind, {}).get("text", ""))

static func event_allowed(event: Dictionary, actor_id: int, team: Variant = null) -> bool:
	var kind := str(event.get("type", ""))
	if kind in LOCAL_TYPES: return actor_id >= 0 and event.get("actor") == actor_id
	if not kind.begins_with("cocs-"): return true
	# Keep the spectator allowlist and reject foreign private team events before
	# formatting. Team comes only from the current confirmed local snapshot.
	if actor_id < 0 and not SpectatorEvents.public_event(event): return false
	if (event.get("team") == 0 or event.get("team") == 1) and event.get("team") != team and not SpectatorEvents.public_event(event): return false
	# Source latticeSoundCue eligibility, independent of audio mute/volume.
	if kind in ["cocs-buy", "cocs-device-use"]: return actor_id >= 0 and event.get("actor") == actor_id
	if kind in TEAM_CAPTIONS and (team == null or event.get("team") != team): return false
	if kind == "cocs-command" and event.get("action") not in ["take", "release", "mutiny-vote", "policy", "set-route"]: return false
	if kind in ["cocs-role-repair", "cocs-role-spot"]:
		var entries: Variant = event.get("repaired" if kind == "cocs-role-repair" else "targets")
		return entries is Array and not entries.is_empty()
	return true

func consume(events: Array, at: float, actor_id: int, enabled: bool, team: Variant = null) -> void:
	if not enabled:
		clear()
		return
	for value: Variant in events.slice(0, 512):
		if not value is Dictionary: continue
		var kind := str(value.get("type", ""))
		# Global captions describe a received event, never its location or proximity.
		if not event_allowed(value, actor_id, team): continue
		var candidate := {"text":text_for(value), "priority":catalog.get("captions", {}).get(kind, {}).get("priority", 80)}
		# Repeated simulation tells may interleave with shots in the same batch.
		# Dedupe by text as well as the currently showing line so a held blocked
		# movement or automatic weapon cannot alternate away a pickup every tick.
		var text: String = candidate.text
		if text.is_empty(): continue
		var recent: bool = repeated.has(text) and at >= float(repeated[text]) and at - float(repeated[text]) < TTL
		repeated[text] = at
		if repeated.size() > 128: repeated.erase(repeated.keys()[0])
		if recent: continue
		var next := accept(current, candidate, at)
		if not next.is_empty():
			current = next

func line(at: float) -> String:
	if current.is_empty(): return ""
	var age := at - float(current.at)
	return str(current.text) if age >= 0 and age < TTL else ""

func clear() -> void:
	current.clear()
	repeated.clear()
