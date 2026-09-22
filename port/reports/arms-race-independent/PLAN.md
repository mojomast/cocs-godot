# Independent acceptance plan, before live execution

Baseline `5445295`; delivery `52de3b9` + `21fbd93`, cherry-picked as
`5d03467` + `e7602fb`. Shared hooks remain unapplied. Read the primary
ACTIVE_LANES, delivery HANDOFF/DISCOVERY, all Arms Race runtime/helpers,
inherited session, source Arms Race tests/outcome rules/core ladder and scheduler.

Source findings: `core.mjs:1148–1149` owns +1/+2 promotions, final kill at
rung 9, death demotion; `outcome.mjs:74–81` prioritizes explicit winner,
then timed ladder/frags ties and scoreless draw. Session boundary dispatch
calls the subclass fresh-input gate; selection is disabled before queueing.
The exact delivery runtime will be tested against this integrated base.

Run 1: unchanged delivery snapshot-guided native keyboard/mouse observer on
Meridian, 1280x800, two Normal bots, default 180-second timer, ten weapons,
source-default RNG/physics/scheduler. Public map box route approaches a visible
bot to 12m and uses native mouse aim/fire/reload. Stop at first confirmed
promotion, otherwise 174s soft/177s observer/180s process bound. At most one
second purposeful combat attempt after reviewing the first; no seed retries.
This review's budget is separate from the delivery author's attempts.

Independently run all three arena startups and a legal 60s Meridian timer/restart
at 960x640 (other startup sizes 1280x800/960x640). Preserve every UUID and
failure. Compare source events/actor snapshots with native current/next display;
queue count, receipts and ACK highwater are distinct evidence. Open PNGs directly.

Use pinned Godot/deps per handoff, private copied project/XDG, owned PORT=0
loopback authorities and private Xvfb with both TCP and Unix listeners disabled.
Wrapper only redirects evidence/adds checks; observer and runtime remain exact.
Add explicit-release-safe boundary fixtures and run source Arms Race/outcome/
input/movement tests plus inherited native control/lifecycle/HUD tests.
Verify process reaping, temp removal and listener closure. Record hashes.

Full ten-rung live victory remains open unless actually reached. Automated
native input is not human usability approval. Campaign deferred; external lobby,
Horde and usability reservations preserved. No shared edits or hook integration.

## Review-run decisions

- Independent combat attempt 1 (`2a8ac5ea-4118-489c-a9ac-c58388f7cc15`)
  promoted at source 8.217s and ended at observer age 8.596368s; no second
  combat attempt is needed.
- Initial startup preflight (`46927e91-1736-4e5d-ad29-48eba05c850f`) failed
  because this wrapper mistakenly ran the inherited graphical weapon-selection
  test headless. The test explicitly requires a private graphical display;
  headless mouse capture stays visible. Zero authority starts/combat inputs.
  Preserve FAIL and rerun startup after moving this test under the existing
  private Xvfb. Runtime, observer, rules and test script remain unchanged.
