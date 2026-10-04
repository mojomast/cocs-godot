# AL — bounded baseline characterization, completed and released

Base `b5deca56`; branch `astra/walker-baseline-characterization-al`.
Approved source `3b2fb4cd`, parent-integrated `b5deca56`.
Read-only archive helpers: **75271920**.
Authority: **MOTH-BLENDER-20261004-AL**, exactly one engine invocation.

## Result

**Native collection complete; Godot0, supervisor0; strict Python replay true.**
First parsing occurred inside that sole invocation. No script/parse/admission
failure markers occurred; the raw engine log contains the banner and its original
trailing blank line. No retries, source corrections or additional native work.

All eight canonical profiles completed: **six blocked with target witness, two
arrived, zero unresolved, zero faults, zero unrun**. Twenty settling responses
per profile plus800 input responses give **960 ordinary returned responses** and
960 recorded read-only downward support observations, below the2,080 cap. Eight
distinct body RIDs and eight distinct capsule shape RIDs were recorded. No
candidate bodies, UP/lookahead planner queries or assists were used.

| Case | Radius / rise / yaw | Input responses | Outcome | Terminal proof frames |
|---:|---|---:|---|---|
|0|.35 / .15 / −45°|127|blocked_with_target_witness|29–148:120 responses|
|1|.35 / .15 / +45°|127|blocked_with_target_witness|176–295:120 responses|
|2|.42 / .15 / −45°|21|arrived|334–336: final3 landing responses|
|3|.42 / .15 / +45°|21|arrived|375–377: final3 landing responses|
|4|.42 / .18 / −45°|126|blocked_with_target_witness|404–523:120 responses|
|5|.42 / .18 / +45°|126|blocked_with_target_witness|550–669:120 responses|
|6|.42 / .20 / −45°|126|blocked_with_target_witness|696–815:120 responses|
|7|.42 / .20 / +45°|126|blocked_with_target_witness|842–961:120 responses|

`referenceAgreement=true`: both .35 references blocked and the .42/.15/−45
ordinary-capable reference arrived. The previously unmeasured +45° control also
arrived **in AL**; this is a fresh observation, not a retroactive inference about
AK's unrun +45° baseline. Arrival is legitimate characterization data.

**No height is selected.** `selectedHeight=null`; `selectionQualified`,
`candidateAdmission`, `nativeStepAdmission` and `productionPromotion` are false.
Both .18 and .20 blocked at both yaws in this fixed matrix, but neither result
establishes native candidate feasibility or authorizes another invocation.

## Independent inspection of actual operands

`response-chart.csv` retains all960 returned rows with actual positions, clocks,
whole/parent/last motion, target-slide angles/points, support identities and
classification replay. `native-detail.json` binds these to the raw receipt.
`independent-terminal-proofs.json` independently reconstructs all eight terminal
windows directly from raw operands without calling the policy predicates.

### Three blocked radius/rise families

For **each** of the120 responses in **each** of the six blocked windows:
continued input `[0,-1]`, requested horizontal motion≈.1m, returned ordinary
parent call, grounded state, whole displacement0, goal not reached, fresh valid
downward query and qualified walkable base support were verified. Every response
also has an actual intended-target ordinary slide contact with shape/localShape0,
low-band target point and head-on≈1.0. No ancient-contact or empty-query shortcut.

| Family, both yaws | Target ordinary normal angle | Actual target point Y | Final along | Downward-query evidence |
|---|---:|---:|---:|---|
|.35/.15|51.3068921567°|.150000005960464|−.299999876855|base UP contact plus steep target contact56.3916170765°|
|.42/.18|51.9454279984°|.180000007152557|−.399999892002|one base UP contact|
|.42/.20|55.3457820025°|.200000002980232|−.399999892002|one base UP contact|

The .35 query's mixed contact set is preserved: its steep target contact is not
walkable base support. At .18/.20 the downward query sees base only, while the
separate **ordinary slide record** supplies the target obstruction witness.
These are distinct measured operands. The helper preserves floating head-on
reconstruction values (including1.0000000000000002 roundoff), rather than silently
clamping raw evidence to an idealized value.

### Both .42/.15 ordinary arrivals

Both have six consecutive qualifying ordinary landing responses at completion;
independent final-three checks confirm full footprint, continued input and fresh
exclusive target support. Target/support shape and local shape are0, normal isUP,
and maximum plane error is **5.960464011e−9m**, below the unchanged1µm bound.

* −45° finishes frame336 at
  `[-.712754607200623,.165570169687271,.712753057479858]`,
  reconstructed along **1.007986136329**.
* +45° finishes frame377 at
  `[.712615251541138,.165551975369453,.712616205215454]`,
  reconstructed along **1.007790827833**.

The first target ordinary contacts are46.5527325025°/46.2296955080° at frame322
for−45°, and46.4976760694°/46.2279125469° at frame363 for+45°. Upward whole-frame
motion occurs on322–326 and363–367 respectively. Mixed base-floor contacts and
aggregate grounded state do **not** uniquely identify the internal target-contact
classification branch. The pinned .01rad engine allowance remains consistent
diagnostic context, not a unique backend-causation claim; full-tread arrival uses
explicit46° support criteria unchanged. This is qualitative reference agreement,
not a claim that AL reproduces AK's endpoint bit-for-bit.

All ordinary-frame accounting passes the reviewed validator. That does not answer
the separate production candidate pre-lift accounting question. Instrumented
completions/support observations are not an engine-internal physical-call total:
`physicalCallCounts=null` and `parentInternalCallsTraced=false` remain explicit.

## Seals, lifecycle and release

Attempt: `baseline-characterization-al-01` under the dedicated native test folder.
Seven reviewed scripts plus minimal `project.godot`; no full-game assets/autoload.

* Source SHA256: `8ddfd02d9fac88a5a5f6e3dcdb34f432a2654bbbfc9e045ab91949d8df1882a4`
* Grant SHA256: `f5fca7640bcb438c1a3b9d1c1895c9c30c0d485e1a41330a9c00278f63f4cfcd`
* Engine SHA256: `5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`
* Dependencies SHA256: `7ecbd6a2f300fbbc698eea47c47209ae710a64b57e02a72a4d63fd044d7c94e4`
* Native receipt SHA256: `f9e77adc174d3a4cc03b9ced716e5f89888ff2163217580bd1bd55cb9e17fc04`
* Supervisor SHA256: `0e6b99eac0eb60336eaa325ff32607b94c28b45f7748cc6186987c54b400b303`

Exact engine path, verified size/hash, eight-key fresh grant, argv, command,
thread environment, source/dependency bindings and ordering are archived. The
unchanged Godot4.5.2 binary is identified by hash and absolute path, not copied.
AK51 is bound failed-positive lineage, not a passing predecessor or reused grant.

Owned **PID/PGID3528101, startTicks628660036**. The supervisor held the shared lock
through receipt finalization and measured three empty-group audits. Its native
recorded interval was08:44:16.793780Z–08:44:32.670870Z, about15.87709 seconds.

The owner then independently measured the sole owned group empty three times:
08:45:10.190346Z,08:45:10.411386Z,08:45:10.632368Z. Lock available at
**08:45:10.854044Z**; explicit **AL release08:45:10.854070Z**.
No queued work, remaining authorization, or engine invocation after release.

## Verification and preservation

After release: **34 current source/offline/mock tests +5 approved-design tests =39
passed**. Native collection and these host tests are separate evidence. No
historically pinned tests were reinterpreted in the corrected checkout.

Before/after verification preserved AK51, AJ23, AI40, AH42, AG29, AF24, AE46, AD45,
AB140, Z253, X600, U264, AA141, AC265; all15 production dependencies, approved
design bytes, source provenance and historical receipts. Viewer
PID2598700/PGID2598689/startTicks522477875 and seven displays are unchanged.
**30,497 preexisting sidecars** were verified unchanged; **zero new sidecars**;
no cleanup was performed. The larger sidecar census includes the explicitly
enumerated prior/design/current roots in `audit_al.py`.

The delivery inventory covers helpers, this report, evidence and the complete
staged source/grant/raw native/supervisor files. It **excludes itself**; exact
manifest byte size/SHA256 are supplied with delivery. Raw logs are not normalized.

AK's whole positive admission remains FAIL. This baseline characterization grants
no step admission or manual-gameplay acceptance. All60 candidate map journeys
remain unrun,184 static Vesper failures unresolved, and production motion
accounting remains open. Further work requires separate owner review and authority.
