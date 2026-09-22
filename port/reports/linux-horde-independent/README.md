# Lead rebuild: local Horde and ten-route Linux prototype

**PASS:87 integrated gates,16 launcher/ownership/cleanup cases, and six exported
default-ten-wave Horde startup checks.** This is bounded startup acceptance,
separate from the native one-wave combat/death/restart records and prior exported
popup-free lobby gameplay. No full ten-wave completion is claimed.

## Artifact and play

Archive:
`/tmp/opencode/lead-native-linux-package/builds/1790057930032905812/cocs-native-linux.tar.gz`

- Archive SHA256: `d57d35dfd625d81c3fa360036fdde98f133f222aa058c062c21c4bcd8b0d88f0`
- Manifest SHA256: `3f05e49a140543d108ed7f0d152488013aef1b2c8c2f3190f58c43428dbb54c2`
- Build inputs SHA256: `327b0efac1741eb20aac786a9397bc6323f6144c3575d127d5169fdc8078b5e8`

```sh
node /tmp/opencode/cocs-package-play-m8dgtoqi/cocs-native-linux/run.mjs --experience=horde --map=meridian-exchange
node /tmp/opencode/cocs-package-play-m8dgtoqi/cocs-native-linux/run.mjs --experience=lobby
```

Fresh unrelated extraction:9 maps,9 compiled release scenes,10 routes; no tests,
GLB probes, checkout references, symlinks or editor/git/npm needed at play time.
The play PATH contains only Node. All114 packaged files and256 build inputs match
their manifests/current checkout after verification. Generated binaries stay
outside Git.

## Source and adapter boundary

Source closure contains84 modules, all byte-checked against the pinned source
commit. The two port-owned Horde modules are separately committed/hash-checked:
`port/native-horde/authority.mjs` and `input-buffer.mjs`. Horde reaches73 source
modules plus those adapters. No observer/oracle/test/validator enters the shipped
runtime closure. Public Room still rejects local-only Horde configuration.

Only the Horde route constructs the local adapter and requires its exact
`cocs-local-horde` / transport1 / localOnly / allocated-port readiness identity.
Other owned routes retain the public server; external lobby creates neither.
Wrong modes/maps/options/readiness fail before native gameplay. The common Horde
route preserves default10 waves and exposes no waves/endless/upgrade/endpoint
override. Source Match/input/scoring/physics remain unchanged.

## Fresh final exported checks

The inherited14 launcher cases plus Horde ordinary window-close and native-crash
cleanup pass. Six additional actual-product observations cover Meridian,
Verdant and Ember at960×640 and1280×800: **881 public snapshots total**.
Each reaches wave1/10,3 lives,3 live NPCs, not-over state and preserved source
startup events including `horde-modifier` with `sourceId:"swarm"`. Event ordinals
are adapter-local identities, not global source serials.

The external observer instantiates the real exported Horde scene as a child,
reads public signals/state and records the actual Horde scoreboard composition.
Tab press/release uses XTest; explicit window close and native exit are checked.
No movement/fire, target override, Match access, source injection or accelerated
simulation occurs. The local adapter is imported without an observation hook.
These startup receipts are not a repeat of the source-object gameplay oracle.

The lead directly opened all six fresh PNGs. Wave/enemy/lives/score/SWARM strip,
roster and two-line help are readable at both sizes. At960×640 the held-Tab board
partly covers lower health/ammo; releasing Tab restores them. The roster still
calls player plus NPCs “4 players.” These known layout/copy limitations remain.

All22 recorded case port/PID sets were independently checked absent/closed after
the run; `lead-check.json` retains results. No shared service was restarted.

## Commands and limits

```sh
PORT=0 TMPDIR=/tmp/opencode GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 python3 tools/godot-dev/verify.py
python3 -B tools/godot-package/build.py --state /tmp/opencode/lead-native-linux-package
python3 -B tools/godot-package/verify.py --build-result /tmp/opencode/lead-native-linux-package/builds/1790057930032905812/build-result.json --output NEW_DIRECTORY --world-commands-capture
```

One final integrated package attempt; all original failed reviews, event/input
defects, visual failures and fixes remain in their historical report trees.
Full ten-wave/boss/defeat/upgrades, worst-wave resources, complete action effects,
hardware/audio/human play and other combat/board popup paths remain open.
The clean exported full lobby flow is the prior package's separate result;
this final package checks its startup/ownership, not another full lobby round.
