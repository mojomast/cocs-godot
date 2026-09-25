# Native REQ catalogue mirror

The Godot native client mirrors the *launched* personal REQUISITION rows from
`game/cocs-economy.mjs` so its picker can offer exactly what the server will
accept. The mirror is generated — do not hand-edit the marked region in
`godot/lattice/req_catalog.gd`.

## Update workflow (after a source lane launches a row)

1. Integrate the source change (`game/cocs-economy.mjs` `REQ_ITEMS`). A launched
   row must have a machine `effect` descriptor and at least one canonical mode.
2. Regenerate the mirror:

   ```bash
   node port/tools/native_lattice_req_catalog/export.mjs
   ```

3. Review the new row(s) in the generated region of
   `godot/lattice/req_catalog.gd` (id, cost, effectCopy, modes, flags).
4. Run the deterministic checks:

   ```bash
   node --test port/tools/native_lattice_req_catalog/export.test.mjs
   node port/tools/native_lattice_req_catalog/export.mjs --check
   ```

## Fail-closed rules

* Only rows with `launch:true` or `coopLaunch:true` are mirrored.
* The offered set (non-empty `modes`, the `reqPurchaseOptions` filter) must equal
  the launched set. A row with modes but no launch flag is a source
  inconsistency and generation stops rather than advertising a `not-launched`
  purchase.
* A launched row whose effect `kind` is not in `KNOWN_EFFECT_KINDS`
  (`source.mjs` and `req_catalog.gd`) stops generation until native gate
  handling is added deliberately.
* `godot/tests/lattice/req_catalog_contract.gd` compares the committed mirror
  against the tracked source block with a bidirectional id match, so a newly
  launched source row fails the native contract until the mirror is regenerated
  and reviewed.

## Why two source views

`catalogRows()` imports the frozen module (exact effect objects);
`parseItemsBlock()` reads the same text block the GDScript contract parses. The
exporter refuses to generate if the two disagree, so the Godot regex contract
cannot silently drift from the real table.
