extends RefCounted
## Presentation-only LATTICE kit teaching. Hooks are descriptions of source
## behavior, not native action permissions or locally inferred role telemetry.
const Loadout = preload("res://ui/loadout.gd")

# Mirrors game/lattice-roles.mjs LATTICE_OPERATOR_ROLES. Each entry is independent
# of the harness so all 57 legal combinations compose without pair-specific copy.
const OPERATORS := {
	"mistral":{"job":"Recon / rotation", "name":"Running point", "effect":"Capture 20% faster while moving at least 4 m/s inside the point; stopping removes the bonus.", "limit":"A moving approach outside the point does not earn capture credit."},
	"gemini":{"job":"Breach / disrupt", "name":"Relay duelist", "effect":"Weapon swaps open 3 seconds of 20% faster capture, at most once every 6 seconds.", "limit":"The swap window must overlap physical presence on the point."},
	"grok":{"job":"Breach / disrupt", "name":"Hot breach", "effect":"Capture 25% faster with at least two Heat stacks; the bonus ends when Heat cools.", "limit":"Heat requires landing hits; it is not a permanent capture rate."},
	"deepseek":{"job":"Anchor / ward", "name":"Patient overwatch", "effect":"While stationary on a point, reveal one visible enemy within 24 m for 2 seconds, every 4 seconds.", "limit":"Moving ends the stationary opportunity; the intel mark grants no SCAN damage bonus."},
	"meta":{"job":"Link / repair", "name":"Braced maintenance", "effect":"Crouch without firing on an owned, uncontested cut point for 4 seconds to repair its link; moving or taking damage interrupts.", "limit":"Only a published repairable sabotage cut qualifies, not ordinary enemy ownership or a disconnected link; 4v4 has no natural Saboteur cut source at this pin."},
	"claude":{"job":"Anchor / ward", "name":"Safe review", "effect":"Hold still without firing on an owned point to clear slow from one nearby ally, at most once every 6 seconds.", "limit":"This clears slow, not all damage or status effects."},
	"chatgpt":{"job":"Quartermaster", "name":"Adaptive quartermaster", "effect":"During the post-swap handling window, share up to a quarter-magazine from your ammo belt with one nearby ally on a point, every 8 seconds.", "limit":"Sharing needs pickup-acquired finite donor ammo for the recipient's equipped weapon, leaves at least one round and needs recipient capacity; default Pulse ammo is infinite and offers no useful transfer."},
	"kimi":{"job":"Recon / rotation", "name":"Moving context", "effect":"While moving at least 2 m/s on a point, reveal one visible enemy within 32 m for 1.5 seconds, every 3 seconds.", "limit":"Stopping loses the moving reveal opportunity; intel alone grants no SCAN damage bonus."},
	"qwen":{"job":"Puma delivery / interaction", "name":"Tool-use specialist", "effect":"Capture, terminal channels and economy-node PRIME run at 1.35× speed.", "limit":"Capture already reaches the 1.35× ceiling: stronger contributors win rather than stacking. PRIME and terminals are Operations opportunities, not general PvP unit actions."},
}

# Mirrors game/lattice-roles.mjs LATTICE_HARNESS_ROLES; activation is a
# source-owned event and selecting a teaching card never activates a hook.
const HARNESSES := {
	"openclaw":{"job":"Breach / disrupt", "name":"Break the siege", "effect":"Claw activation removes up to 15% hostile capture progress from one point within 6 m, with an 8-second point disruption cooldown.", "limit":"Disruption never grants ownership by itself."},
	"hermes":{"job":"Quartermaster / rotation", "name":"Courier delivery", "effect":"Activate at a connected owned economy point to trade up to 4 personal REQ for 3 team FLUX, with a 10-second point cooldown.", "limit":"Requires a connected owned economy point and actual personal REQ; movement alone does not deliver FLUX."},
	"opencode":{"job":"Quartermaster", "name":"Multiplex supply", "effect":"Burst activation shares up to a quarter-magazine from your ammo belt with two allies within 8 m on the point; recipients share an 8-second resupply cooldown.", "limit":"Pickup-acquired finite donor ammo must match each recipient's equipped weapon, leave one round and fit recipient capacity; infinite default Pulse offers no useful transfer."},
	"claudecode":{"job":"Anchor / ward", "name":"Team guardrail", "effect":"Guardrail activation clears slow from up to three allies within 8 m on the point; each ally can receive a cleanse once every 6 seconds.", "limit":"Slow cleanse is situational and is not a permanent ward."},
	"codex":{"job":"Link / repair", "name":"Recompile link", "effect":"Recompile activation repairs one owned, uncontested cut point within 6 m, including its sabotaged terminal, with an 8-second cooldown.", "limit":"Needs a published repairable sabotage cut; ordinary lost ownership or disconnection is not a repair. 4v4 has no natural Saboteur cut source at this pin."},
	"cline":{"job":"Breach / disrupt", "name":"Step onto the point", "effect":"After a successful dash, capture 25% faster for 3 seconds while physically on a point; the window can open once every 6 seconds.", "limit":"The dash itself does not capture a point; the boost does not stack with a stronger capture bonus."},
	"roo":{"job":"Anchor / ward", "name":"Jam the takeover", "effect":"Jam activation wards one owned point within 9 m for 4 seconds: hostile capture is 20% slower; points share an 8-second ward cooldown.", "limit":"Uses the strongest ward with FORTIFY rather than stacking; requires an owned point."},
}

const SHARED_LIMITS := "Capture bonuses use the strongest contributor, capped at 1.35×; they never stack. A legal adjacent live front can be captured even when cut off from HQ income. Depot Puma loaners spawn automatically at owned depots even with vehicles:false, but a role does not grant a vehicle or prove native board/drive/dismount controls."

static func describe(operator_id: Variant, harness_id: Variant) -> Dictionary:
	var problem: String = Loadout.problem(operator_id, harness_id)
	if not problem.is_empty():
		return {"ready":false, "reason":problem, "text":problem}
	var operator_role: Dictionary = OPERATORS[operator_id].duplicate(true)
	var harness_role: Dictionary = HARNESSES[harness_id].duplicate(true)
	var title: String = Loadout.character_name(operator_id) + " · " + Loadout.harness_name(harness_id)
	var text := "%s — %s: %s %s: %s Limits: %s %s %s" % [title,
		operator_role.name, operator_role.effect, harness_role.name, harness_role.effect,
		operator_role.limit, harness_role.limit, SHARED_LIMITS]
	return {"ready":true, "reason":"", "operator":operator_id, "harness":harness_id,
		"title":title, "operator_role":operator_role, "harness_role":harness_role,
		"limits":SHARED_LIMITS, "text":text}

## Accept only the transport's authoritative start echo (session_config).
## Never resolve/fallback a request into an apparently assigned kit.
static func from_session(session_config: Dictionary) -> Dictionary:
	if session_config.is_empty() or not session_config.has("operator") or not session_config.has("harness"):
		return {"ready":false, "reason":"Awaiting assigned session loadout.", "text":"Awaiting assigned session loadout."}
	return describe(session_config.get("operator"), session_config.get("harness"))
