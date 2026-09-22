# Independent soccer guidance and retained goal audit

Production `fe71fef` and evidence `98647e9` integrate as `e561f99` / `4eb0e36`.
The lead reviewed public snapshot validation, defending-team goal identity,
passive markers/HUD and clearing at stale/results/restart boundaries.

```sh
PORT=0 TMPDIR=/tmp/opencode GODOT_BIN="$PINNED_GODOT" \
python3 -B port/native-soccer-play/run.py --visual
python3 -B port/native-soccer-play/audit.py \
  --output port/reports/soccer-guidance-independent/audit.json
```

**PASS**. Independent real-source stationary graphical evidence:
`port/native-soccer-play/evidence/5e2e60d8-ca26-41e5-8b36-3857b9916291/`.
Both 960×640 and 1280×800 show authoritative local Red, OWN Red / ATTACK Blue,
ball direction/distance and opponent-goal direction/distance. The lead directly
opened both guidance PNGs: panels fit and source markers are visible. These
brief stationary checks send no driving keys and establish no scored goal.

Fresh import and **164 checks pass**: existing controls27/Puma19/polish41/
progression32 plus soccer45. Synthetic cases include both JSON-float teams,
orientation/colors, invalid/missing/stale authority and nonmutation. Both real
source servers closed with zero sockets; children reaped and private copy gone.

The independent offline audit replayed all four retained runs (three agent runs
plus the new visual run), checking hashes, source clock ratios, role attribution,
score increments and cleanup. It confirms exactly two bounded scoring attempts,
**seven source goals: four normal bot goals and three bot own goals**. There are
**zero local-driver goals**. No extra scoring attempt was run by the lead.
The fresh audit destination preserves the original delivered `evidence/audit.json`.
Audit SHA256: `af42b2a0bdd46110c90bedccbb978635a8bbe09503a78cbe896f25aee96bc2bd`.

The lead also opened both original live goal PNGs from the two attempts. The
corrected **Blue GOAL · Ball reset to centre** notification is visible with a
source score increment at both resolutions. That is reviewed genuine archived
bot-goal presentation, not an independently repeated or local-driver goal.
This resolves the earlier lack of a post-fix live goal-notification image.

The new soccer45 gate participates in the **59-gate combined pass**. Native
programmatic input is distinct from human/OS-device acceptance. Local scoring,
long match usability and hardware camera/audio review remain open.
