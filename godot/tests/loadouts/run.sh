#!/usr/bin/env bash
# Offline native loadout gates. Requires GODOT_BIN; isolated runtime + XDG dirs.
#   GODOT_BIN=/path/to/Godot_v4.5.2-stable_linux.x86_64 godot/tests/loadouts/run.sh
#
# Fails closed: every group must (a) exit 0, (b) print its own
# PORT_LOADOUT_<NAME>_OK marker, and (c) log no engine ERROR:/SCRIPT ERROR line.
# Resource leaks are failures too, not allow-listed shutdown noise.
# The runner's exit status is the first failing engine exit
# code, so callers never lose the real command result.
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root/.."
bin="${GODOT_BIN:?Set GODOT_BIN to the pinned editor}"
runtime="$PWD/.port-runtime/loadouts"
mkdir -p "$runtime/data" "$runtime/config" "$runtime/cache" "$runtime/logs"
export XDG_DATA_HOME="$runtime/data" XDG_CONFIG_HOME="$runtime/config" XDG_CACHE_HOME="$runtime/cache"
failed=0
first_code=0
for entry in unit:UNIT parity:PARITY client_frames:CLIENT setup_menu:SETUP lobby_menu:LOBBY session_flow:SESSION; do
  test_file="${entry%%:*}"
  expected="PORT_LOADOUT_${entry##*:}_OK"
  log="$runtime/logs/$test_file.log"
  timeout 180 "$bin" --headless --path godot --script "res://tests/loadouts/$test_file.gd" -- "$@" > "$log" 2>&1
  code=$?
  marker=$(grep -oE "PORT_LOADOUT_[A-Z_]+OK[^\"]*" "$log" | head -1)
  errors=$(grep -m3 -E "SCRIPT ERROR|ERROR:|leaked|still in use at exit" "$log")
  reason=""
  if [ "$code" -ne 0 ]; then reason="engine exit=$code"
  elif [ -z "$marker" ]; then reason="no PORT_LOADOUT success marker"
  elif [ "${marker#"$expected"}" = "$marker" ]; then reason="unexpected marker: $marker"
  elif [ -n "$errors" ]; then reason="engine errors despite marker"
  fi
  if [ -n "$reason" ]; then
    failed=1
    if [ "$first_code" -eq 0 ]; then first_code=$code; [ "$first_code" -eq 0 ] && first_code=1; fi
    printf '%-14s exit=%-3s FAILED (%s) %s\n' "$test_file" "$code" "$reason" "${marker:-no marker}"
    [ -n "$errors" ] && printf '%s\n' "$errors" | sed 's/^/    /'
  else
    printf '%-14s exit=%-3s %s\n' "$test_file" "$code" "$marker"
  fi
done
if [ "$failed" -eq 0 ]; then echo "PORT_LOADOUT_OFFLINE_OK"; exit 0; fi
echo "PORT_LOADOUT_OFFLINE_FAILED"
exit "$first_code"
