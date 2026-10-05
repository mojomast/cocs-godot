# COCS six-map population program — status and action queue

**Purpose:** precise "where we left off" for the Moth-asset / Blender map-variety program
(Helix Conservatory, Gravemill Foundry, Parallax Observatory, Vesper Viaduct,
Abyssal Pressureworks, Stormglass Causeway).
**As of:** 2026-10-05. Source of record: `feature/relay-campaign` @ `5c66f32f` (parent `91b0b801`).
Master checkpoint: `port/finish/MOTH_BLENDER_MAP_VARIETY_20261003.md` (newest state at top).
No claim below exceeds what the cited docs record; unmerged branches are labelled as such.

---

## 1. Runtime identity (measured on `feature/relay-campaign` @ `5c66f32f`)

`geometryHash` from `godot/multiplayer_worlds/generated/<map>.json`; GLB sha256 computed locally.

| Map | Runtime `geometryHash` | Runtime GLB path | Runtime GLB sha256 |
|---|---|---|---|
| helix-conservatory | `f068d1ab…965fa9b2` | `art/helix-conservatory/helix-conservatory.glb` | `0c462ffa475f02aa388101c38339d6d81eb3df9549a7d664ca65ec390c802d88` |
| gravemill-foundry | `8ebb148f…4fcde25f` | `art/worlds/gravemill-foundry.glb` | `46bf1648b32d23e337cd11b2c639a47f17d36c41361aab9434e1e621361e5935` |
| parallax-observatory | `906be2ae…6d4554` | `art/parallax-observatory/parallax-observatory.glb` | `c1dffd357545206d3f70870f850e441c5be148e652830a4a69835185a75610bd` |
| vesper-viaduct | `27c71cc8…f395ea7` | `art/worlds/vesper-viaduct.glb` | `6afe34c82d45f06c30dedc780f59ac6afa5200835b487d41705902d771fc0bfd` |
| abyssal-pressureworks | `32366a6c…5349b53be` | `art/worlds/abyssal-pressureworks.glb` | `fa6888d11ed95dee670b3200b141962e74d6ea17523aef3bcbd7edee149f16b1` |
| stormglass-causeway | `6afb8a36…753acce48` | `art/worlds/stormglass-causeway.glb` | `ff318582fd47ca633ef74da1aa4a6aa2b5b691800f12fb3210f3dac140cb5b33` |

**No map's runtime GLB equals its newest approved candidate.** Runtime is still the pre-variety
promotion for all six. Verified by comparing every runtime hash against the approved artifact
hashes in §2. This is the program's central fact: the variety work is staged/evidence-only.

---

## 2. Per-map status

Producer commit, artifact hash and integration commit are quoted **only** from the review docs.

### Helix Conservatory
- **Latest produced revision:** revision-4, attempt `x-03` (producer `171ffddb`).
  Master `46fe68d6ccb97c349812b6c4a5a600c3c9c90f19c50bee217378cb8f9029c856`;
  GLB `4943e353f4626a11f1e515b9046c92df30985ef725f399f651a8d8ddad953995`
  (verified present at `tools/godot-multiplayer/new-maps/botanical-correction/runs/x-03/helix-conservatory/helix-conservatory.glb`).
  157,518 triangles; 32,763 native capsule samples, zero errors.
- **Integration:** selected evidence merged as **`5f41d68e`** (`BOTANICAL_X_SELECTIVE_REVIEW.md`,
  `BOTANICAL_X_REVIEW.md`); producer tip `49462324` is patch-identical, not a distinct unmerged change.
  Successor *source* merged through **`6e1d4b1e`**; prior U attempt `243223d3` remains unmerged.
- **Blockers:** none specific to Helix. Original frame P1 closed by actual export (ten bearings,
  35 attachments, 810 footprint samples on Y16 terrace).
- **Next step:** source-only — dressing profile + promotion transaction once the program-wide gates land.

### Gravemill Foundry
- **Latest produced revision:** **R7 / attempt Y** (`26da91b3` + `f3b51b2c`).
  GLB `6325fdf0003813c5cb5a59aca3626f6756998fb53f8aaa143d9f3043f3caa44f` (15,012,592 B);
  master `96314db722902c12c8b5866edfd0d12844db3a99527eb746c58f61376dc09472`.
  R6 GLB `945978699f7b7ee4519f6078b68a508177a75905541f463c1777bf10f5efc47c`;
  R5 GLB `237dcc9d1b339116915d824f9896e6ee7daa57b0c13bab08c58da8d51445c9c8`. All three revision GLBs
  are present in `art/revisions/` and hash-verified.
- **Integration:** R7 merged as **`dd76b82a`**, package exclusion as **`dd6bc7c3`**; R5 `7ae3f2f5`/`96bc9758`,
  R6 `5641fec9`/`9c5eca6d`. **All seven tangent defects closed with zero waivers**
  (`FOUNDRY_R7_REVIEW.md`). Registry `tools/godot-package/staged_resources.mjs` holds all three as
  `staged-not-runtime-promoted` / `unpromoted-artifact-review-pending`; combined exclusion 211 files / 54,926,437 B.
- **Blockers:** public/hosted promotion only. Docs explicitly withhold manual-art acceptance ("broad pale/repetitive finishes"),
  and llvmpipe/llvmpipe-static timings (95.5 ms warm load, 124–331 ms/frame) are **not** gameplay/GPU acceptance.
- **Next step:** gated/promotion — requires parent grant to flip the staged registry status.

### Parallax Observatory
- **Latest produced revision:** **districts-v4 + AC glyph successors** (`cb769d81` + `ebca944d`).
  AC GLB `0903dc4f8487ff9011204a63421a398b3f647bd8b5baca4d1552aa67d00a660b` (19,006,932 B);
  master `3d5e9da74264a929e01b69f45d2c19e784d81d143516624b20e9a35c6a009fc5`.
  X districts-v4 GLB `6356cf895c65cec181e1c6c077118b98f3ee80cb567955b37835433971342422`.
  Prior AA attempt GLB `95e9da98a45565ca2aae90858a9e5027d9123e4ffd1347da98d5de8573141cd5` — **failed attempt**.
- **Integration:** AC merged as **`464604bb` / `388812d7`**; X evidence selected in **`5f41d68e`**;
  AA archived as failed evidence (`1b7dff8a`/`673d0a0f`/`badfedc3`/`dec159d4`).
  AC "closes AA's complete native basis-equivalence failure without waivers" (`PARALLAX_AC_REVIEW.md`).
- **Blockers:** tangent convention. 4,729/4,745 "nonorthogonal" records — the docs treat these as a
  **raw UV-derivative census, not a spec violation**; the spec-invalid set was the 16 singular glyph
  records AC already closed (`BLOCKERS_EFFICIENCY_20261005.md` §2; `PARALLAX_GLYPH_POLICY_REVIEW.md`
  recorded 4,729 remaining, and `8c43b112`/`a52e37b0` withdrew the unsupported shading-defect inference).
  Also open: authored-X **appearance** equivalence, 24 original captures with constrained views retained.
- **Next step:** source-only — implement the record classifier + bounded appearance contract
  (`BLOCKERS_EFFICIENCY_20261005.md` §2 recommendation; `parallax-tangent-provenance/README.md`).

### Vesper Viaduct
- **Latest produced revision:** urban-v3, attempt `x-03` (producer `171ffddb`), **staged evidence only** —
  master/GLB/captures were deliberately **not** copied into the selective integration (`BOTANICAL_X_SELECTIVE_REVIEW.md`).
  Candidate X identity from `NATIVE_BINDING_FOLLOWUP.md`: authority `397cedc8…`, geometry `fd8e7134…`,
  GLB `f859d49cc1b462b4a88e351d915518c49940ce24a7b8c2047c2d8f94f419e1db`, 64,311 tris, 29 meshes, 17 materials.
  64,311 triangles; 20,157 capsule samples with **184 contacts** (170 civic-stair + 14 roof-step).
- **Integration:** shared source merged (`33afe0ec`/`8b80875b`, `2f64d2de`); artifact **withheld**.
  Parapet P1 closed; the post-X binding correction `525b9fbe` and its review `30dbdc0f`
  (`POST_X_BINDING_REVIEW_20261005.md`, verdict APPROVE for selective **source** integration) are
  **unmerged**. Doc note: 184 records are static finite-capsule placements reconstructed at source,
  `scope: "source distance reconstruction of pinned X native contacts, not a new native run or waiver"`,
  `unreproducedContacts: 0`.
- **Blockers:** the prepared 60-journey native batch (6 groups × 10 walk-only cases) **has never run**.
  Root cause is process/physics: `godot/exploration/walker.gd` has `floor_max_angle = deg_to_rad(46.0)`,
  `floor_snap_length = 0.3`, `safe_margin = 0.02`, capsule radius 0.35, and `step()` calls only
  `move_and_slide()` — **no step logic** (verified in source; Godot proposal #2751 tracks built-in step-up).
- **Next step:** gated/native — one grant running all six groups with **continue-and-triage**
  (do not use `|| break`), commands already written in `tools/godot-multiplayer/new-maps/botanical-post-x/NATIVE_BINDING_FOLLOWUP.md`.
  Fallback is source-only: height-preserving collision ramps / 0.02 m edge bevels in the Vesper authority recipe.

### Abyssal Pressureworks
- **Latest produced revision:** **revision2-corrective-v**, worker `03b3db50`.
  Geometry identity `b010a0764e3754b9d1e6ff3839e7c319d871336cf5b242a36cd512dd9ee3aa86`;
  master `16e244942c84c810802fa56ec37efca5b39b95f2872d373175d68cc94e48d93f`;
  GLB `770c8622f6e9dc401fb6dc5cce4225efc5b930c1a88f29f9f0c324170db07f87`.
  229,620 triangles / 47 primitives / 30 packed images. Frozen T GLB `925883ef…`.
- **Integration:** merged as **`873ad2ac`** (`ABYSSAL_V_REVIEW.md`): closes the T interior terrace-contact P1
  for this successor. Corrective **source** merged as **`a8b3fe6b`** (`1cdf967e` is patch-equivalent).
- **Blockers:** the **next** P1 — new accessible terrace fins/ledges appear solid in the actual export but
  lack authority collision. `1cdf967e` moves two ledges and twelve fins beyond the retaining walls and
  extends the SW south wall across the 36 m deck edge (all 84 solid faces outward; clearances >0.52 m
  radius + 0.05 m bevel + 0.05 m margin; all 501 nav nodes connect). **Fresh Blender/native evidence is
  still required to close it** — no built artifact exists in the tree for it.
- **Next step:** gated/native — corrective build/reopen/export/probe under a new grant.

### Stormglass Causeway
- **Latest produced revision:** revision-2, coastal **T** attempt `f2d34471` (tooling `834ff85a`).
  Staged GLB `port/finish/map-variety/stormglass-staged-T-20261003/stormglass-causeway/stormglass-causeway-revision2.glb`
  — sha256 `ec8d8536239d1a481d3b1eadd489be3101739aa523d36e27d4ba0223daca96c4`, 9,110,464 B.
  46,850 triangles / 33 meshes / 36 images.
- **Integration:** staged evidence merged as **`c5c50a93`** from worker `2ed7a012`, confined to
  `port/finish/map-variety/stormglass-staged-T-20261003/`; 50 inventory hashes and 49 byte-identical
  original T files verified; **public runtime promotion pending** (`COASTAL_T_REVIEW.md`).
- **Blockers:** the documented **flat-road concession**. `recipe.mjs` has `roadRelief: 0`, road is Y=0
  everywhere; `game/race.mjs:303-305` passes `()=>0` as the vehicle ground callback so vehicles ignore
  terrain Y; `route_probe.gd` asserts `absf(hit.position.y) < 0.001` on every road ray
  (`MAP_VARIETY_REVISION_BLUEPRINT_20261003.md` §3.1). Plan A (scenery-only, road stays Y=0) was the
  chosen default. Racing/chase-camera/production-weather acceptance still pending.
- **Next step:** parent decision — keep Plan A or authorize **Plan B**, which requires a coordinated
  versioned terrain/race/vehicle revision (4 coordinated changes listed in the blueprint) and re-proving.

---

## 3. Cross-cutting status

### Walker support-query diagnosis
- **State:** source diagnosis integrated and independently approved. `7c1f196b` → integrated as **`d008a28b`**;
  review `95cdaf4c`, integration `721bddd5`. Source receipt `25382b4dd0d51b1e671a97a1478bb8bee5daaf0fff305ea024016d2c94082c40`.
- **Finding:** at AM frame 550, .42/.18/−45 gives original DOWN32 45.776894°, parity/parent floor 45.646724°,
  fresh guard 47.476992°. Identity passes, velocity is zero, **normal fails**; the landing-plane guard is
  **unreached**. Normal-length errors <4.7e−8 do not explain it. A conditional arithmetic reconstruction
  (`recovery residual = travel − safeFraction × motion`) fits the recorded values but is **not** proof of
  the active backend (`WALKER_SUPPORT_QUERY_DESIGN_REVIEW.md`, `POST_X_SOURCE_REVIEW.md`).
- **Refinement:** exact-zero-motion requests **omitted** from the executable proposal after inspecting
  `godot_space_3d.cpp:698-699` (motion divided by length with no zero check). Do not substitute epsilon motion.
- **Next:** a bounded two-case finite-motion comparison package (design only, no probe staged).

### Production motion accounting
- **Unresolved.** Repeatedly stated as open across AG→AM: whole-frame displacement vs `move_and_slide`
  diverge; planner and parent use different recovery-restart models and different down-query lengths
  (AE: final Y differed from proof by **21.845102 µm** against a 1 µm bound).
- **`BLOCKERS_EFFICIENCY_20261005.md` §3** prescribes one canonical per-frame ledger
  (`pre_lift_delta, slide_delta, snap_delta, collision_response_delta, total_delta, …`) plus a single
  reconciler asserting `total_delta = slide + snap + response` within tolerance.
- **Explicitly:** even a fully successful synthetic campaign would not resolve production accounting
  (recorded in the AM/AK/HH checkpoint entries).

### Package / receipt promotion state
- `tools/godot-package/staged_resources.mjs` holds foundry-r5/r6/r7 as
  `staged-not-runtime-promoted` and `unpromoted-artifact-review-pending`; exclusions total
  **211 files / 54,926,437 B**; accepted native selection stays **2,494 files**; **seven production receipts unchanged**.
- Stormglass staged evidence and Abyssal V are merged but explicitly **not promoted**.
- `port/finish/{ABYSSAL,PARALLAX}_PACKAGE_PROMOTION.md` describe *earlier, different* promotions
  (Abyssal production-I `25ad4fc3…`, Parallax production-C `f369bc9d…`) and say so themselves. Do not read
  them as promotion of the variety revisions.
- Every doc in this program states promotion/hosted/manual/weather acceptance as pending. **None is claimed.**

### Dressing profile gap
- `godot/multiplayer_worlds/dressing/profiles/` has **three** profiles: helix-conservatory,
  gravemill-foundry, parallax-observatory. **Vesper, Abyssal and Stormglass have none.**
- `dressing/profile.gd` `IDENTITIES` and `dressing_resources.mjs` `DRESSING_IDS` are hard-coded to the same
  three. `binder.gd:apply()` returns `status:"ineligible"` for anything outside `IDENTITIES`, so the three
  unprofiled maps silently get **no runtime dressing** — not an error, a gap.
- Profiles are bound to `geometryHash`, so any promoted revision changes its identity and the profile
  must be re-derived. `dressing_resources.mjs` asserts `profile.geometry_hash === generated[id].geometryHash`.
- Blueprint open decision (d): whether Gravemill should join the shared Moth finish, which would change
  its GLB identity **and** its dressing profile.

---

## 4. Prioritized queue — can finish now, source-only

**Q1 — Parallax tangent record classifier + bounded appearance contract** (unblocks the largest stated gate)
Files: `tools/godot-multiplayer/new-maps/botanical-parallax-aa-diagnosis/` (census), existing census output
from `8f166beb`, `parallax-tangent-provenance/README.md` "preferred next scope".
Work: classify records into spec-invalid (non-unit T, W ∉ {±1}, N∥T, UV rank failure) vs
spec-valid-but-derivative-disagreeing; publish both counts; add appearance contract for saltstone face 11823
and the five reversed-U corners. Update the qualification record so 4,729 stops reading as a gate.
Tests: `node --test tools/godot-multiplayer/new-maps/parallax-observatory/*.test.mjs` plus the new classifier tests;
re-run the 141 frozen AA hashes already covered by `1c661b95`.

**Q2 — Canonical per-frame motion ledger + reconciler**
Files: `godot/exploration/walker.gd`, the walker harness under `tools/godot-multiplayer/new-maps/walker-*/`.
Work: emit the ledger fields named in `BLOCKERS_EFFICIENCY_20261005.md` §3 from one place; single reconciler
asserts `total_delta = slide + snap + response`; guard reads the same ledger; document physics tick/fixed dt.
Tests: existing walker source suites (`walker-step-up`, `walker-snap-compare`, `walker-parity-*`); add
regression that a pre-lift outside parent accounting is labelled, not silently absorbed.

**Q3 — Land the post-X binding correction + its review into the branch**
Source `525b9fbe` and review `30dbdc0f`/`dc7b73ef` are unmerged although the review verdict is
**APPROVE for selective source integration**. Reviewer independently ran 13 Python + 12 Node tests, the
pinned-X `verify_art_fixture` integration, 600 X + 264 U frozen re-verification, a 7-mutation negative matrix,
and a glTF census of both GLBs.
Files: `tools/godot-multiplayer/new-maps/botanical-post-x/{art_binding.py,verify_art_fixture.py,prepare_native.py}`,
`godot/tests/new_maps/botanical_post_x/art_binding.gd`, `port/finish/map-variety/POST_X_BINDING_REVIEW_20261005.md`.
Tests: `python3 -B -m unittest discover -s tools/godot-multiplayer/new-maps/botanical-post-x -p 'test_*.py'`
and the 12 Node tests named in the review.

**Q4 — Vesper height-preserving ramp/bevel authority proposal (source-only, parallel to any grant)**
Prepare the fallback so it is ready if the batch shows real stalls. Must preserve authority support heights —
the blueprint's nav490 example shows a naive continuous civic ramp moves Y13.8 → Y13.7727, so use thin
bevels or height-matched ramps. Re-run the static census tooling
(`botanical-post-x/diagnose_contacts.py` + `contacts-evidence.json`).

**Q5 — Abyssal corrective-source verification (source-only half)**
`1cdf967e`/`a8b3fe6b` is integrated and reviewed but unbuilt. Source-only: verify `build.mjs --check`,
`test_layout.py`, `test_service_cave_contacts.py`, `verify_archived_service_cave.py` all pass on current
HEAD and that the 84 outward faces / 0.52 m clearances / 501-nav connectivity still reproduce, so the
eventual native grant has a green precondition.

**Q6 — Dressing profiles for Vesper / Abyssal / Stormglass (source-only, blocked on identity)**
Cannot author against the current `geometryHash` if the promoted revision changes geometry. Correct order is
**after** each map's promotion transaction. If pursued now, it must target the staged candidate identities
(`fd8e7134…` Vesper, `b010a076…` Abyssal), and `profile.gd IDENTITIES` + `dressing_resources.mjs DRESSING_IDS`
must be extended in the same change. Lower priority than Q1–Q5 for that reason.

---

## 5. Gated on heavy/native grants

| Item | Gate | Prepared material |
|---|---|---|
| Vesper 60-journey batch (6 groups × 10) | one grant; continue-and-triage, **not** stop-on-first-failure | `botanical-post-x/NATIVE_BINDING_FOLLOWUP.md` exact commands |
| Abyssal corrective-v build | corrective native grant | source in `abyssal-pressureworks/revision2-corrective/` |
| Stormglass Plan B drivable relief | **explicit parent authority**; 4 coordinated code/recipe changes | blueprint §3.1 items 1–4 |
| Foundry R7 promotion flip | parent grant to change registry status | `tools/godot-package/staged_resources.mjs` |
| Stormglass / Abyssal / Helix public promotion | parent promotion transaction per map | precomputed exclusions |
| Walker bounded two-case comparison | new grant after source review | `walker-support-normal-diagnosis/DESIGN.md` |

**Stop conditions already recorded for any Vesper grant:** asserts-enabled Godot 4.5.2 required or the
binding gate is decorative; first group is a binding-calibration run; a failed group stops the *diagnostic
sequence*, but for triage purposes every case should still be attempted and classified by predicate.

---

## 6. Evidence discipline and conflicts

1. **Runtime ≠ latest candidate, for all six maps.** Every runtime GLB hash differs from every approved
   artifact hash. Nothing in this program is runtime-promoted.
2. **`184` is not a movement result.** The contacts are static finite-capsule placements, source-reconstructed
   (`contacts-evidence.json` `scope` field; `unreproducedContacts: 0`). `BOTANICAL_X_REVIEW.md` and the
   checkpoint table call them "native capsule result" contacts blocking acceptance — that framing is accurate
   for *acceptance* but they are not `Walker.step` outcomes. Both statements are in the docs; the distinction matters.
3. **Parallax 4,729 — conflicting framings.** `PARALLAX_GLYPH_POLICY_REVIEW.md` (via the checkpoint, line ~523)
   records 4,729 nonorthogonal entries remaining **as a review finding**. `BLOCKERS_EFFICIENCY_20261005.md`
   (2026-10-05, newest) argues that figure is a raw UV-derivative census, **not** a glTF spec violation, and the
   spec-invalid set was the 16 records AC closed. The newer doc is research/synthesis and explicitly
   "not a replacement for any review" — so 4,729 should be treated as **open question, not settled**.
   Additionally `8c43b112` **withdrew** the earlier shading-defect inference; `a52e37b0` confirms only that
   a counterexample exists to the faulty inference, **not** full renderer equivalence.
4. **Abyssal WeatherService claim was corrected.** The producer report said the parent snapshot had no
   `WeatherService`; parent verified `a8b3fe6b:godot/ambience/weather_service.gd` exists. Accurate boundary:
   that isolated stage did not exercise it. Captures are neutral staged presentation.
5. **`dcb`/checkout drift.** The shared checkout was being advanced during the post-X review; the review
   records merge-base `32eba401` against both `91b0b801` and `5c66f32f` as the load-bearing fact, not the tip.
6. **Grant/worker ancestry ≠ merge state.** Several producer tips (`49462324`, `2ed7a012`, `1cdf967e`,
   `b81730f7`, `0f108974`, `7c1f196b`, `3a0da75e`, `48c7e6c1`) show as "unmerged" by branch tip but are
   **patch-identical** (`git log --cherry-mark` shows `=`) to merged parent commits. Only these are genuinely
   unmerged content: **`525b9fbe`** and its review **`30dbdc0f`**, plus the Abyssal corrective *artifacts*.
7. **Performance numbers are not acceptance.** llvmpipe 124–331 ms/frame (Foundry), 167–315 ms median 214
   (R5), 95.5 ms warm load — the docs explicitly say these do not establish gameplay/GPU performance.
8. **Triangle counts are advisory by user direction** (150,000 targets; `dd05f50c` made global gates advisory).
   Abyssal's 79,620 overage and Foundry's 111,454→87,566 sequence are recorded, not blocking.
9. **Stormglass Plan A vs B is an unmade parent decision**, not a defect. The flat-road concession must stay
   truthfully reported (`MOTH_BLENDER_MAP_VARIETY_20261003.md` line ~1374).
10. **Synthetic success ≠ map acceptance.** Stated repeatedly (AH, AK, AM, AB entries): even a passing
    synthetic campaign "would not resolve production accounting or map acceptance".

### Key commit index
Merged into `feature/relay-campaign`: `18201a06` coastal source · `dd76b82a`/`dd6bc7c3` Foundry R7 ·
`873ad2ac` Abyssal V · `c5c50a93` Stormglass T staged · `5f41d68e` Helix/Parallax X selection ·
`7ae3f2f5`/`96bc9758` R5 · `5641fec9`/`9c5eca6d` R6 · `a8b3fe6b` Abyssal corrective source ·
`464604bb`/`388812d7` Parallax AC · `2f64d2de` X shared source · `6e1d4b1e` botanical successors ·
`8b80875b`/`33afe0ec` Vesper Z fixture · `ca84e802`/`d8822447` Parallax tangent contract ·
`d008a28b` + `721bddd5` support-query diagnosis/design · `ebbb7d20` AM failure archive.
Unmerged and material: `525b9fbe` + `30dbdc0f` (post-X binding), Abyssal corrective-v **artifacts**,
Foundry R7 **promotion**, all map **promotion transactions**.