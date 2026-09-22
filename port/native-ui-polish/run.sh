#!/usr/bin/env bash
# UI-polish lane evidence runner.
#
#   port/native-ui-polish/run.sh [output-dir]        # default evidence/after
#
# Uses the shared private-Xvfb helper (tools/godot-dev/xvfb_run.py) with an
# isolated HOME/XDG tree, so no desktop, service or port is shared. Synthetic
# state only: the probe never opens a WebSocket connection.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
godot=${GODOT_BIN:-/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64}
out=${1:-"$root/port/native-ui-polish/evidence/after"}
runtime=$(mktemp -d /tmp/opencode/ui-polish-probe-XXXXXX)
trap 'rm -rf "$runtime"' EXIT
mkdir -p "$out" "$runtime/data" "$runtime/config" "$runtime/cache"
HOME="$runtime" XDG_DATA_HOME="$runtime/data" XDG_CONFIG_HOME="$runtime/config" XDG_CACHE_HOME="$runtime/cache" \
  python3 "$root/tools/godot-dev/xvfb_run.py" "$godot" \
    --path "$root/godot" --resolution 1280x800 \
    --rendering-method gl_compatibility --audio-driver Dummy \
    --script "$root/port/native-ui-polish/probe.gd" -- --setup \
    --capture-dir="$out" --report="$out/report.json"
