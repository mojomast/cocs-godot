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
