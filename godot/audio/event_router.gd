extends RefCounted
## Presentation-only authoritative-event planner. No network/gameplay writes.
## Event IDs are wire identities, never Horde payload/sourceId ordinals.
const MAX_IDS := 4096
const MAX_BATCH := 512
const VEHICLE_BEATS := ["vehicle-shot", "vehicle-damage"]
const WORLD_BEATS := ["capture", "flag-pickup", "flag-drop", "flag-return", "flag-pass", "flag-contest",
	"zone-score", "zone-progress", "zone-contested", "zone-capture", "zone-neutralized", "charge", "assault-hold", "payload-hold", "hill-rotate",
	"uplink-capture", "uplink-stage", "objective-win", "objective-tiebreak", "sudden-death", "horde-wave", "horde-wave-cleared",
	"horde-resupply", "boss-summon", "boss-slam", "boss-phase", "mender-heal", "vip-deploy", "vip-down", "vip-extracted",
	"assault-sector-captured", "assault-sector-lost", "assault-breach", "payload-checkpoint", "payload-delivered", "horde-upgrade",
	"horde-upgrade-selected", "horde-modifier", "juggernaut-transfer", "mission-won", "mission-lost", "overseer-aura", "lattice-support",
	"weather-change", "time-change", "vehicle-repair", "deployable-destroyed", "deployable-repaired", "deployable-fire", "holdout-progress", "payload-contest",
	"holdout-win", "uplink-win", "director-init", "director-wave", "director-wave-cleared", "director-siege", "director-siege-lifted",
	"director-escalation", "director-modifier", "director-intermission", "director-boss", "director-phase", "director-retarget", "director-overrun",
	"director-retire", "director-denial", "director-denial-end", "director-reinforce", "director-hq-damage", "director-spawn-telegraph",
	"director-spawn", "coop-reinforce", "coop-resupply", "coop-reserve", "coop-intermission-open", "coop-subagent-retire", "coop-spend-rejected",
	"coop-spend", "coop-bonus", "operation-summary", "cocs-capture", "cocs-depot-capture", "cocs-device-use", "cocs-terminal-shard",
	"cocs-terminal-vault", "cocs-terminal-sabotage", "cocs-terminal-hack", "cocs-terminal-deploy", "cocs-depot-vehicle-spawn",
	"cocs-depot-purchase", "cocs-sapper", "cocs-siphon", "cocs-scan", "cocs-role-spawn", "cocs-role-killed", "cocs-role-expire",
	"cocs-role-rally", "cocs-role-repair", "cocs-role-spot", "cocs-command", "cocs-prime-start", "cocs-prime", "cocs-prime-interrupt",
	"cocs-order-complete", "cocs-order-rejected", "cocs-buy"]
const LOCAL_BEATS := ["weapon-upgrade", "armsrace-promote", "armsrace-demote", "bounty", "loadout-switch", "threat-ping", "elimination-life", "singleplayer-life", "campaign-resupply"]
const ESCALATE := {"horde-wave":[1,1], "director-escalation":[1,1], "boss-summon":[0,2], "boss-slam":[0,2], "director-boss":[0,2], "boss-phase":[0,3], "director-phase":[0,3], "director-overrun":[0,3], "sudden-death":[0,3]}
const CLEAR := ["horde-wave-cleared", "director-wave-cleared", "objective-win", "mission-won", "holdout-win", "uplink-win"]
const RESPONSE_UP := ["capture", "zone-capture", "assault-sector-captured", "payload-delivered", "uplink-capture", "objective-win", "flag-return"]
const RESPONSE_DOWN := ["assault-sector-lost", "vip-down", "mission-lost", "elimination-life"]
const VOICE := {"capture":"capture", "flag-pickup":"flag-pickup", "flag-return":"flag-return", "goal":"goal", "killstreak":"killstreak", "spree":"spree", "multikill":"multikill", "victory":"victory", "defeat":"defeat", "score":"score", "boss-summon":"boss", "director-boss":"boss", "objective-win":"objective", "horde-wave":"objective"}
const TEAM_PRIVATE := ["cocs-terminal-shard", "cocs-terminal-vault", "cocs-terminal-sabotage", "cocs-terminal-hack", "cocs-terminal-deploy",
	"cocs-depot-purchase", "cocs-sapper", "cocs-siphon", "cocs-scan", "cocs-role-spawn", "cocs-role-killed", "cocs-role-expire",
	"cocs-command", "cocs-order-complete", "cocs-order-rejected"]
const REPEAT_WINDOW := {"cocs-scan":1.5, "cocs-role-rally":3.0, "cocs-role-repair":3.0, "cocs-role-spot":3.0, "cocs-command":1.5, "director-hq-damage":3.0}
var round_key: Variant = null
var ids: Dictionary = {}
var order: Array = []
var repeats: Dictionary = {}
var zone: Dictionary = {}
var escalation := 0
var dropped_duplicate := 0
var dropped_invalid := 0
var last_cue_id := ""
var vehicle_hits: Dictionary = {}

func start_round(key: Variant) -> void:
	# Reconnect/start notification for the same public round is not a reset.
	if round_key == key: return
	round_key = key
	ids.clear()
	order.clear()
	repeats.clear()
	zone.clear()
	vehicle_hits.clear()
	escalation = 0
	last_cue_id = ""

func seek_reset(key: Variant) -> void:
	round_key = null
	start_round(key)

func _numeric_id(value: Variant) -> int:
	if value is int and value >= 0: return value
	if value is float and is_finite(value) and value >= 0.0 and value <= 2147483647.0 and floorf(value) == value: return int(value)
	return -1

func _claimed(id: int) -> bool:
	if ids.has(id):
		dropped_duplicate += 1
		return false
	ids[id] = true
	order.append(id)
	if order.size() > MAX_IDS: ids.erase(order.pop_front())
	return true

func _team_or_actor(event: Dictionary, kind: String, actor: int, team: Variant) -> bool:
	if kind == "cocs-buy" or kind == "cocs-device-use": return actor >= 0 and event.get("actor") == actor
	if kind == "cocs-depot-vehicle-spawn": return true # hostile loaner warning is audible
	if kind in TEAM_PRIVATE: return team != null and event.get("team") == team
	if kind in ["cocs-role-repair", "cocs-role-spot"]: return event.get("repaired", event.get("targets", [])) is Array and not event.get("repaired", event.get("targets", [])).is_empty()
	return true

func _repeat_allowed(event: Dictionary, kind: String) -> bool:
	if not REPEAT_WINDOW.has(kind): return true
	var time: Variant = event.get("time")
	if not (time is int or time is float) or not is_finite(float(time)): return true
	var bucket := "%s:%s" % [kind, str(event.get("hq", event.get("team", event.get("actor", "global"))))]
	var previous: Variant = repeats.get(bucket)
	if previous != null and float(time) - float(previous) < float(REPEAT_WINDOW[kind]): return false
	repeats[bucket] = float(time)
	if repeats.size() > 64: repeats.erase(repeats.keys()[0])
	return true

func _zone_progress(event: Dictionary) -> bool:
	var key := str(event.get("zone", "zone"))
	var amount: Variant = event.get("progress", 0)
	var bucket := mini(3, int(clampf(float(amount) if amount is int or amount is float else 0.0, 0.0, 100.0) / 25.0))
	var next := {"bucket":bucket, "team":event.get("team"), "contested":event.get("contested") == true}
	var prev: Variant = zone.get(key)
	zone[key] = next
	if zone.size() > 64: zone.erase(zone.keys()[0])
	return prev != null and (next.team != prev.team or next.contested != prev.contested or (bucket > prev.bucket and bucket >= 1))

func consume(items: Array, actor: int = -1, team: Variant = null, ready: bool = true, local_vehicle: Variant = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for value: Variant in items.slice(0, MAX_BATCH):
		if not value is Dictionary: dropped_invalid += 1; continue
		var event: Dictionary = value
		var id := _numeric_id(event.get("id"))
		if id < 0: dropped_invalid += 1; continue
		if not _claimed(id): continue
		# Events may arrive before the initial snapshot; consume identity, never
		# infer an old seat/team from a previous round or replay on recovery.
		if not ready: continue
		var kind := str(event.get("type", ""))
		var local := actor >= 0 and event.get("actor") == actor
		if kind == "vehicle-damage":
			# Event actor is the ATTACKER, not the rider. Match the snapshot seat.
			if local_vehicle == null or event.get("vehicle") != local_vehicle: continue
			var stamp: Variant = event.get("time")
			if not (stamp is int or stamp is float) or not is_finite(float(stamp)): continue
			var key := str(local_vehicle)
			if vehicle_hits.has(key) and float(stamp) - float(vehicle_hits[key]) < 0.05: continue
			vehicle_hits[key] = float(stamp)
			if vehicle_hits.size() > 16: vehicle_hits.erase(vehicle_hits.keys()[0])
			var amount: Variant = event.get("amount")
			var strength := clampf(float(amount) / 40.0, 0.0, 1.0) if (amount is int or amount is float) and is_finite(float(amount)) else 0.0
			out.append({"id":id, "type":kind, "vehicle":local_vehicle, "strength":strength, "motif":"", "voice":"", "response":"", "escalation":escalation, "local":true})
			continue
		if kind == "vehicle-shot":
			# The existing ordinary shot path does not own mounted vehicle reports.
			out.append({"id":id, "type":kind, "from":event.get("from", event.get("pos")), "motif":"", "voice":"", "response":"", "escalation":escalation, "local":local})
			continue
		if ESCALATE.has(kind):
			var change: Array = ESCALATE[kind]
			escalation = mini(3, maxi(escalation + int(change[0]), int(change[1])))
		elif kind in CLEAR: escalation = 0
		if kind in LOCAL_BEATS and not local: continue
		if not _team_or_actor(event, kind, actor, team) or not _repeat_allowed(event, kind): continue
		if kind == "zone-progress" and not _zone_progress(event): continue
		if kind == "cocs-command" and event.get("action") not in ["take", "release", "mutiny-vote", "policy", "set-route"]: continue
		if kind == "cocs-terminal-shard" and event.get("action") not in ["collect", "return"]: continue
		if not kind in WORLD_BEATS and not kind in LOCAL_BEATS and not kind in VOICE: continue
		var response := "capture" if kind in RESPONSE_UP else ("loss" if kind in RESPONSE_DOWN else ("accent" if local and kind in ["killstreak", "spree", "multikill"] else ""))
		var voice := str(VOICE.get(kind, ""))
		# Speech says FLAG CAPTURED. Zone/uplink/depot capture must NOT reuse it.
		if kind == "capture" and event.get("mode", "ctf") != "ctf": voice = ""
		# Speech says BOSS INCOMING; phase 2/3 does not summon a new boss.
		var cue := {"id":id, "type":kind, "motif":kind, "response":response, "voice":voice, "escalation":escalation, "local":local,
			"team":event.get("team"), "listener_team":team}
		last_cue_id = "%s:%d" % [kind, id]
		out.append(cue)
	return out

func status() -> Dictionary:
	return {"round":round_key, "remembered_events":order.size(), "repeat_buckets":repeats.size(), "zones":zone.size(),
		"escalation":escalation, "dropped_duplicate":dropped_duplicate, "dropped_invalid":dropped_invalid, "last_cue_id":last_cue_id}
