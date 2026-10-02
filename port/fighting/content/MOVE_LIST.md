# Operator Clash — authored move reference

5 neutral, 2 down, 4 back, 6 forward, 8 up; j. airborne; xx cancel; [4] hold back. Directions mirror facing.

L/M/H normals; Special S1; Mobility S2; Special+Grab S3; Super costs 1000. Grab throw, Back+Grab back throw.

Independent Guard high; Down+Guard low. Back alone walks. No RMB tap/hold split.

Frame columns are startup / active / recovery at 60 Hz. Reach is melee box outer edge or maximum projectile travel in metres; mobility rows give displacement cap. Damage is unscaled. These are initial authored targets; human balance and native contacts remain pending.

## ChatGPT (chatgpt) — all-rounder

HP 1000; walk 52 mm/tick; weight 100%; jump 185 mm/tick. Resource adaptation: 0/3.

| Key / input | Original move | S/A/R | Damage | Hit/block stun | Reach m |
|---|---|---:|---:|---:|---:|
| stand_l / L | Survey Tap | 5/3/10 | 48 | 20/12 | 0.66 |
| stand_m / M | Cage Cross | 8/3/16 | 78 | 25/16 | 0.93 |
| stand_h / H | Plasma Lift | 12/4/23 | 112 | 31/19 | 1.10 |
| crouch_l / L | Floor Probe | 5/2/11 | 45 | 19/11 | 0.59 |
| crouch_m / M | Cable Sweep | 9/3/18 | 74 | 26/15 | 1.02 |
| crouch_h / H | Survey Scoop | 11/4/24 | 105 | 33/18 | 0.88 |
| air_l / L | Bracket Peck | 5/3/9 | 47 | 20/12 | 0.60 |
| air_m / M | Open-Cage Kick | 8/4/14 | 76 | 26/16 | 0.90 |
| air_h / H | Descending Frame | 11/5/20 | 110 | 32/19 | 1.05 |
| throw_f / GRAB | Adaptive Turn | 6/2/30 | 130 | 0/0 | 0.75 |
| throw_b / BACK_GRAB | Cable Exchange | 6/2/32 | 138 | 0/0 | 0.75 |
| special1 / SPECIAL | Survey Orb | 12/3/22 | 85 | 30/18 | 5.00 |
| special2 / MOBILITY | Cable Reel | 14/4/24 | 90 | 34/18 | 1.30 |
| special3 / SPECIAL_GRAB | Adaptive Throw | 12/2/30 | 145 | 0/0 | 0.79 |
| super / SUPER | Closed-Loop Verdict | 9/5/42 | 240 | 45/25 | 2.40 |

- **Survey Tap** (stand_l): square lead-hand snap; standing space check. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Cage Cross** (stand_m): opposed shoulder cross; standing space check. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Plasma Lift** (stand_h): two-arm rising cage; standing space check. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Floor Probe** (crouch_l): kneeling fingertip probe; low-line grounded strike. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Cable Sweep** (crouch_m): low cable-guided shin arc; low-line grounded strike. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Survey Scoop** (crouch_h): wide scoop from crouch; low-line grounded strike. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Bracket Peck** (air_l): tucked aerial hand; airborne overhead. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Open-Cage Kick** (air_m): open hip side kick; airborne overhead. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Descending Frame** (air_h): both forearms descend; airborne overhead. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Adaptive Turn** (throw_f): Paired grip casts the victim forward. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Cable Exchange** (throw_b): Paired pivot casts the victim behind the attacker. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Survey Orb** (special1): Slow survey sphere controls 5 m; jump it or punish the release. Counterplay: jump it or punish the release.
- **Cable Reel** (special2): Articulated cable pulls on contact; crouch guard then punish its long recoil. Counterplay: crouch guard then punish its long recoil.
- **Adaptive Throw** (special3): Telegraphed close command capture; jump during the cage opening. Counterplay: jump during the cage opening.
- **Closed-Loop Verdict** (super): all-rounder payoff: two-arm rising cage expands into a committed signature finish. Costs the full 1000 meter. Counterplay: Guard the anticipated finish; punish 42 recovery ticks if it misses.

### Proposed input traces

- **Basic confirm**: Survey Tap xx Cage Cross. Inputs at ticks 0, 12. Grounded close fixture. **Pending actual core verification.**
- **Signature special confirm**: Survey Tap xx Cage Cross xx Survey Orb. Inputs at ticks 0, 12, 28. Grounded close fixture. **Pending actual core verification.**
- **Air corner chain**: Bracket Peck xx Open-Cage Kick xx Survey Orb. Inputs at ticks 0, 12, 32. Airborne corner fixture. **Pending actual core verification.**

## Claude (claude) — ward footsies

HP 1060; walk 44 mm/tick; weight 110%; jump 170 mm/tick. Resource review: 0/4.

| Key / input | Original move | S/A/R | Damage | Hit/block stun | Reach m |
|---|---|---:|---:|---:|---:|
| stand_l / L | Crook Jab | 6/3/12 | 51 | 22/14 | 0.76 |
| stand_m / M | Chevron Check | 10/4/18 | 84 | 29/18 | 1.15 |
| stand_h / H | Ceramic Lance | 15/3/26 | 120 | 35/20 | 1.48 |
| crouch_l / L | Ward Knuckle | 6/2/12 | 49 | 21/12 | 0.66 |
| crouch_m / M | Shin Gate | 10/4/20 | 80 | 29/17 | 1.17 |
| crouch_h / H | Shield Rise | 13/5/25 | 114 | 35/20 | 1.00 |
| air_l / L | Glide Palm | 6/4/11 | 50 | 22/14 | 0.70 |
| air_m / M | Winged Ward | 10/5/17 | 83 | 29/18 | 1.05 |
| air_h / H | Descending Chevron | 14/4/23 | 118 | 35/20 | 1.23 |
| throw_f / GRAB | Ward Pivot | 6/2/30 | 136 | 0/0 | 0.75 |
| throw_b / BACK_GRAB | Review Reversal | 6/2/32 | 144 | 0/0 | 0.75 |
| special1 / SPECIAL | Ward Lance | 14/3/27 | 105 | 34/19 | 3.10 |
| special2 / MOBILITY | Safety Glide | 6/18/14 | 0 | 0/0 | 1.40 |
| special3 / SPECIAL_GRAB | Review Capture | 5/12/30 | 135 | 0/0 | 0.00 |
| super / SUPER | Layered Injunction | 10/5/42 | 246 | 45/25 | 2.40 |

- **Crook Jab** (stand_l): crooked elbow jab behind ward; standing space check. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Chevron Check** (stand_m): shield-first horizontal check; standing space check. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Ceramic Lance** (stand_h): long braced palm lance; standing space check. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Ward Knuckle** (crouch_l): closed kneeling knuckle; low-line grounded strike. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Shin Gate** (crouch_m): shield edge skims shin; low-line grounded strike. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Shield Rise** (crouch_h): forearms rise as nested shields; low-line grounded strike. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Glide Palm** (air_l): one palm checks below gliding torso; airborne overhead. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Winged Ward** (air_m): two broad forearms spread; airborne overhead. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Descending Chevron** (air_h): closed chevron falls shoulder-first; airborne overhead. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Ward Pivot** (throw_f): Paired grip casts the victim forward. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Review Reversal** (throw_b): Paired pivot casts the victim behind the attacker. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Ward Lance** (special1): Braced ceramic thrust reaches 3.1 m; crouch guard and whiff punish the planted recovery. Counterplay: crouch guard and whiff punish the planted recovery.
- **Safety Glide** (special2): Slow airborne retreat preserves spacing; intercept from below or meet the landing. Counterplay: intercept from below or meet the landing.
- **Review Capture** (special3): Timed ward reflects projectiles and captures close strikes; throw it or wait for the ward to close. Counterplay: throw it or wait for the ward to close.
- **Layered Injunction** (super): ward footsies payoff: long braced palm lance expands into a committed signature finish. Costs the full 1000 meter. Counterplay: Guard the anticipated finish; punish 42 recovery ticks if it misses.

### Proposed input traces

- **Basic confirm**: Crook Jab xx Shin Gate. Inputs at ticks 0, 13. Grounded close fixture. **Pending actual core verification.**
- **Signature special confirm**: Crook Jab xx Shin Gate xx Ward Lance. Inputs at ticks 0, 13, 31. Grounded close fixture. **Pending actual core verification.**
- **Air corner chain**: Glide Palm xx Winged Ward xx Descending Chevron. Inputs at ticks 8, 21, 39; 36-tick back-charge setup from tick 0. Airborne corner fixture. **Pending actual core verification.**

## Grok (grok) — pressure brawler

HP 980; walk 57 mm/tick; weight 95%; jump 205 mm/tick. Resource heat: 0/6.

| Key / input | Original move | S/A/R | Damage | Hit/block stun | Reach m |
|---|---|---:|---:|---:|---:|
| stand_l / L | Offset Hook | 4/3/12 | 50 | 21/11 | 0.61 |
| stand_m / M | Piston Elbow | 7/4/18 | 86 | 27/15 | 0.90 |
| stand_h / H | Outrider Hammer | 18/3/27 | 128 | 36/20 | 1.05 |
| crouch_l / L | Oil-Rig Tap | 5/2/12 | 47 | 20/11 | 0.56 |
| crouch_m / M | Raking Boot | 8/3/19 | 82 | 28/15 | 0.95 |
| crouch_h / H | Furnace Upper | 10/4/25 | 118 | 34/18 | 0.81 |
| air_l / L | Crooked Peck | 4/3/10 | 49 | 21/11 | 0.57 |
| air_m / M | Flying Piston | 7/4/16 | 85 | 28/16 | 0.85 |
| air_h / H | Falling Anvil | 12/4/22 | 125 | 35/19 | 0.96 |
| throw_f / GRAB | Heat Hitch | 6/2/30 | 128 | 0/0 | 0.75 |
| throw_b / BACK_GRAB | Outrider Spin | 6/2/32 | 136 | 0/0 | 0.75 |
| special1 / SPECIAL | Arc Grenade | 16/3/24 | 95 | 32/18 | 3.80 |
| special2 / MOBILITY | Charged Super Jump | 8/1/16 | 0 | 0/0 | 1.80 |
| special3 / SPECIAL_GRAB | Rocket Tackle | 17/5/29 | 150 | 36/20 | 1.80 |
| super / SUPER | Redline Pileup | 11/5/42 | 252 | 45/25 | 2.40 |

- **Offset Hook** (stand_l): short asymmetric hook; standing space check. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Piston Elbow** (stand_m): rear elbow drives hip-first; standing space check. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Outrider Hammer** (stand_h): one heavy arm folds overhead; standing space check. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Oil-Rig Tap** (crouch_l): off-center knuckle below knee; low-line grounded strike. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Raking Boot** (crouch_m): heel scrapes in crooked arc; low-line grounded strike. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Furnace Upper** (crouch_h): compressed rear arm bursts upward; low-line grounded strike. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Crooked Peck** (air_l): one tucked hand hooks down; airborne overhead. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Flying Piston** (air_m): rear elbow leads airborne body; airborne overhead. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Falling Anvil** (air_h): single arm slams with bent knees; airborne overhead. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Heat Hitch** (throw_f): Paired grip casts the victim forward. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Outrider Spin** (throw_b): Paired pivot casts the victim behind the attacker. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Arc Grenade** (special1): Arcing piston grenade pressures a landing; advance beneath it or challenge its startup. Counterplay: advance beneath it or challenge its startup.
- **Charged Super Jump** (special2): Hold down for 18 ticks before the compressed leap; anti-air its predictable rise. Counterplay: anti-air its predictable rise.
- **Rocket Tackle** (special3): Armored piston rush ends in a shoulder impact; block then punish, or throw the startup. Counterplay: block then punish, or throw the startup.
- **Redline Pileup** (super): pressure brawler payoff: one heavy arm folds overhead expands into a committed signature finish. Costs the full 1000 meter. Counterplay: Guard the anticipated finish; punish 42 recovery ticks if it misses.

### Proposed input traces

- **Basic confirm**: Offset Hook xx Piston Elbow. Inputs at ticks 0, 11. Grounded close fixture. **Pending actual core verification.**
- **Signature special confirm**: Offset Hook xx Piston Elbow xx Arc Grenade. Inputs at ticks 0, 11, 26. Airborne corner fixture. **Pending actual core verification.**
- **Air corner chain**: Crooked Peck xx Flying Piston xx Falling Anvil. Inputs at ticks 0, 11, 26. Airborne corner fixture. **Pending actual core verification.**

## Meta (meta) — armored grappler

HP 1100; walk 40 mm/tick; weight 120%; jump 165 mm/tick. Resource brace: 3/3.

| Key / input | Original move | S/A/R | Damage | Hit/block stun | Reach m |
|---|---|---:|---:|---:|---:|
| stand_l / L | Turbine Jab | 7/3/14 | 58 | 24/14 | 0.69 |
| stand_m / M | Plating Shoulder | 11/4/23 | 98 | 32/18 | 1.04 |
| stand_h / H | Twin-Piston Crush | 17/5/31 | 130 | 39/23 | 1.18 |
| crouch_l / L | Rivet Tap | 7/2/14 | 54 | 23/13 | 0.62 |
| crouch_m / M | Foundation Kick | 12/4/24 | 92 | 32/18 | 1.11 |
| crouch_h / H | Anchor Lift | 15/5/30 | 126 | 39/22 | 0.97 |
| air_l / L | Turbine Peck | 7/3/12 | 56 | 24/14 | 0.65 |
| air_m / M | Cross-Brace Knee | 11/5/20 | 96 | 32/18 | 0.98 |
| air_h / H | Two-Drum Drop | 16/6/27 | 129 | 39/23 | 1.12 |
| throw_f / GRAB | Turbine Fold | 8/2/30 | 140 | 0/0 | 0.75 |
| throw_b / BACK_GRAB | Counterweight Cast | 8/2/32 | 148 | 0/0 | 0.75 |
| special1 / SPECIAL | Shock Cone | 11/5/25 | 100 | 33/18 | 2.20 |
| special2 / MOBILITY | Brace Slam | 12/6/30 | 145 | 38/22 | 0.90 |
| special3 / SPECIAL_GRAB | Twin Grab | 15/2/34 | 180 | 0/0 | 0.98 |
| super / SUPER | Twin-Core Collapse | 12/5/42 | 258 | 45/25 | 2.40 |

- **Turbine Jab** (stand_l): broad planted fist; standing space check. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Plating Shoulder** (stand_m): hip drives layered shoulder; standing space check. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Twin-Piston Crush** (stand_h): two arms crush from raised brace; standing space check. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Rivet Tap** (crouch_l): low rivet-hand tap; low-line grounded strike. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Foundation Kick** (crouch_m): heavy low heel with planted hips; low-line grounded strike. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Anchor Lift** (crouch_h): both turbines lift from squat; low-line grounded strike. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Turbine Peck** (air_l): compact airborne fist; airborne overhead. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Cross-Brace Knee** (air_m): crossed arms brace a knee; airborne overhead. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Two-Drum Drop** (air_h): both arms drop with tucked spine; airborne overhead. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Turbine Fold** (throw_f): Paired grip casts the victim forward. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Counterweight Cast** (throw_b): Paired pivot casts the victim behind the attacker. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Shock Cone** (special1): Short twin-sector cone stops approaches; bait the 2.2 m limit and punish recovery. Counterplay: bait the 2.2 m limit and punish recovery.
- **Brace Slam** (special2): Airborne braced drop controls a compact landing; move away then punish the deep squat. Counterplay: move away then punish the deep squat.
- **Twin Grab** (special3): Longest heavy squeeze has visible turbine windup; jump or interrupt before armor. Counterplay: jump or interrupt before armor.
- **Twin-Core Collapse** (super): armored grappler payoff: two arms crush from raised brace expands into a committed signature finish. Costs the full 1000 meter. Counterplay: Guard the anticipated finish; punish 42 recovery ticks if it misses.

### Proposed input traces

- **Basic confirm**: Rivet Tap xx Foundation Kick. Inputs at ticks 0, 14. Grounded close fixture. **Pending actual core verification.**
- **Signature special confirm**: Rivet Tap xx Foundation Kick xx Shock Cone. Inputs at ticks 0, 14, 35. Grounded close fixture. **Pending actual core verification.**
- **Air corner chain**: Turbine Peck xx Cross-Brace Knee xx Two-Drum Drop. Inputs at ticks 8, 22, 42; 36-tick back-charge setup from tick 0. Airborne corner fixture. **Pending actual core verification.**

## Gemini (gemini) — two-stance duelist

HP 960; walk 56 mm/tick; weight 95%; jump 192 mm/tick. Resource band: 0/1.

| Key / input | Original move | S/A/R | Damage | Hit/block stun | Reach m |
|---|---|---:|---:|---:|---:|
| stand_l / L | Petal Jab | 5/2/10 | 46 | 20/12 | 0.67 |
| stand_m / M | Twin-Claw Cross | 8/3/15 | 75 | 25/16 | 0.99 |
| stand_h / H | Rail Palm Lift | 12/4/22 | 108 | 32/19 | 1.13 |
| crouch_l / L | Split Tap | 5/2/10 | 45 | 19/11 | 0.61 |
| crouch_m / M | Petal Scissor | 8/3/17 | 72 | 26/15 | 1.04 |
| crouch_h / H | Bifurcate Rise | 11/4/23 | 104 | 33/18 | 0.90 |
| air_l / L | Claw Peck | 5/3/9 | 46 | 20/12 | 0.62 |
| air_m / M | Mirror Heel | 8/4/13 | 74 | 26/16 | 0.94 |
| air_h / H | Petal Guillotine | 11/4/19 | 107 | 32/19 | 1.04 |
| throw_f / GRAB | Petal Exchange | 6/2/30 | 126 | 0/0 | 0.75 |
| throw_b / BACK_GRAB | Mirror Revision | 6/2/32 | 134 | 0/0 | 0.75 |
| special1 / SPECIAL | Rail Lance | 13/2/25 | 90 | 31/18 | 5.70 |
| special2 / MOBILITY | Band Transition | 5/1/12 | 0 | 0/0 | 1.00 |
| special3 / SPECIAL_GRAB | Revision Grab | 13/2/29 | 140 | 0/0 | 0.78 |
| super / SUPER | Bifurcated Horizon | 13/5/42 | 264 | 45/25 | 2.40 |
| palm_l / L | Open-Petal Check | 6/3/12 | 52 | 23/14 | 0.84 |
| palm_m / M | Mirror Lance | 10/3/19 | 87 | 30/18 | 1.28 |
| palm_h / H | Horizon Palm | 15/4/28 | 121 | 37/21 | 1.45 |

- **Petal Jab** (stand_l): split fingers lead alternate shoulders; standing space check. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Twin-Claw Cross** (stand_m): crossed claw forearms; standing space check. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Rail Palm Lift** (stand_h): open palm drives bifurcated hips; standing space check. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Split Tap** (crouch_l): two fingers reach from kneel; low-line grounded strike. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Petal Scissor** (crouch_m): opposed low shin scissor; low-line grounded strike. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Bifurcate Rise** (crouch_h): palms unfurl upward; low-line grounded strike. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Claw Peck** (air_l): one claw below tucked hips; airborne overhead. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Mirror Heel** (air_m): mirrored heel extends from twist; airborne overhead. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Petal Guillotine** (air_h): two petals close downward; airborne overhead. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Petal Exchange** (throw_f): Paired grip casts the victim forward. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Mirror Revision** (throw_b): Paired pivot casts the victim behind the attacker. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Rail Lance** (special1): Narrow finite lance checks 5.7 m; crouch under its tall line or jump on anticipation. Counterplay: crouch under its tall line or jump on anticipation.
- **Band Transition** (special2): One extra airborne impulse opens palm stance for 180 ticks; attack its visible ascent. Counterplay: attack its visible ascent.
- **Revision Grab** (special3): Petal capture sets palm stance; escape with jump before the petals close. Counterplay: escape with jump before the petals close.
- **Bifurcated Horizon** (super): two-stance duelist payoff: open palm drives bifurcated hips expands into a committed signature finish. Costs the full 1000 meter. Counterplay: Guard the anticipated finish; punish 42 recovery ticks if it misses.
- **Open-Petal Check** (palm_l): Open-palm stance replaces claw contraction with a long planted ceramic thrust. Counterplay: Palm stance extends reach but exposes slower recovery; attack its transition.
- **Mirror Lance** (palm_m): Open-palm stance replaces claw contraction with a long planted ceramic thrust. Counterplay: Palm stance extends reach but exposes slower recovery; attack its transition.
- **Horizon Palm** (palm_h): Open-palm stance replaces claw contraction with a long planted ceramic thrust. Counterplay: Palm stance extends reach but exposes slower recovery; attack its transition.

### Proposed input traces

- **Basic confirm**: Petal Jab xx Twin-Claw Cross. Inputs at ticks 0, 12. Grounded close fixture. **Pending actual core verification.**
- **Signature special confirm**: Petal Jab xx Twin-Claw Cross xx Rail Lance. Inputs at ticks 0, 12, 28. Grounded close fixture. **Pending actual core verification.**
- **Air corner chain**: Claw Peck xx Mirror Heel xx Rail Lance. Inputs at ticks 0, 12, 32. Airborne corner fixture. **Pending actual core verification.**

## DeepSeek (deepseek) — charge hover zoner

HP 1080; walk 42 mm/tick; weight 115%; jump 175 mm/tick. Resource fuel: 90/90.

| Key / input | Original move | S/A/R | Damage | Hit/block stun | Reach m |
|---|---|---:|---:|---:|---:|
| stand_l / L | Sleeve Jab | 7/3/13 | 55 | 23/13 | 0.72 |
| stand_m / M | Pressure Palm | 11/4/21 | 91 | 31/18 | 1.13 |
| stand_h / H | Vessel Elbow | 16/4/29 | 126 | 38/22 | 1.25 |
| crouch_l / L | Valve Tap | 7/2/13 | 52 | 22/12 | 0.65 |
| crouch_m / M | Ballast Sweep | 11/4/23 | 88 | 31/17 | 1.19 |
| crouch_h / H | Compression Lift | 14/5/28 | 121 | 38/21 | 1.02 |
| air_l / L | Diver Peck | 7/4/12 | 53 | 23/13 | 0.68 |
| air_m / M | Pressure Knee | 11/5/19 | 90 | 31/18 | 1.08 |
| air_h / H | Salvage Dive | 15/5/25 | 124 | 38/22 | 1.18 |
| throw_f / GRAB | Ballast Clamp | 6/2/30 | 138 | 0/0 | 0.75 |
| throw_b / BACK_GRAB | Vessel Inversion | 6/2/32 | 146 | 0/0 | 0.75 |
| special1 / SPECIAL | Compute Shot | 10/3/28 | 130 | 36/21 | 6.20 |
| special2 / MOBILITY | Hover Jets | 5/30/18 | 0 | 0/0 | 0.80 |
| special3 / SPECIAL_GRAB | Vessel Crush | 16/2/35 | 170 | 0/0 | 0.90 |
| super / SUPER | Critical Compression | 14/5/42 | 270 | 45/25 | 2.40 |

- **Sleeve Jab** (stand_l): compact sleeve-driven fist; standing space check. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Pressure Palm** (stand_m): palms vent from tucked ribs; standing space check. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Vessel Elbow** (stand_h): diver elbow lifts pressure vessel; standing space check. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Valve Tap** (crouch_l): closed valve knuckle at ankle; low-line grounded strike. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Ballast Sweep** (crouch_m): weighted shin drags low; low-line grounded strike. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Compression Lift** (crouch_h): compressed arms open upward; low-line grounded strike. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Diver Peck** (air_l): tight fist beneath tucked chest; airborne overhead. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Pressure Knee** (air_m): knee rises with vented hips; airborne overhead. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Salvage Dive** (air_h): both elbows dive from compact tuck; airborne overhead. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Ballast Clamp** (throw_f): Paired grip casts the victim forward. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Vessel Inversion** (throw_b): Paired pivot casts the victim behind the attacker. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Compute Shot** (special1): Requires 36 back-held ticks; large compression shell travels 6.2 m, so pressure before charge completes. Counterplay: large compression shell travels 6.2 m, so pressure before charge completes.
- **Hover Jets** (special2): Each hover spends 30 of 90 fuel and lasts 30 ticks; wait below and contest the fuel-limited landing. Counterplay: wait below and contest the fuel-limited landing.
- **Vessel Crush** (special3): Armored pressure clamp is slow and grounded; jump it or strike before the vessel braces. Counterplay: jump it or strike before the vessel braces.
- **Critical Compression** (super): charge hover zoner payoff: diver elbow lifts pressure vessel expands into a committed signature finish. Costs the full 1000 meter. Counterplay: Guard the anticipated finish; punish 42 recovery ticks if it misses.

### Proposed input traces

- **Basic confirm**: Valve Tap xx Pressure Palm. Inputs at ticks 0, 14. Grounded close fixture. **Pending actual core verification.**
- **Signature special confirm**: Valve Tap xx Ballast Sweep xx Compute Shot. Inputs at ticks 36, 50, 69; 36-tick back-charge setup from tick 0. Grounded close fixture. **Pending actual core verification.**
- **Air corner chain**: Diver Peck xx Pressure Knee xx Salvage Dive. Inputs at ticks 8, 22, 42; 36-tick back-charge setup from tick 0. Airborne corner fixture. **Pending actual core verification.**

## Mistral (mistral) — air-dash rushdown

HP 920; walk 62 mm/tick; weight 85%; jump 198 mm/tick. Resource air_dash: 1/1.

| Key / input | Original move | S/A/R | Damage | Hit/block stun | Reach m |
|---|---|---:|---:|---:|---:|
| stand_l / L | Scatter Snap | 4/2/9 | 45 | 19/11 | 0.58 |
| stand_m / M | Aerofoil Heel | 7/3/14 | 72 | 24/15 | 0.97 |
| stand_h / H | Rising Cyclone | 10/4/22 | 105 | 31/18 | 1.06 |
| crouch_l / L | Slip Tap | 4/2/10 | 45 | 19/10 | 0.53 |
| crouch_m / M | Wing Sweep | 7/3/16 | 70 | 25/14 | 1.03 |
| crouch_h / H | Tailfin Rise | 10/4/22 | 101 | 32/17 | 0.84 |
| air_l / L | Slipstream Peck | 4/3/8 | 45 | 19/11 | 0.55 |
| air_m / M | Swept Heel | 7/4/12 | 71 | 25/15 | 0.92 |
| air_h / H | Sirocco Dive | 10/4/18 | 104 | 31/18 | 1.02 |
| throw_f / GRAB | Slipstream Fold | 6/2/30 | 122 | 0/0 | 0.75 |
| throw_b / BACK_GRAB | Leeward Cast | 6/2/32 | 130 | 0/0 | 0.75 |
| special1 / SPECIAL | Flak Fan | 10/4/20 | 80 | 29/16 | 1.90 |
| special2 / MOBILITY | Air Dash | 3/10/13 | 0 | 0/0 | 1.45 |
| special3 / SPECIAL_GRAB | Slide Takedown | 14/5/27 | 125 | 34/18 | 1.50 |
| super / SUPER | Nine-Gust Break | 15/5/42 | 276 | 45/25 | 2.40 |

- **Scatter Snap** (stand_l): lean fingertip snap; standing space check. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Aerofoil Heel** (stand_m): long swept roundhouse; standing space check. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Rising Cyclone** (stand_h): whole-body spiral kick; standing space check. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Slip Tap** (crouch_l): low open-hand tap; low-line grounded strike. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Wing Sweep** (crouch_m): shin traces aerofoil arc; low-line grounded strike. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Tailfin Rise** (crouch_h): rear heel rises with winged arms; low-line grounded strike. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Slipstream Peck** (air_l): narrow aerial jab; airborne overhead. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Swept Heel** (air_m): extended swept heel from lean; airborne overhead. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Sirocco Dive** (air_h): diagonal kick below trailing arms; airborne overhead. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Slipstream Fold** (throw_f): Paired grip casts the victim forward. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Leeward Cast** (throw_b): Paired pivot casts the victim behind the attacker. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Flak Fan** (special1): Short aerofoil fan confirms close pressure; stay beyond 1.9 m and punish the sweep. Counterplay: stay beyond 1.9 m and punish the sweep.
- **Air Dash** (special2): One 1.45 m airborne burst per landing; guard high and intercept its landing rather than chasing. Counterplay: guard high and intercept its landing rather than chasing.
- **Slide Takedown** (special3): Low sliding heel sweeps into a hard fall; crouch guard and punish the extended finish. Counterplay: crouch guard and punish the extended finish.
- **Nine-Gust Break** (super): air-dash rushdown payoff: whole-body spiral kick expands into a committed signature finish. Costs the full 1000 meter. Counterplay: Guard the anticipated finish; punish 42 recovery ticks if it misses.

### Proposed input traces

- **Basic confirm**: Scatter Snap xx Wing Sweep. Inputs at ticks 0, 11. Grounded close fixture. **Pending actual core verification.**
- **Signature special confirm**: Scatter Snap xx Wing Sweep xx Flak Fan. Inputs at ticks 0, 11, 26. Grounded close fixture. **Pending actual core verification.**
- **Air corner chain**: Slipstream Peck xx Swept Heel xx Sirocco Dive. Inputs at ticks 0, 11, 26. Airborne corner fixture. **Pending actual core verification.**

## Kimi (kimi) — blink mobile zoner

HP 900; walk 58 mm/tick; weight 85%; jump 190 mm/tick. Resource context: 0/3.

| Key / input | Original move | S/A/R | Damage | Hit/block stun | Reach m |
|---|---|---:|---:|---:|---:|
| stand_l / L | Gimbal Jab | 5/3/11 | 46 | 21/12 | 0.71 |
| stand_m / M | Orbital Backhand | 9/3/18 | 77 | 27/17 | 1.19 |
| stand_h / H | Apogee Kick | 14/4/25 | 111 | 34/20 | 1.40 |
| crouch_l / L | Orbit Tap | 5/2/12 | 45 | 20/11 | 0.64 |
| crouch_m / M | Perigee Sweep | 9/3/20 | 74 | 28/16 | 1.24 |
| crouch_h / H | Axis Rise | 12/4/25 | 107 | 35/19 | 0.98 |
| air_l / L | Satellite Peck | 5/4/10 | 46 | 21/12 | 0.67 |
| air_m / M | Orbit Heel | 9/4/16 | 76 | 28/17 | 1.11 |
| air_h / H | Falling Meridian | 13/5/22 | 110 | 34/20 | 1.30 |
| throw_f / GRAB | Context Orbit | 6/2/30 | 120 | 0/0 | 0.75 |
| throw_b / BACK_GRAB | Gimbal Exchange | 6/2/32 | 128 | 0/0 | 0.75 |
| special1 / SPECIAL | Context Pulse | 15/2/27 | 95 | 32/18 | 6.60 |
| special2 / MOBILITY | Blink Step | 15/1/22 | 0 | 0/0 | 1.80 |
| special3 / SPECIAL_GRAB | Context Grab | 14/2/32 | 135 | 0/0 | 0.80 |
| super / SUPER | Closed Context Eclipse | 16/5/42 | 282 | 45/25 | 2.40 |

- **Gimbal Jab** (stand_l): rotating wrist jab; standing space check. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Orbital Backhand** (stand_m): full orbital backhand; standing space check. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Apogee Kick** (stand_h): high gimbal heel from torso rotation; standing space check. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Orbit Tap** (crouch_l): wrist circles below knee; low-line grounded strike. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Perigee Sweep** (crouch_m): shin draws low orbit; low-line grounded strike. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Axis Rise** (crouch_h): both hands spiral upward; low-line grounded strike. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Satellite Peck** (air_l): orbiting palm below hips; airborne overhead. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Orbit Heel** (air_m): heel traces a horizontal ring; airborne overhead. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Falling Meridian** (air_h): gimbal arm arcs down past bent knee; airborne overhead. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Context Orbit** (throw_f): Paired grip casts the victim forward. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Gimbal Exchange** (throw_b): Paired pivot casts the victim behind the attacker. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Context Pulse** (special1): Finite narrow rail pulse covers 6.6 m; duck its line or force recovery with a jump. Counterplay: duck its line or force recovery with a jump.
- **Blink Step** (special2): Visible 15-tick gimbal windup precedes a 1.8 m forward blink; attack the arrival, with no hidden invulnerability. Counterplay: attack the arrival, with no hidden invulnerability.
- **Context Grab** (special3): Orbital capture trades damage for repositioning; jump the open-ring windup. Counterplay: jump the open-ring windup.
- **Closed Context Eclipse** (super): blink mobile zoner payoff: high gimbal heel from torso rotation expands into a committed signature finish. Costs the full 1000 meter. Counterplay: Guard the anticipated finish; punish 42 recovery ticks if it misses.

### Proposed input traces

- **Basic confirm**: Gimbal Jab xx Orbital Backhand. Inputs at ticks 0, 12. Grounded close fixture. **Pending actual core verification.**
- **Signature special confirm**: Gimbal Jab xx Orbital Backhand xx Context Pulse. Inputs at ticks 0, 12, 29. Grounded close fixture. **Pending actual core verification.**
- **Air corner chain**: Satellite Peck xx Orbit Heel xx Context Pulse. Inputs at ticks 0, 12, 33. Airborne corner fixture. **Pending actual core verification.**

## Qwen (qwen) — anchor setplay grappler

HP 1020; walk 48 mm/tick; weight 105%; jump 180 mm/tick. Resource tools: 3/3.

| Key / input | Original move | S/A/R | Damage | Hit/block stun | Reach m |
|---|---|---:|---:|---:|---:|
| stand_l / L | Lamellar Tap | 6/3/12 | 52 | 22/13 | 0.78 |
| stand_m / M | Cable-Guided Palm | 9/4/19 | 85 | 29/17 | 1.18 |
| stand_h / H | Sentinel Lift | 14/4/27 | 119 | 36/21 | 1.31 |
| crouch_l / L | Lockpin Tap | 6/2/13 | 50 | 21/12 | 0.70 |
| crouch_m / M | Segment Sweep | 10/4/21 | 82 | 29/16 | 1.25 |
| crouch_h / H | Layered Rise | 13/5/26 | 115 | 37/20 | 1.06 |
| air_l / L | Glyph Peck | 6/3/11 | 51 | 22/13 | 0.73 |
| air_m / M | Locking Heel | 9/5/17 | 84 | 29/17 | 1.12 |
| air_h / H | Falling Lamella | 13/5/23 | 117 | 36/21 | 1.23 |
| throw_f / GRAB | Tool Lock | 6/2/30 | 132 | 0/0 | 0.75 |
| throw_b / BACK_GRAB | Sentinel Transfer | 6/2/32 | 140 | 0/0 | 0.75 |
| special1 / SPECIAL | Tool Pulse | 14/3/24 | 90 | 32/18 | 4.80 |
| special2 / MOBILITY | Tether Anchor | 20/1/25 | 0 | 0/0 | 2.00 |
| special3 / SPECIAL_GRAB | Tool Throw | 14/2/33 | 155 | 0/0 | 1.05 |
| super / SUPER | Final Toolchain | 17/5/42 | 288 | 45/25 | 2.40 |

- **Lamellar Tap** (stand_l): sequential plate knuckle; standing space check. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Cable-Guided Palm** (stand_m): rope guides open palm; standing space check. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Sentinel Lift** (stand_h): layered forearms lift sentinel torso; standing space check. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Lockpin Tap** (crouch_l): small lockpin fist at shin; low-line grounded strike. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Segment Sweep** (crouch_m): low segmented cable arm; low-line grounded strike. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Layered Rise** (crouch_h): stacked forearms unfold upward; low-line grounded strike. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Glyph Peck** (air_l): measured airborne palm; airborne overhead. Counterplay: Guard its short reach, then challenge a delayed follow-up.
- **Locking Heel** (air_m): grounded torso twists into heel; airborne overhead. Counterplay: Block at its preferred range; whiff punish the extended limb.
- **Falling Lamella** (air_h): layers close into descending elbow; airborne overhead. Counterplay: Respect the rising contact, then punish the committed recovery.
- **Tool Lock** (throw_f): Paired grip casts the victim forward. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Sentinel Transfer** (throw_b): Paired pivot casts the victim behind the attacker. Counterplay: Press Grab within ten ticks to tech, or jump before capture.
- **Tool Pulse** (special1): Segmented tool pulse controls midrange; jump it and punish the sentinel release. Counterplay: jump it and punish the sentinel release.
- **Tether Anchor** (special2): One visible anchor lasts 180 ticks and pulls once within 0.65 m; jump over its trigger or pressure the setup. Counterplay: jump over its trigger or pressure the setup.
- **Tool Throw** (special3): Long cable capture has a 14-tick lock glyph; jump or interrupt while the cable unfolds. Counterplay: jump or interrupt while the cable unfolds.
- **Final Toolchain** (super): anchor setplay grappler payoff: layered forearms lift sentinel torso expands into a committed signature finish. Costs the full 1000 meter. Counterplay: Guard the anticipated finish; punish 42 recovery ticks if it misses.

### Proposed input traces

- **Basic confirm**: Lockpin Tap xx Segment Sweep. Inputs at ticks 0, 13. Grounded close fixture. **Pending actual core verification.**
- **Signature special confirm**: Lockpin Tap xx Segment Sweep xx Tool Pulse. Inputs at ticks 0, 13, 31. Grounded close fixture. **Pending actual core verification.**
- **Air corner chain**: Glyph Peck xx Locking Heel xx Tool Pulse. Inputs at ticks 0, 13, 34. Airborne corner fixture. **Pending actual core verification.**

## Native-03 candidate follow-up

Basic confirms now teach two consecutive normals; signature and air practice retain three attacks. Original native failures and all passing candidates are recorded in NATIVE_03_DIAGNOSIS.json. Revised candidates need actual-core rerun.
Meta/Qwen: hold down continuously through crouch L and crouch M; a down-neutral-down sequence selects Mobility instead.
Grok signature grenade practice is now a grounded corner-pressure route; its original midscreen third hit arrived after hitstun expired.
Claude, Meta and DeepSeek air practice: start grounded at the corner, tap Up for both actors at tick0, then begin the listed aerial normals at tick8. Their new setup uses ordinary jumps, with no initial velocity injection. Grok/Mistral retain the native-passing airborne fixtures unchanged.
ChatGPT, Gemini, Kimi and Qwen retain their harder air-normal into projectile routes. The third input is four ticks later to cover ordinary landing recovery; Astra must repair the observed landing-timer latch before these candidates can be certified. No projectile finisher is replaced to hide the core issue.

