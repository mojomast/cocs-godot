# Windows GPU checks

Extract `cocs-gpu-checks-windows.zip` with its directory structure intact. In
Command Prompt (replace the two paths with yours):

```cmd
cd /d C:\path\to\extracted\cocs-gpu-checks-windows
set "GODOT_BIN=%CD%\Godot.exe"
set "COCS_CAREER_ROOT=C:\path\to\empty-scratch-career"
"GPU Checks.cmd"
```

Choose a writable, disposable scratch directory outside the extracted folder.
The bundle contains Godot 4.5.2 editor (`Godot.exe`), Node 22.22.0
(`node.exe`), `node_modules/ws`, the complete tracked Godot project and the
JavaScript source closure for both checks. It needs no npm install or network.

On the first run only, when `godot/.godot` is absent, the command runs
`Godot.exe --headless --path godot --editor --import` before the checks. Allow
several minutes (typically 2–10) for import; subsequent runs skip import.
The rendered Horde upgrade fixture takes up to 30 seconds; the weather campaign
journey can take up to 115 seconds, plus startup/cleanup. The command prints
PASS/FAIL and exit code for each check, and appends both checks to
`gpu-checks-output.txt` in the extracted folder. **Paste back the entire
`gpu-checks-output.txt`**, including its summary. Also mention whether the
first-run import printed errors.

Both checks require a working Windows GPU/graphics driver and rendered Godot
window. A GPU-less machine, remote session with no usable graphics device, or
broken graphics driver will fail the checks; timeouts, Vulkan/device errors, or
missing evidence are not passes. Missing `GODOT_BIN`, `node.exe`, `ws`, or source
modules fail at startup; missing Godot resources or import failures indicate an
incomplete extraction/import. A local firewall blocking localhost WebSocket
traffic can prevent the authority/client from connecting. Do not paste only the
PASS/FAIL lines: the diagnostic output is needed to distinguish these cases.

In Linux assembly verification with llvmpipe, the Horde fixture reached its
product scene but failed with `Parse JSON failed. Error at line 0`, and the
campaign reached the input window but failed `real input moves public actor`.
The same failure classes occurred in the unbundled worktree; the Windows GPU
check is intended to distinguish those environment/input failures from a
successful rendered session.

The builder is `python3 tools/godot-package/build-gpu-checks-bundle.py REPO_ROOT
--toolchain TOOLCHAIN_DIR --output EMPTY_STATE_DIR`. The toolchain must contain
the **Windows** official `editor.zip`, `SHA512-SUMS.txt`,
`node-v22.22.0-win-x64.zip`, `NODE-SHASUMS256.txt`, and `ws-8.21.3.tgz`.
Build output is an extracted `cocs-gpu-checks-windows/` tree and a sorted,
timestamp-normalized `cocs-gpu-checks-windows.zip`. The entire tracked Godot
tree is included: Godot scene dependencies are not safely reducible by an ESM
import walk.
