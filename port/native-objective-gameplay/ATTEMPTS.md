# Attempt history (do not conflate driver success with acceptance)

1. Source tests without a dependency resolver: 55 passed, one test module failed to resolve three. No server launched. Corrected using existing dependencies read-only. Subsequent source tests: 58/58.
2. First launcher invocation failed at module load: CommonJS-resolved ws lacked the ESM named export WebSocketServer. No native/display resources launched. Resolver now delegates to Node ESM resolution with the installed package's parent URL.
3. ce6c14a4-1e2c-4882-ac40-ad79c9f545c1: first payload normal-rate run; later independent replay passed (55 snapshots). Before road cues/provenance refinements. Retained, not designated final.
4. 74a791c7-e941-413c-a1ec-ac6179968683: first CTF run. Driver observed carry/drop but flag renderer was empty. Independent replay FAILED `rendered flag_0`. Its old summary's exit 0 is a driver result ONLY, not acceptance. Renderer rejected JSON float team IDs using typed Array membership. Fixed with finite numeric equality and a JSON roundtrip native regression.
5. 80883d89-62d0-4db8-94ad-cff9b59979cc: corrected CTF renderer with bases; independent replay passed (597 snapshots). Before final screenshot/provenance metadata. Retained intermediate success.
6. 0a6fa2e0-d17b-44aa-b48b-deccf8d0f67d: payload with road guidance at 960x640; replay passed (54 snapshots). Retained intermediate success.
7. Synthetic adapter-control test first failed its held-key assertion and warned about event reuse. The test had not flushed the buffered input event; it now flushes and duplicates the release event. All 11 assertions then passed. No runtime control behavior was weakened.
8. 0a04b930-7d1c-4c99-9ee5-3ea13cc6415f: deliberate 100ms outer timeout, exit 1, both child PIDs reaped/absent and zero sockets. Failure cleanup evidence, never gameplay acceptance.
9. 40e1b463-a857-44ab-bf1a-d8ebee783178: FINAL CTF, 1280x800, runtime/source hashes, approach and carry screenshots. Independent correlation required by launcher and replayed after compression: 582 snapshots, carry/drop, 1087 input receipts, ACK 1087. No return/capture.
10. 5ff72691-48e6-462b-9d0e-54095e807c7e: FINAL Payload, 960x640, runtime/source hashes and screenshot. Independent correlation required by launcher and replayed after compression: 54 snapshots, push/idle, 68 receipts, ACK 66. No contest/checkpoint/delivery.

Every launched scenario is normal-rate and bounded. Repeats above addressed specific defects or added the requested cues, resolution checks and provenance; they were not hidden rerolls. All owned native/display processes were reaped. The final two are the designated acceptance evidence for the limited interactions only.

Visual inspection attempt: browser service failed HTTP 500 at /tabs before loading the local image. PNGs remain unreviewed. Temporary image HTTP server stopped; reference gallery untouched.
