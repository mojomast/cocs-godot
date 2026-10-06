# Contract: WeaponPresentationProfile + sampled-animation pilot (W2, F05)

**Worker scope:** `godot/first_person/**` and `godot/tests/first_person/**`.
**Must not touch:** `game/**` (source balance stays authoritative),
`godot/net/**`, `godot/world/session.gd`, protocol schemas, `godot/ui/**`,
`project.godot`, global optical settings.

## Goal

One inspectable presentation profile per weapon, keyed by stable source weapon
ID, that owns the values now spread across `first_person/{rig,handling,inertia,
kick_motion,sprint_fov,session_binding}.gd` and the duplicated feel tables in
`world/audio_feedback.gd`. The existing `first_person/rig.gd` remains the **sole
final pose compositor**; helpers consume the profile instead of importing each
other's state.

## Interface (authored by orchestrator; implement exactly)

- New `godot/first_person/profiles/weapon_presentation_profile.gd`:
  `extends Resource`, `class_name WeaponPresentationProfile`.
- Exported fields, all authored overrides keyed by `weapon_id: String` (must
  match the source weapon id/name; the source `game/data.mjs` `WEAPONS` order is
  the stable identity):
  - pose/ADS offsets and sight corridor references;
  - cosmetic recoil/recovery scale + spring/inertia limits (derived from source
    manifest kick, never hand-copied source balance);
  - mechanism clip references (reload/switch/pump) or `null`;
  - muzzle/impact grammar reference and audio report cue id;
  - a `default_for_weapon` fallback whose values reproduce today's constants.
- Loader `WeaponPresentationProfile.for_weapon(id)` returns the shared immutable
  profile; unknown id resolves to the documented default (current behavior).
  Runtime state (recoil age, heat, reload progress) stays per-instance.
- Export current values first: the Pulse Rifle profile must reproduce the current
  procedural response exactly (parity), then SMG and Scattergun may follow only
  if parity holds.

## Sampled-animation pilot

For the Pulse Rifle reload: an `AnimationPlayer` (or equivalent existing rig
mechanism) may drive a **disjoint hardware/offset track** that samples source
reload progress read-only. Requirements:

- The clip samples source timing; it must not free-run, gate, shorten or complete
  the reload, and must not touch ammunition or source state.
- Explicit cancellation and RESET ownership on source events; switching weapons,
  sprint, melee or death cancels cleanly.
- Aim/recoil/inertia stay procedural and authoritative where they already are.

## Required evidence

- Existing gates unchanged: `res://tests/first_person/{handling,lifecycle,
  binding,ads_contract,recoil,muzzle_geometry,detail,finishes}.gd`.
- New focused tests: profile parity for the Pulse Rifle (same numbers consumed,
  same procedural result), immutable shared resource + isolated per-instance
  state, two independent instances, reload clip cancellation/interruption.
- `git diff` shows no `game/**` change. No source balance edit in the same
  commit. Report rig CPU/asset memory measurements only if actually recorded.
