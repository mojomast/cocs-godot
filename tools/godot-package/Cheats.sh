#!/bin/sh
# Cheats and the debug panel on a local single-player route.
# A DEBUG badge appears in the match: F3 hides the panel, F4 toggles god mode,
# F5 unlocks all weapons, F6 cycles difficulty. Never available in a
# human-vs-human lobby.
cd "$(dirname "$0")" || exit 1
export COCS_DEBUG=1
exec node run.mjs --experience=identity-zones --bots=2 --round-seconds=300 --score-limit=100 "$@"
