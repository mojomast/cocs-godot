# Zone / vehicle integration follow-up

Runtime deliveries are integrated as `8344544` / `c95f5ca` (zones) and
`88cd514` / `fc5795c` (combined arms). Independent zone acceptance is retained in
[`zone-modes-independent`](../zone-modes-independent/); combined-arms review is
tracked separately. Shared launcher and package options expose `zones` and
`combined-arms`, with invalid map/mode combinations rejected before startup.

## Retained first integration failure

[`failure-01`](failure-01/) preserves the actual failing aggregate report/log.
The newly registered combined-arms replay test selected the newest directory
whose summary said PASS, based on filesystem mtime. A fresh checkout made that
the unrelated `launcher-check`, which has no driving `native.log` or `wire.json`.
No replay tests ran. This was a fixture-selection error, not a gameplay failure.

The test now defaults to the explicitly accepted driving archive
`9216ae2e-c5ad-4c37-8e04-772855d11fba`; `COMBINED_EVIDENCE` still permits an
explicit alternate archive, whose summary must also be PASS. All eight replay
and negative cases pass after the correction. No old evidence was modified.

## Zone-helper corrections

Independent review found that an unsuccessful capture could still return exit0
with a partial label. The live helper now saves `validation.json`, then requires
all four capture/held-score/effect flags before setting exit0. Failures retain
their archives. It also records actual Git HEAD instead of hardcoded `013ad65`.
Original summaries retain their historical baseline fields; the independent
report supplies exact tested provenance. These helper fixes change no runtime.

The lead directly opened independent Meridian gameplay and Verdant results PNGs.
Zone HUD and results fit. The enormous inherited close-range pickup label behind
Verdant results remains a documented cosmetic issue.

## Independent vehicle receipt follow-up

Review `9b1cdcd`, integrated as `51f555f`, reproduced the full Puma route in one
attempt. The lead opened its mounted960×640 and released1280×800 PNGs and replayed
its evidence with the strengthened validator:332 queue/receipt matches,
357 snapshot correlations,25.678m driving and3.118m fresh infantry movement pass.

The reviewer found that one missing ordinary driving receipt escaped the old
validator. Applied its proposed exact queue/receipt sequence-set check, removed
the skip for absent receipts, and added a regression deleting one drive packet.
All **9 replay/negative tests** pass against the original accepted driving
fixture; the separate independent archive also passes. These are helper changes,
so the verified Linux runtime package remains current.

```sh
python3 -B -m unittest discover -s port/native-combined-arms -p test_validate.py
python3 -B port/native-combined-arms/validate.py port/reports/combined-arms-independent/evidence/fa2d3e19-b0a8-414b-8db2-5dfa57cda4c1
```
