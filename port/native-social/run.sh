#!/usr/bin/env bash
# Native social (room browser + room-scoped chat) checks.
#
#   GODOT_BIN=/path/to/Godot_v4.5.2-stable_linux.x86_64 port/native-social/run.sh
#
# Two independent groups, each fails closed on its own marker:
#   authority : real server/game-server.mjs over WebSockets (list/rooms, chat
#               scope, spectator scope, 300 ms floor, correlated errors)
#   native    : headless Godot synthetic UI/model test (no network, no display)
#
# The Godot group runs in an isolated XDG runtime and fails if the engine logs a
# script error even when a marker is printed. Neither group starts a browser,
# rebuilds the package, or touches npm dependencies.
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
failed=0
first_code=0

authority_log=".port-runtime/native-social-authority.log"
mkdir -p .port-runtime
if node --test port/native-social/social_authority.test.mjs > "$authority_log" 2>&1; then
  printf '%-12s %s\n' authority "PASS ($(grep -c '^ok ' "$authority_log" || true) subtests)"
else
  code=$?
  printf '%-12s exit=%-3s FAILED\n' authority "$code"
  sed -n '1,80p' "$authority_log" | sed 's/^/    /'
  failed=1; [ "$first_code" -eq 0 ] && first_code=$code
fi

bin="${GODOT_BIN:-}"
if [ -z "$bin" ]; then
  printf '%-12s SKIPPED (set GODOT_BIN to run the headless native check)\n' native
else
  runtime="$PWD/.port-runtime/native-social"
  mkdir -p "$runtime/data" "$runtime/config" "$runtime/cache" "$runtime/logs"
  export XDG_DATA_HOME="$runtime/data" XDG_CONFIG_HOME="$runtime/config" XDG_CACHE_HOME="$runtime/cache"
  log="$runtime/logs/lobby_social.log"
  timeout 180 "$bin" --headless --path godot --script "res://tests/protocol/lobby_social.gd" > "$log" 2>&1
  code=$?
  marker=$(grep -oE "PORT_SOCIAL_OK[^\"]*" "$log" | head -1)
  errors=$(grep -m3 -E "SCRIPT ERROR|Parse Error|ERROR:" "$log")
  if [ "$code" -ne 0 ]; then
    printf '%-12s exit=%-3s FAILED (engine exit)\n' native "$code"; failed=1; [ "$first_code" -eq 0 ] && first_code=$code
  elif [ -z "$marker" ]; then
    printf '%-12s FAILED (no PORT_SOCIAL_OK marker)\n' native; failed=1; [ "$first_code" -eq 0 ] && first_code=1
  elif [ -n "$errors" ]; then
    printf '%-12s FAILED (engine errors despite marker)\n' native; printf '%s\n' "$errors" | sed 's/^/    /'; failed=1; [ "$first_code" -eq 0 ] && first_code=1
  else
    printf '%-12s exit=%-3s %s\n' native "$code" "$marker"
  fi
fi

if [ "$failed" -eq 0 ]; then echo "PORT_NATIVE_SOCIAL_OK"; exit 0; fi
echo "PORT_NATIVE_SOCIAL_FAILED"
exit "$first_code"
