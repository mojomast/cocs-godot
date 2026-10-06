# Active source selection

`active-source.json` is the single reviewed answer to "what source does the
product ship?" for development, packaging, CI and verification. It names the
derivative contract that describes every reviewed `game/`/`server/` byte in the
current checkout, pinned by SHA-256.

Consumers resolve it when `COCS_SOURCE_DERIVATIVE` is unset:

- `tools/godot-dev/launch.mjs` (development launcher)
- `tools/godot-export/semantic.mjs` (source verification and export)
- `tools/godot-dev/verify.py` (aggregate verifier)
- `tools/godot-package/build.py` (package builder)

An explicit `COCS_SOURCE_DERIVATIVE=<path>` keeps the historical verification
path and is how a frozen candidate is checked at its own commit. Historical
derivative contracts (`lattice-catalog-derivative.json`,
`movement-candidate-derivative.json`, and the parent chain they describe) stay
immutable evidence; do not edit them to follow later runtimes.

The active descriptor fails closed: a missing descriptor, unsupported schema, or
a derivative byte that does not match `derivative_sha256` is an error, not a
fallback. Widening source selection requires a reviewed descriptor change and a
regenerated derivative, never an edited hash.
