# Parent-only shared AV integration

Dependency: production/assets/tests commit `22b95dba`.

This separate commit changes only `godot/audio/av_service.gd` plus this note.
It attaches `Threats`, selects the source mode root, dispatches only the new
`enemy-telegraph` descriptor, and forwards settings/focus/round/seek/stale/results
lifecycle. Child `_exit_tree` owns quiet release. Diagnostics add `threats`.

Merge these additive hooks with the world lane's `12f0aa1b` confirmed snapshot
context. No weather tick, weather-owner handshake, weather phase or ambience
logic is changed. Muted events still pass through the existing identity router;
weather still ticks independently when muted. Regress the **merged** composition,
including same-round bind/reconnect and source event-before-snapshot ordering.

Do not cherry-pick the hook without its dependency: `Threats` is a preload and
the router must produce the special descriptor before generic motif processing.
