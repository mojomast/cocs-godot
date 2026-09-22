#!/bin/sh
# Domination on Vermilion Fold: three capture zones, both teams scoring.
# Options: bots 0..7, round seconds 60..900, score limit 1..900.
cd "$(dirname "$0")" || exit 1
exec node run.mjs --experience=identity-zones --bots=2 --round-seconds=300 --score-limit=100 "$@"
