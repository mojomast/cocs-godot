# Integrated popup-free Linux lobby — bounded acceptance PASS

The lead rebuilt the current combined runtime and ran a fresh full two-client
flow. **82 live checks / zero engine errors**, independently audited with
**156 assertions** and **3,855 source/native application matches**. The separate
generic package suite passes all **14 startup/ownership/cleanup cases**.

## Artifact and launch

Archive:
`/tmp/opencode/lead-native-linux-package/builds/1790056603963977358/cocs-native-linux.tar.gz`

- Archive SHA256: `bb8cbf1a83304f69cd850004abf5e209074626f5da19d36e4118cff65df6ee0d`
- Manifest SHA256: `6384152923e1667e1e3a9839199d95431fd85faac7ede7fc83d02ef49cbbee54`
- Build inputs SHA256: `dce281b29a961698e56e9e2699ee92a5ad986a26e4f6dcc28ceca94058511321`

```sh
node /tmp/opencode/cocs-package-play-0l_4p9qk/cocs-native-linux/run.mjs --experience=lobby
```

The fresh unrelated extraction contains all9 maps/eight scenes/nine routes and
excludes tests/probes. Node-only play PATH has no editor/git/npm. Official release
executable is unchanged from the one with popup errors; the new lobby uses only
inline native controls. Production bytes remain unchanged after verification.

## Fresh full flow

`full-flow/` records one95.343s attempt, using the unchanged packaged authority
and actual exported product scene. External observer sends engine input events;
it does not select widgets directly, change source state or inject timing.
Source results occur at60.0167s,59.365s wall after round start.

- Explicit host Create/config/Start and guest Join.
- Living host displacement18.985m/15 shots; guest18.698m/15 shots.
- Active Leave, then separate read-only spectator connection: **1,464 applied
  snapshots**, only one Join and one Leave, zero player/config/start messages.
- Host moves15.625m while spectated; spectator's delayed renderer shows15.756m.
- Spectator sees natural results, explicitly leaves, and a **new guest** joins
  between rounds. Host restarts; fresh guest captures and moves17.407m/15 shots.
- Final explicit Leaves, zero accumulated popup callbacks and zero engine errors.

This does not promote a spectator automatically or establish token resumption.
Source-applied movement/fire and rendered snapshots are audited independently of
input receipts/ACK high-water. `audit.json` records exact counts and effects.
The reviewed auditor was adapted only for the integrated paths, one full-flow
case, and integration preservation scope; `lead-audit.py.txt` retains that script.

## Lead visual and regression review

Opened actual exported menu1280×800, results960×640, spectator1280×800 and fresh
guest-capture1280×800 PNGs. Inline selected value/count and controls are readable;
Leave/Restart, status, scoreboard and equipment panels fit their states.
The lead additionally ran63 graphical selector checks and all80 aggregate gates.
The separate agent targeted release run remains its own evidence, not a second
lead run.

`tools/godot-package/verify_lobby.py` now wraps the reviewed inline-selector flow
and checks artifact/runtime hashes before execution. Historical OptionButton
observers remain unchanged in their old reports. The wrapper was updated after
building; it is external test tooling, not shipped runtime.

## Preservation and limits

Original failed full flow,14-error release/debug comparison and X11 discovery
failure remain immutable in their earlier report directories. Only the lobby
popup path is replaced. Combat setup/board popup issues, human/OS input, hardware
audio, adverse networks and broader mode completion remain open.

All full-flow children/listeners/temp environments were cleaned up. The generic
suite separately verifies external authority preservation on client close and
interrupt, then closes its own authority. No shared service was restarted.
