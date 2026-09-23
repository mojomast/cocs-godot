# Playable-port integration: menu + loadouts + Horde + LATTICE

## Scope and authority boundaries

This batch combines the existing unified main-menu lane with three gameplay-accessibility improvements. It does not replace the Node simulation. The original `game/` and `server/` source remains unchanged. No commit, push, package publication, or release is authorized by this handoff; those require the owner's separate approval.

Vocabulary: a **loadout** is an operator/harness pair; an **upgrade** is a Horde reward from a current source offer; **topology** is authored LATTICE adjacency plus recipient-visible supply information. Guidance is advisory, not command authority.

- Source combat setup/lobby: popup-free operator and harness controls; Claude is locked to Claude Code. Create/join carry the selection, and the roster displays the authority's identity. Legacy identity-free roster envelopes remain valid.
- Local Horde: numbered offer buttons and hotkeys, validated epoch/wave/applied-count intents, and explicit applied/refused feedback. Repeated snapshots preserve button instances/focus. The source still owns rewards and wave progression.
- LATTICE: authored links behind visible map markers, supply and next-target guidance, unknown supply distinct from confirmed cuts, safe handling of stale selected IDs. No hidden recipient data is added and HOLD stays server-gated.
- The menu, registry, launchers, and existing three menu gates are preserved. Native-arena Deathmatch retains its separate restricted authority; it does not acquire arbitrary loadout support.

## Source launch commands

From the repository root, set `GODOT_BIN` to the pinned Godot 4.5.2 executable. Existing generated content and imported assets are prerequisites.

```sh
node tools/godot-dev/launch.mjs --experience=menu
node tools/godot-dev/launch.mjs --play --setup
node tools/godot-dev/launch.mjs --experience=lobby
node tools/godot-dev/launch.mjs --experience=horde --map=meridian-exchange
node tools/godot-dev/launch.mjs --experience=lattice --map=asterion-relay --mode=cocs
```

These are source-tree launches. Previously published packages do not automatically contain this uncommitted work.

## Verification

Final aggregate verification: **167/167 canonical gates passed**, including the real two-client loadout loopback, seven lifecycle/cleanup regression cases, blood harness failure controls and live native blood check, Cinder traversal, menu contracts, Horde accelerated-offer loopback, LATTICE topology and release refusal. The tested source was hash-frozen; `final-full.json` and `full-attempt-01.json` retain the complete run. The release gate deliberately refuses publication; a green source verifier is not release authorization.

The canonical `tools/godot-dev/verify.py` contains the menu gates, loadout native/real-two-client gates, Horde adapter/native/loopback gates, and LATTICE topology gate. `test_playable_gates.py` checks registration, uniqueness and topology provenance.

```sh
PORT=0 TMPDIR=/tmp/opencode python3 tools/godot-dev/verify.py
```

The Horde gate `horde-upgrade-fixture` exercises actual native key input, a real loopback authority, source selection, confirmation and resulting snapshots. It deliberately offers a wave-three reward early: it is NOT a natural three-wave or ten-wave completion test. Display tests run on private Xvfb rather than the user's desktop.

The real source-launcher journey was exercised on a private display: first `MENU_READY`, native-dm `MENU_ROUTE`, owned authority readiness, rendered Prism Foundry match, a normal window-close request, second `MENU_READY`, then `MENU_QUIT` and supervisor exit 0. Logs/screenshots are in `menu-resume/` in the evidence directory below. The earlier failed driver attempts are retained: bare Xvfb had no window manager to create `WM_DELETE_WINDOW` before Godot's startup lookup. Initializing the standard WM atoms before launching Godot fixed the driver; no menu or launcher code change was needed. Audio hardware was unavailable (Godot fell back to Dummy), so this is not audio acceptance.

The previously killed Cinder traversal passed an isolated rerun (1,246 assertions, no failures). No Cinder gameplay change was made; the historical SIGKILL's cause is unproven. The loadout loopback now holds both real clients connected until both snapshot proofs are validated, then requires release acknowledgments and clean exits. Its lifecycle regressions are registered as `loadout-lifecycle`.

Local integration evidence is retained at `/home/mojo/.tmp-on-disk/cocs-improvements-io2r8890/`: original-file protection manifest, independent lane reviews, final review, aggregate report, scoped change list, content hashes and integration receipt. Failed/intermediate reports remain labelled failed.

## Remaining acceptance and future work

Real-GPU performance, subjective visual/gameplay acceptance, packaged OS acceptance, and natural full Horde/LATTICE round completion remain open. No automatic release claim follows from source tests. Full Arsenal, persistent settings and local movement prediction remain later work, not features completed in this batch.
