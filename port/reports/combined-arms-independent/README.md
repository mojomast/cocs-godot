# Independent Sunscar combined-arms acceptance

**PASS — the delivered Puma slice reproduced on the first independent live run.**
Infantry approached the source vehicle, E mounted its driver seat, W moved the
source chassis, Space supplied one rising-edge brake tap with S deceleration,
E exited, and fresh Enter + W resumed infantry movement.

Reviewed 2026-09-22 in `/tmp/opencode/combined-arms-independent`, branch
`review-combined-arms-independent`. Base: `83e4aff175eeef47c9ceab5714bad162ce9b32a6`.
Delivery cherry-picks (dependencies, **not independent review commits**):

- `1126a08` → `17c4aa6e5a1db8428c918d711d73bd1c6e43361a`
- `613dc92` → `30f1b7e3a3c7af6353b64aede1324856a2bcde51`

Ownership/discovery reviewed: primary checkout `port/handoffs/ACTIVE_LANES.md`,
delivery `port/native-combined-arms/{HANDOFF,DISCOVERY}.md`, native adapter,
controls/lease/camera/renderers/HUD, delivered tests, and source routing below.
All new work is confined to this report directory. Launcher integration patch
remains unapplied; shared/root/source/runtime files are unchanged.

## Evidence and reproducibility

Independent evidence UUID:
[`fa2d3e19-b0a8-414b-8db2-5dfa57cda4c1`](evidence/fa2d3e19-b0a8-414b-8db2-5dfa57cda4c1/).
This is a new capture, not a copy of delivery evidence.

```sh
python3 -B port/reports/combined-arms-independent/run.py
python3 -B port/reports/combined-arms-independent/analyze.py \
  port/reports/combined-arms-independent/evidence/fa2d3e19-b0a8-414b-8db2-5dfa57cda4c1
```

Exactly **one purposeful live run**, no retries or preceding independent
failures. Native route: **15.380101 s**. Whole run, including export/import,
43 native checks, captures, replay tests and cleanup: **29.756994 s**.
The runner enforces a 165-second work deadline plus cleanup within 180 seconds.
Delivery's earlier failures remain in its original evidence directories.

`run.py` creates a copied, owned runtime. Source and existing Godot scripts are
hash-equal to the checkout before execution and verified unchanged afterward.
The only added Godot file is an evidence-only subclass of the delivered input
observer: it logs recipient/start-round metadata and changes the small live
capture to 960×640. It inherits the exact delivered walking/driving route and
uses `Input.parse_input_event` physical key/mouse events through the native
adapter. No position/seat/physics/seed writes or direct authority handlers.

Pinned engine: `Godot_v4.5.2-stable_linux.x86_64`, version
`4.5.2.stable.official.6ce3de25a`, SHA-256
`5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`.
Primary `node_modules` reused read-only. Owned HOME and XDG data/config/cache/
runtime directories; private Xvfb display `:2`, `-nolisten tcp -nolisten unix`.
Owned dynamic authority endpoint: `ws://127.0.0.1:44111`.

The independent server observer imports unchanged `createGameServer` with only
history/progression persistence disabled. Default `tickDt=1/60`,
`tickMs=1000/60` and snapshot rate remain intact. The ordinary native host
request selects `sunscar-convoy`, `combined-arms`, zero bots. Start config
retains speed/gravity/damage 1, time limit 300; snapshots contain one actor.
No random seed is supplied (the authored map's layout seed is source content).

## Exact authority results

| Check | Independent result |
|---|---|
| Recipient | Room `M3S6`, peer `1`, actor `0`, one connection |
| Round | One start; `roundRevision=1` |
| Queued / received | **332 / 332**, exact matching sequence sets and payloads |
| Snapshots | **357/357 native samples** match their recipient source snapshot; 444 source snapshots retained |
| Vehicle roots | **3,570 XYZ comparisons** across all ten source vehicle IDs, tolerance <0.0001 m |
| Mounted identity | Actor `vehicleId=sunscar-0-puma`, `vehicleSeat=driver`, vehicle `driver=0` |
| Puma displacement | **25.678 m**, X −62 → −36.322; Z stays −4; Y stays 0 |
| Fresh infantry motion | **3.118 m**, X −36.322 fixed; Z −5.650 → −8.768 |
| ACK-correlated neutral samples | **53**: released 27, exit-neutral 10, final-release 16 |
| Native tests | **43 checks passed** (`controls.log`) |
| Delivered replay/negative tests | **8 passed** against this independent UUID (`replay-tests.log`) |

Round correlation uses the actual start frame's `roundRevision` latched on the
same socket/recipient, checked against the native start observer. This source
mode does not put a separate round revision on every snapshot. There is exactly
one start, no reconnect, and monotonic snapshot/input sequences. ACK is a
high-water mark; reception and ACK alone are not treated as state application.

### Mount and exit: receipt versus applied state

| Action | Input seq queued & received | Last pre-ACK snapshot | First ACK snapshot | Actual source transition |
|---|---:|---:|---:|---|
| E mount | **141** | 183 / ACK 140 | **184 / ACK 141** | Actor unmounted → Puma driver; Puma driver null → 0 |
| E exit | **285** | 380 / ACK 284 | **381 / ACK 285** | Actor vehicle/seat → null; Puma driver 0 → null |

Matching source events: `vehicle-enter`, event 34 at source time 6.133;
`vehicle-exit`, event 35 at time 12.700. Both name actor 0 and
`sunscar-0-puma`. Native `engaged=false` at both first applied transition
samples, then fresh Enter is required.

Exact source XYZ retained (not camera coordinates):

- Ordinary initial actor spawn: **(−86, 0, 2)**.
- Last pre-mount source snapshot 183: **(−61.796, 0, −5.515)**,
  within source entry reach of Puma **(−62, 0, −4)**.
- Mounted actor seat anchor: **(−61.950, 0.200, −3.600)**.
- End drive-stage Puma: **(−50.634, 0, −4)** at 14.792 m/s.
- First brake-stage Puma: **(−50.136, 0, −4)** at 15.002 m/s.
- Last brake-stage Puma: **(−36.390, 0, −4)** at 0.781 m/s.
- Released, settled Puma: **(−36.322, 0, −4)** at 0 m/s.
- Source-selected exit: **(−36.322, 0, −5.650)**.
- Fresh infantry movement endpoint: **(−36.322, 0, −8.768)**.
- Last retained native actor: **(−36.322, 0, −10.768)** after source coasting.

Space is true in received sequences **204–209**, one continuous physical tap
and **one rising edge**, then false from **210**, ACK-correlated by snapshot
277. Source `Room.input` retains `lastJump` and forwards an edge once at
simulation input assembly. This proves the ordinary brake-tap/release route;
S is also held during slowdown. It does not isolate Space's braking force or
claim sports-style held handbrake semantics.

After exit, W without Enter produces **zero displacement** and neutral inputs
through the 0.7-second exit-neutral stage. Fresh W-up, Enter-down/up, W-down at
14.053636 s leads to the 3.118 m infantry movement above. Esc release yields
neutral packets; existing source momentum can still coast. The final released
stage moves 1.426 m from its first to last sample, so neutral input must not be
described as instantaneous physical stopping.

Full stage boundaries, sequences, coordinates, identity checks, key events and
brake release are in `independent-analysis.json`. Source anchors inspected:
`game/destination-objective-maps.mjs:198–307`, `game/protocol.mjs:208–226`,
`game/core.mjs:760–787`, `game/vehicles.mjs:393–432`,
`server/room.mjs:1021–1097,1258–1329`, `server/game-server.mjs:51,450–465`.

## Actual PNG inspection

All four PNGs were opened directly with the image-capable read tool.

- [Mounted 960×640](evidence/fa2d3e19-b0a8-414b-8db2-5dfa57cda4c1/mounted-960.png):
  clear open Puma body, roll cage, wheels; readable driver/speed/hull/heat line,
  exit prompt, Space **brake tap** and fresh-capture help; no text clipping.
- [Released 1280×800](evidence/fa2d3e19-b0a8-414b-8db2-5dfa57cda4c1/released-1280.png):
  clearly framed Puma and refinery wall, readable Enter/fresh-controls prompt;
  camera is outside the vehicle. This is released input while still mounted,
  before E exit, not a screenshot of dismounted infantry.
- [Synthetic silhouettes 960×600](evidence/fa2d3e19-b0a8-414b-8db2-5dfa57cda4c1/silhouettes-960.png)
  and [1280×800](evidence/fa2d3e19-b0a8-414b-8db2-5dfa57cda4c1/silhouettes-1280.png):
  five distinct labeled forms; Puma roll cage, small Scout, tracked/cannon
  Titan, long Transport, wing/pod Hornet. The delivered gallery still uses
  960×600, documented honestly; requested 960×640 inspection is the live PNG.
  These are static synthetic preview/readability checks. They do not establish
  driving, gunner/passenger control or flight for any secondary chassis.

## Findings and unapplied fix

**One non-blocking verifier defect, reproduced offline.**
`port/native-combined-arms/validate.py:18–20` only compares a queued packet when
its sequence already exists in the received-input dictionary. Removing driving
input **171** from an in-memory copy of this wire trace still passes the
delivered verifier and all of its other acceptance assertions.

The independent strict audit closes that evidence gap for this run: every one
of 332 queued packets has an identical recorded receipt. Raw evidence is intact.
[`UNAPPLIED-validator-receipts.patch`](UNAPPLIED-validator-receipts.patch)
proposes queued-sequence uniqueness and exact queued/received set equality.
`git apply --check` passes. An in-memory check of the proposed logic accepts the
original trace and rejects the missing-171 copy; see `unapplied-patch-check.json`.
Lead should also add a targeted missing-single-driving-receipt negative test.
The patch is deliberately unapplied.

**Capture-size discrepancy:** delivered `observe.gd` and gallery use 960×600;
the handoff accurately labels those images. The independent evidence-only
capture override supplies the requested live 960×640 proof. A future delivery
harness update can make the requested small resolution configurable.

No blocking runtime defect was reproduced in the accepted slice. Live acceptance
is limited to Puma mount/drive/brake-tap/exit/fresh infantry. This was automated
native input, not a human driving session. Combat outcomes, secondary-seat
gameplay, Hornet flight, objective victory/restart, live focus/disconnect
impairment and package integration were not exercised here.

## Cleanup and integrity

All nine owned processes exited and were reaped. Server cleanup records
`serverClosed=true`, `sockets=0`; a fresh loopback probe confirms port 44111 is
closed. Private runtime `/tmp/opencode/ca-independent-wxsskcdg` was removed.
Original runtime/source hashes stayed equal. Evidence contains raw logs,
commands/PIDs, source/generated-content/engine hashes and exact output paths.

SHA-256 highlights:

| Artifact | SHA-256 |
|---|---|
| `wire.json` | `2df59f2eaa77eece3358fffb63d3b949de9d4c3d6df097afb07221483a2f34a4` |
| `native.log` | `4f8739d78de792bd964eb3c5ff08713cf6cfe0831740b1c0f669e611b3a32d20` |
| `hashes.json` | `696f3495e8cac0799217aaed00b64777589f21441842cca614e33afdb9ac1f25` |
| `summary.json` | `8829d66bff0c998538441b261640737acc51e06f3d67684b3c60e5bfbdd071a6` |
| `mounted-960.png` | `68880dfd195645a9246b55f1572b8f2db6af9707517e0f8f8a77053b37b73221` |
| `released-1280.png` | `37937404af5b7da45d1c6fafed864de189e7cc82d5613382b523ba521dc7f19d` |

`SHA256SUMS` covers the report/harness and evidence (excluding itself). The
parse-only banner log has its trailing blank line removed for git whitespace
checks; `parse-observer.raw.json` preserves its exact original stdout. Native
and wire traces are unchanged. No merge, push, deployment or published gallery
changes. Campaign remains deferred; other lanes were not modified.
