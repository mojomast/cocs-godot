#!/usr/bin/env bash
# Linux x86_64 editor + isolated environment; no export templates required.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
state="${1:?Usage: bash tools/godot-dev/ci_bootstrap.sh ABSOLUTE_STATE_DIRECTORY}"
[[ "$state" = /* ]] || { echo 'State directory must be absolute' >&2; exit 1; }
[[ "$(uname -s)/$(uname -m)" = Linux/x86_64 ]] || { echo 'Requires Linux x86_64' >&2; exit 1; }
mkdir -p "$state"/{toolchain,tmp,data,config,cache,runtime,browsers}
chmod 700 "$state/runtime"
touch "$state/started"

# SHA256 from the official release asset digest; independently cross-checked
# against its SHA512-SUMS.txt. See port/native-ci/evidence/toolchain.json.
archive=Godot_v4.5.2-stable_linux.x86_64.zip
binary=Godot_v4.5.2-stable_linux.x86_64
sha256=87f6e6be292929e363d15ed9052f277b2ba4e95ed994e1e099048097be2dfd03
url="https://github.com/godotengine/godot/releases/download/4.5.2-stable/$archive"
curl --fail --location --retry 2 --connect-timeout 20 --max-time 180 \
  "$url" --output "$state/toolchain/$archive"
printf '%s  %s\n' "$sha256" "$state/toolchain/$archive" | sha256sum --check --strict
python3 - "$state/toolchain/$archive" "$state/toolchain/$binary" <<'PY'
from pathlib import Path
import sys
import zipfile

target = Path(sys.argv[2])
with zipfile.ZipFile(sys.argv[1]) as archive:
    target.write_bytes(archive.read(target.name))
target.chmod(0o755)
PY
export GODOT_BIN="$state/toolchain/$binary"
export TMPDIR="$state/tmp"
export XDG_DATA_HOME="$state/data"
export XDG_CONFIG_HOME="$state/config"
export XDG_CACHE_HOME="$state/cache"
export XDG_RUNTIME_DIR="$state/runtime"
export PLAYWRIGHT_BROWSERS_PATH="$state/browsers"
export GUEST_NODE_MODULES="$root/node_modules"
export PORT=0
version="$("$GODOT_BIN" --version)"
[[ "$version" = 4.5.2.stable.official.6ce3de25a ]] || { echo "Unexpected Godot: $version" >&2; exit 1; }
printf '%s\n' "$version"
sha256sum "$GODOT_BIN"
python3 --version
node --version
npm --version

# Source this in each new shell. Bash escaping preserves spaces in local paths.
for name in GODOT_BIN TMPDIR XDG_DATA_HOME XDG_CONFIG_HOME XDG_CACHE_HOME \
  XDG_RUNTIME_DIR PLAYWRIGHT_BROWSERS_PATH GUEST_NODE_MODULES PORT; do
  printf 'export %s=%q\n' "$name" "${!name}"
done > "$state/environment.sh"
printf 'Environment: source %q\n' "$state/environment.sh"
