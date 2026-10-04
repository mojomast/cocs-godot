# Residual-exit race correction (source only)

Follow-up to `9b3b0c04`; historical `wiring-provenance.json` remains unchanged.

The residual group may disappear after its ownership census and before SIGKILL.
`ProcessLookupError` now records that race and proceeds to three fresh membership
audits. Neither signal delivery nor ESRCH establishes release. Each audit records
whether membership was measured; a failed census records `members:null`, never an
invented empty list. Permission/other cleanup errors, identity reuse, older group
members, missing ownership, unknown audit results or surviving members prevent
`releasedCleanly`. Ownership failures never authorize a signal.

Signal handlers are restored by an outer finalization guard, independently of
cleanup and receipt writing. A failed receipt write returns failure and attempts
to emit the diagnostic report to stderr without overwriting a partial receipt.
The lock stays held through finalization and the receipt attempt; its file context
releases it on exit. `lockReleasePendingUnix` is a pre-release timestamp, not an
assertion that release or empty membership was observed.

Six new no-child regressions exercise the actual supervisor path: the exact
residual-exit/ESRCH race, permission failure despite empty audits, ESRCH followed
by a surviving member, audit failure, leader PID reuse, and receipt-write failure.
They check all three audits, restored signal handlers and lock availability.
The existing deadline and nonwaiting-lock tests remain in place. All18 wiring
tests pass; child creation and group signaling are mocked throughout these tests.

No controller, query helper, guard, epsilon or historical archive is changed.
Updated review pins bind the corrected supervisor; the additive correction
receipt records current hashes and historical preservation. No native grant,
engine execution, import, rendering, server or actual child job is authorized or
performed. Source remains WIP awaiting focused review and integration.
