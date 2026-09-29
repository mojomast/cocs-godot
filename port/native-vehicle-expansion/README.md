# Vehicle expansion verification boundary

`source-oracle.mjs` is an **arranged direct-Match fixture**, not live Room-wire
or native-Godot proof. It intentionally places two source actors at a vehicle
for each of the five kinds. Run only when the parent grants the serialized
heavy slot: `node port/native-vehicle-expansion/source-oracle.mjs`.

Required separate live acceptance (not implied by that fixture): launch an
unmodified source `Room` over real WebSockets, seat **two distinct native
clients** before host start, correlate each client's queued input sequence with
the server's accepted receipt and snapshot ACK, and observe a single chassis
with driver 0 and gunner 1. Assert driver movement, independent gunner
`vehicle-shot` (`actor:1`, `vehicle`, `barrel`, `from`, `to`), passenger personal
fire, one accepted climb for one held jump through the ordinary Room rising-edge
parser, release/focus-neutral inputs, and authoritative exit/destruction/
respawn. If test setup directly writes positions, label those portions
`controlled fixture placement`, never as naturally navigated client gameplay.

The existing `port/native-combined-arms` trace proves a **one-client Puma
driver** only. It cannot establish the two-client or full-fleet criteria.
The client must never synthesize repeated `jump` pulses for an ordinary
Room's held key: the source wire parser changes jump to a rising edge. The
Puma sports route has a separate held-jump contract.
