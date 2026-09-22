# Windows operator demo — release evidence

Download: <https://github.com/mojomast/cocs-godot/releases/tag/windows-demo-2026-09-22>

Build/runtime revision: `fc318528fee9be04f74d5e82fe023a2adab95d1a`.
The Windows smoke harness was corrected in `928dcd8`; those changes affect
verification only. The ZIP remained byte-identical through all Windows attempts.

| Artifact | Value |
|---|---|
| ZIP | `cocs-native-windows.zip`, 68,520,143 bytes |
| SHA256 | `fd02b9de5bc454acb5a2b4d20502016e72ea45a1aef82cfe39915eb94aa6281d` |
| Manifest SHA256 | `ff17e08eecb17cc5af3574800908006ef2f6c96a4ff71a948cacde864a7d6a26` |
| Target | Windows x64, Godot 4.5.2 release export, bundled Node 22.22.0 |
| Models | Explicit candidate staging override; baseline remains the source default |

## Actual native Windows verification

[Run 35700483115](https://github.com/mojomast/cocs-godot/actions/runs/35700483115)
passed on `windows-latest`. Downloaded logs and run metadata are in
`evidence/windows-native/`.
Readable Windows `.log` copies normalize line endings/final blank lines; adjacent
`.log.gz` files preserve the exact downloaded bytes. Hashes are recorded in
`evidence/windows-log-normalization.json`.

- Downloaded the release ZIP and checked its adjacent SHA256.
- Fresh extraction into a path containing spaces, launched from an unrelated cwd.
- Verified all **119** manifest-listed package files and both runtime versions.
- Invoked the actual **Play.cmd** with bundled Node and Windows Godot executable.
- All three combat maps passed normal-rate source-authoritative snapshots,
  movement, firing, remote-pose and pickup checks. Each log confirms
  `PORT_OPERATOR_MODEL res://player_models/candidate.gd`.
- Native process exit, owned-loopback listener closure and launcher temp cleanup
  passed after every case. No system Node/editor/npm/source checkout was needed
  by the extracted package.
- The packaged operator preview scene loaded successfully from the PCK.

These are **headless Windows** checks. Desktop graphics, mouse feel, hardware
performance and audio still require human play. The three combat smoke exits
emit a non-fatal Godot `ObjectDB instances leaked at exit` warning, retained in
full in the logs; process/listener cleanup passes, but leak-free engine shutdown
is not claimed. The preview exits without that warning.

## Cross-export and regression verification

`evidence/cross-export/` exercises the exact Windows PCK with the pinned Linux
release template after fresh extraction. All three map smoke cases pass with
candidate-model markers; both 960×640 and 1280×800 preview PNGs were directly
opened and inspected. This is **Linux rendering**, not Windows graphical evidence.

The complete **88-gate** aggregate passed locally (`../reports/verification.json`)
and in hosted Ubuntu [run 35700075573](https://github.com/mojomast/cocs-godot/actions/runs/35700075573).
The downloaded hosted summary, console and artifact inventory are retained in
`evidence/hosted-native/`. The added gate validates procedural operator geometry.

## Preserved failed attempts

- `evidence/aggregate-timeout/`: the first local aggregate was interrupted by a
  120-second outer tool deadline during a normal-rate lifecycle gate. It was
  rerun with a 600-second deadline and passed all88 gates.
- `evidence/windows-draft-access-failure/`: run35700163521 could not download the
  draft release with read-only contents permission. GitHub requires contents
  write access to read unpublished draft assets; the job still only downloads.
- `evidence/windows-quoting-failure/`: run35700326602 verified all119 file hashes
  and runtime versions, then its Node→cmd.exe test invocation failed quoting a
  path with spaces. `windowsVerbatimArguments:true` fixed the harness; packaged
  Play.cmd and ZIP bytes were unchanged.

`evidence/build-result.json`, `package-manifest.json`, import/export logs and the
server-closure report record the build. Generated executables and archives remain
outside Git and are attached to the release. See [PLAY.md](PLAY.md) for controls,
available routes, model/demo limits and a reproducible build command.
