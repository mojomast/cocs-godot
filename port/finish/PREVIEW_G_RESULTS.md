# User test preview G — built and locally verified

**Frozen artifact candidate:** `a0866981d28ab5e4c2227bfa41d25aadeba0fe3b`.
This report is a later documentation commit; it does not change the artifact anchor.
Parent owns pushing that exact candidate, actual Windows CI and prerelease publication.

Both builds used `--preview --source-derivative`, pinned Godot 4.5.2 official
editor/templates, retained verified caches and `LP_NUM_THREADS=1`, serially under
`PREVIEW-PACKAGE-20261003-G`. No asset production or full 142-case ledger was run.
No runtime compile fixes were needed. The package remains non-final, with three
validated promotions and four explicitly pending units in README/manifest/intent:
scenery, Vesper Viaduct, Abyssal Pressureworks and Stormglass Causeway.

## Windows artifact — ready for parent CI/publication

- ZIP: `/home/mojo/.tmp-on-disk/cocs-preview-g-windows/builds/1790996064396000390/cocs-native-windows.zip`
- Bytes: **148,557,253**
- ZIP SHA-256: `45046d17d7176ec24a6860569ae7857a0d3368ee163b8669bfffeba4f995fe23`
- Manifest SHA-256: `5162e1641f740bf939d7963ddf4b51fe3b1038a1cc7e6148410f1946d5ec774d`
- Fresh extraction: `/home/mojo/.tmp-on-disk/cocs-preview-g-windows/extracted/cocs-native-windows`
- Recorded-Git/archive identity: **passed**, `.../cocs-preview-g-windows/archive-validation.json`.
- Pinned Node 22.22.0 is bundled. Actual Windows execution is **pending parent CI**;
  Linux validation of Windows archive structure is not Windows execution proof.

## Linux artifact — extracted runtime checks passed

- Archive: `/home/mojo/.tmp-on-disk/cocs-preview-g-linux/builds/1790996161051408385/cocs-native-linux.tar.gz`
- Bytes: **108,294,970**
- Archive SHA-256: `4eb6abe8f8eca4c0029b989711bbe6983d0a7a2d887f0c2d8d0afd073bf93b83`
- Manifest SHA-256: `ead1f8be2dc4e8e20ec64093887b6bd3eaca5432bf201499f05d9f2035d47c53`
- Fresh extraction: `/home/mojo/.tmp-on-disk/cocs-preview-g-linux/extracted/cocs-native-linux`
- Recorded-Git/archive identity: **passed**, `.../cocs-preview-g-linux/archive-validation.json`.

Bounded checks from clean external working directories:

1. `verify_final.mjs`: complete declared final/production resources and raw bytes,
   all nine imported fighter rigs/finishes, Home → Fighting training → Home.
   `PACKAGE_FINAL_OK operators=9 ... raw_resources=56`.
2. Graphical Xvfb/gl_compatibility: actual Home Fighting button, AI/local/training
   match starts and advancing production simulation ticks, then Home teardown.
   Real extracted PCK; no replacement scene/core. Screenshots retained.
3. Packaged executable-relative Campaign launcher, Rootfall smoke:
   400 acknowledgements, 58 combat shots, movement/fire/first-person passed,
   three production robot models loaded, clean `PACKAGE_STOPPED`.
4. Graphical Sunscar combined-arms startup against the extracted source authority:
   actual production demo reached active phase, ten fleet children, screenshot,
   clean client quit and authority listener closure. This is startup proof, not a
   repeat of production-E's nine-client journey or a full vehicle interaction gate.

No `SCRIPT ERROR`, `ERROR:`, failed assertion or failure marker appeared in the
successful native logs. The attempted combined-arms `--smoke` launcher invocation
was correctly refused because that route has no smoke option; `smoke/vehicle.log`
is retained. The actual graphical startup check replaced that invalid invocation.
External smoke scripts under `/tmp/opencode/preview-g-*` are test tools, not shipped
PCK content. Dummy audio/software rendering does not establish audio/GPU acceptance.

Evidence root: `/home/mojo/.tmp-on-disk/cocs-preview-g-linux/smoke/`:
`final/final-result.json`, `final/final-native.log`, `gui.log`, `campaign.log`,
`vehicle-gui.log`; screenshots `home.png`, `fighting-ai.png`, `fighting-local.png`,
`fighting-training.png`, `vehicle-startup.png`. Process records accompany logs.
Build logs and originals remain under each owned state's `builds/` directory.

## Source verification and explicit release

Preview channel + historical manifest tests: **47/47 passed**. Earlier fixture
failure from a historical builder absent in a synthetic repository was corrected
before the passing run. Missing/tampered promoted assets cannot be preview fallbacks;
channel/flags/intent/pending-name mismatches are rejected, and default final still
requires all seven units.

**Grant G released at 2026-10-03T03:00:59.657048Z.** A fresh process-table audit found
zero processes (including zombies) in all seven owned groups:
1047468, 1055498, 1062260, 1065099, 1066250, 1067127, 1071060.
Receipt: `/home/mojo/.tmp-on-disk/cocs-preview-g-linux/HEAVY_GRANT_RELEASE.json`.

No CI dispatch, draft/release creation or publication was performed by this lane.
Pending final production, native freeze/manual/audio, HUD accessibility/performance
and native Windows checks remain explicit. Parent can publish the clearly labeled
test prerelease after its Windows launch gate; existing published release untouched.
