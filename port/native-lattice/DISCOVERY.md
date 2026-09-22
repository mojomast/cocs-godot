# Direct discovery and synthesis

Owner approved direct execution instead of unavailable subagents. Base 9dc82c8; branch feat/native-lattice-command. All implementation confined to the four handoff-owned directories.

## Wire lifecycle
- game/protocol.mjs:94-145: optional bounded roundRev/actionSeq; order requires cardId/verb/target; economy requires cardId/action.
- server/room.mjs:175-281: round/seat/sequence dedupe; payload mismatch is id-reuse; rejection carries cardId/reason/roundRevision and parsed identities. Never retry a spend automatically.
- server/room.mjs:293-374,475-580: running cards mean accepted, not completed. Orders settle against sim orderLog/task; economy settles against spendLog. PvP spawn/reinforce support roles; fortify is no-sink in PvP.
- game/net.mjs:339-398: source caller mints per-round identities and tracks card IDs. Native must not use movement ACKs for command success.
- godot/net/client.gd:129-206: existing decoder bounds frames, validates map and snapshot order but drops cocs-reject. Subclass decode_text narrowly; delegate all ordinary frames.

## Recipient and map discovery
- game/cocs-intel.mjs:14-102,125-162: team maps omit enemy keys. Cards are recipient-team filtered. Missing wallets remain unknown, not zero. Do not render enemy actor positions.
- game/cocs.mjs:1297-1315,1949-2000: PvP roleBoard has allow/threads/agents; commander differs from co-op command; fluxSpent accounts for spending separately from passive income.
- game/cocs-coop.mjs:373-403,420-432,2163-2241: HOLD requires human slice membership; big orders need executor; economy needs real between-wave window and slice/lease checks. First slice will offer co-op HOLD only when human membership is present, and no co-op economy actions.
- game/cocs-orders.mjs:30-51,94-103: HOLD is GO; source anti-double-fire cooldown is 0.5 seconds. Order targets are live node IDs.
- game/cocs-roles.mjs:30-33: Fighter costs 12 FLUX.
- game/destination-lattice.test.mjs:80-262 and port/contracts/map-selection.json: both Asterion Relay and Monsoon Foundry retain cocs and cocs-coop. No substitute maps/modes.

## Native UX and scope
Reuse PortNetwork by narrow subclass and PortCatalog by composition. Native Control scene: map/mode selectors, endpoint/join fields, connect/disconnect, recipient resources, selectable node list, HOLD and explicit-confirm Fighter spend, bounded action history and readable refusals. A responsive scroll layout at 960x640 and 1280x800 avoids fixed positioning. No movement/proximity actions. No privileged actor or local authority changes.

Action lifecycle: queued locally -> pending on server running card -> confirmed only on authoritative done; blocked/expired/refusal remains rejected. For HOLD show accepted/running explicitly, not completed. Match cardId plus actor/peer identity; unique IDs incorporate round and peer. Disable stale/disconnected/dead/unknown identity, unknown role permissions and duplicate activation. Clear projection, selection and pending on reset. No automatic spend retries.

Owned files planned: godot/lattice/{transport.gd,board.gd,board.tscn}; godot/tests/lattice/*; port/tools/native_lattice_demo/*; port/native-lattice/{README.md,HANDOFF.md,evidence/*}. Tests and live evidence must distinguish synthetic/native activation from real OS clicks. Full gameplay, co-op economy, movement, graphical acceptance are not assumed.
