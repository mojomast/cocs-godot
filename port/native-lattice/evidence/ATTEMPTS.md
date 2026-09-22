# Retained attempt ledger

1. Initial launcher failed before serving: Node ERR_MODULE_NOT_FOUND for ws. Corrected with an owned ESM resolver reading the existing GUEST_NODE_MODULES/ws, without installing or writing dependencies.
2. Initial Godot launch failed to parse untyped map_id inference. The owned 120-second launcher deadline terminated the attempt and closed its server. Corrected with an explicit String type and check-only compile before retry.
3. First Asterion live run passed but printed repeated connected records while waiting for friendly ownership. Original complete tool output is archived as initial-asterion.log.gz; it is not the final concise evidence.
4. First background verifier lacked GODOT_BIN in that process environment and failed preflight. Subsequent background commands supplied explicit environment variables. An empty timestamp evidence directory may remain from that preflight.
5. evidence/1790039093689722306: real FAILED matrix. Godot crashed in user:// log rotation/opening before scene execution. Full error/backtrace outputs retained. Corrected by isolated, newly owned XDG directories for every attempt, cleaned after exit.
6. evidence/1790039190681658313: adapter/Asterion/co-op and graphical cases passed, but Monsoon PvP headless timed out at step 0. Harness incorrectly waited for an owned non-HQ node. Both maps author hq-N -> front-N adjacency (destination-lattice-maps.mjs:14); selecting that live frontier directly is a legal HOLD under capturableBy, even when neutral. This corrects target selection, not simulation ownership/timers. Some later cases in this run loaded the corrected smoke script; use the final report for consistent acceptance.
7. evidence/1790039363567534640: source/adapter/UI/import checks passed.
8. evidence/1790039393925752561: entire matrix passed after target fix; later strengthened live cost assertions.
9. evidence/1790039482266134571: entire matrix passed with before/after spend accounting and spawn-count assertions.
10. evidence/1790039644232228736: FINAL entire matrix passed after explicit neutral-owner labeling. No subsequent gameplay/transport/UI code edits.

Two attempts to inspect the native PNGs through browser_navigate failed with HTTP 500 from the browser service /tabs endpoint. No direct visual review is claimed. This blocker did not prevent real private-Xvfb rendering/capture.
