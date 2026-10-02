# First source-feature pass — combined acceptance

Runtime anchor: **`e731fd536d31d16a7014402afe6670fca644f9c1`**.
Evidence root: `/home/mojo/.tmp-on-disk/cocs-first-port-pass-evidence-20261002/`.

## Completed

- **359/359 canonical gates passed on the first run.** `canonical-initial/`
  preserves all gate logs and `verification.json`; `canonical-journeys/` preserves
  the run's isolated connected/rendered/source receipts. Original source lock and
  explicit derivative remain unchanged.
- The canonical report's `port_worktree_dirty` is true: the checkout retains
  generated import/UID metadata and prior evidence. Tracked runtime/build inputs
  were committed; the package builder independently checks their bytes against
  the recorded commit and exports a fresh staged project.
- Linux and Windows archives were built successfully from the same runtime.
  **1,672 shared build inputs match**, and generated resource inventories/digests
  match. Windows additionally records its platform-specific play instructions.
- Both archives were checksum-verified and freshly extracted into paths with
  spaces. Platform execution acceptance is in progress, not yet claimed.

## Pending at this checkpoint

- Linux extracted package: expected **23 base + 52 expansion = 75 cases**.
- Windows: [workflow 36972400600](https://github.com/mojomast/cocs-godot/actions/runs/36972400600),
  expected the same 75 cases with transport observation.
- Package-only graphical caption/HUD evidence, using the external harness in
  the evidence root and production resources/authorities from the extraction.
- Final public acceptance archive, release notes and publication.

Draft release tag: `quiet-relay-source-expansion-2026-10-02`.

## Built archive SHA-256

```text
f08f01a21d694e20e8a25dbce37bc5799e6881e1f29302b34cccdad692b9c37e  cocs-native-linux.tar.gz
81cd193c2269d9c708fcabc81e13b551dac50b1b2fd34d42d6cf3465288ce3be  cocs-native-windows.zip
```

## Public lane screenshots

- [Full Arsenal, caption and operator status](https://github.com/mojomast/cocs-godot/releases/download/quiet-relay-gallery-2026-09-30/source-pass-arsenal-caption-wide.png)
- [VIP compact operator HUD](https://github.com/mojomast/cocs-godot/releases/download/quiet-relay-gallery-2026-09-30/source-pass-vip-compact.png)
- [Matched weather comparison](https://github.com/mojomast/cocs-godot/releases/download/quiet-relay-gallery-2026-09-30/source-pass-weather-comparison.jpg)
- [Labeled rope visual fixture](https://github.com/mojomast/cocs-godot/releases/download/quiet-relay-gallery-2026-09-30/source-pass-rope-fixture.png)

These are lane development captures. Image provenance identifies the connected
controlled pickup fixture, ordinary native mobility input and offline visual
fixtures separately; none is a natural match-completion or real-GPU claim.

## Remaining product acceptance

Successful ordinary-input VIP extraction, full Blackwater chain/Warden,
independent-route spectator handoffs, connected protected mission captions and
some exhaustive compact text/scroll checks remain open. Existing combined-arms
HUD text still overlaps at UI150. Human timing/feel and hardware performance remain
playtest observations. Lane details and retained failures are in their individual
acceptance documents. See [the authorized second pass](PASS_TWO.md).
