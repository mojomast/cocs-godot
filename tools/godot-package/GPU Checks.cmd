@echo off
setlocal DisableDelayedExpansion
set "ROOT=%~dp0"
if not defined GODOT_BIN (
  set "GODOT_BIN=%ROOT%Godot.exe"
)
if not exist "%GODOT_BIN%" (
  echo Missing Godot editor: "%GODOT_BIN%"
  exit /b 2
)
if not exist "%ROOT%node.exe" (
  echo Missing bundled node.exe
  exit /b 2
)
if not exist "%ROOT%node_modules\ws\package.json" (
  echo Missing bundled ws module
  exit /b 2
)
if not exist "%ROOT%game\core.mjs" (
  echo Missing game source modules. Extract the complete zip again.
  exit /b 2
)
if not exist "%ROOT%scripts\world-weather-journey.mjs" (
  echo Missing world-weather journey harness. Extract the complete zip again.
  exit /b 2
)
if not exist "%ROOT%godot\tests\horde\upgrade_loopback.mjs" (
  echo Missing Horde harness. Extract the complete zip again.
  exit /b 2
)
if not exist "%ROOT%godot\content\generated\manifest.json" (
  echo Missing generated content manifest. Extract the complete zip again.
  exit /b 2
)
if not defined COCS_CAREER_ROOT (
  echo Set COCS_CAREER_ROOT to an absolute scratch directory.
  exit /b 2
)
pushd "%ROOT%"
if errorlevel 1 exit /b 2
if not exist "godot\.godot\" (
  echo First run: importing Godot resources. This may take several minutes.
  "%GODOT_BIN%" --headless --path godot --editor --import
  if errorlevel 1 (
    echo Godot import failed.
    popd
    exit /b 1
  )
)
call tools\godot-package\run-gpu-checks.cmd
set "RESULT=%errorlevel%"
popd
exit /b %RESULT%
