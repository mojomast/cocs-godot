# Legal ground fixture correction

Independent verifier `9549da1c` (parent `2f9fa981`) found the original 550 mm
grounded candidate fixture inside the actual 660 mm pushbox spacing. The simulator
separated actors before the first attack. That original fixture failure is retained
here and in the corrected grounded combo notes; it was not native combo proof.

## Data delta from the C2/C3/F9 checkpoint `bcb1effe`

- All **18 grounded candidates** now derive initial separation from
  `rules.pushbox.w`, currently **660 mm**, permitting exact-touch placement.
- All nine airborne candidates retain their original preconditions and traces.
- DeepSeek's charged route adds explicit `defender_setup_inputs`: 36 ticks walking
  in the same world direction as the charging attacker. Both fixture fighters use
  DeepSeek's same 42 mm/tick walk speed. Mirror both command streams using the
  initial attacker facing; release the defender at the first attack.
- Every attacker setup/input sample and every move/stat/resource remains unchanged.
  No hitbox, hurtbox or pushbox was shrunk. Rules, animation requirements, combo
  estimates and move-list output remain byte-identical to `bcb1effe`.
- `roster.json`, exported schema, generator/validation inputs and freeze hashes
  change intentionally. New roster SHA-256:
  `a736dcfe91d44a08b165e1f7191420617984a561972505b0dd53df1b22cd4748`.
  Parent must resynchronize the effects content-contract/data hash after integration;
  unchanged move/animation timings do not require new authored clip timings.

Fixtures place both actors once before playback. Charge follow is ordinary input,
not per-step teleportation. The independent journeys verifier already follows
setup walking using ordinary commands; the content now explicitly records that
second command stream so consumers can replay it without inventing setup logic.

## Source verification

**222/222 tests pass**: the complete C2/C3/F9 checks plus seven new fixture/follow
cases. Negative cases reject grounded separation below the current rules width,
unreachable first-strike horizontal contact candidates, missing/wrong/too-short
charge follow, defender attack buttons, setup continuing beyond first attack, and
unknown position fields. Airborne fixtures are exempt from the grounded-spacing
predicate, avoiding a false overlap rejection.

Horizontal first-contact candidate bounds use the actual first move's box and
standing defender hurtbox. At 660 mm the smallest grounded candidate has **220 mm
horizontal reach slack**. This is a static plausibility bound, not collision or
combo simulation. First-contact startup motion, pushback, landing and stun continuity
still require the actual core. All **27 native combo validations remain pending**.

Fresh-directory generation reproduces current artifacts exactly. Frozen source
boundary diff is empty; `git diff --check` passes. No native/heavy tool process ran.

Evidence:
`/home/mojo/.tmp-on-disk/cocs-fighting-content-evidence-20261002/ground-fixture-correction/`
including `data-delta.json`, validation/test logs and `summary.json`.
