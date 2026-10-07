@echo off
setlocal DisableDelayedExpansion
if not defined GODOT_BIN (
  echo Set GODOT_BIN to the bundled Godot editor exe.
  exit /b 2
)
if not exist "%GODOT_BIN%" (
  echo GODOT_BIN does not exist: "%GODOT_BIN%"
  exit /b 2
)
if not defined COCS_CAREER_ROOT (
  echo Set COCS_CAREER_ROOT to a scratch career directory.
  exit /b 2
)
for %%I in ("%COCS_CAREER_ROOT%") do set "COCS_CAREER_ROOT=%%~fI"
for %%I in ("%GODOT_BIN%") do set "NODE_BIN=%%~dpInode.exe"
if defined COCS_NODE_BIN set "NODE_BIN=%COCS_NODE_BIN%"
if not exist "%NODE_BIN%" (
  echo Bundled node.exe not found at "%NODE_BIN%". Set COCS_NODE_BIN to its path.
  exit /b 2
)
set "ROOT=%~dp0..\.."
set "OUTPUT=%ROOT%\gpu-checks-output.txt"
if not exist "%COCS_CAREER_ROOT%" mkdir "%COCS_CAREER_ROOT%"
if errorlevel 1 exit /b 2
> "%OUTPUT%" echo Windows GPU checks
pushd "%ROOT%"
if errorlevel 1 exit /b 2
call :announce Running horde-upgrade-fixture...
"%NODE_BIN%" tools/godot-package/tee-gpu-check.mjs "%OUTPUT%" "%NODE_BIN%" godot/tests/horde/upgrade_loopback.mjs
set "HORDE_EXIT=%errorlevel%"
call :announce Running world-weather-campaign-journey...
"%NODE_BIN%" tools/godot-package/tee-gpu-check.mjs "%OUTPUT%" "%NODE_BIN%" scripts/world-weather-journey.mjs campaign siltwake-crossing "%COCS_CAREER_ROOT%\weather-campaign"
set "WEATHER_EXIT=%errorlevel%"
if "%HORDE_EXIT%"=="0" (set "HORDE_RESULT=PASS") else (set "HORDE_RESULT=FAIL")
if "%WEATHER_EXIT%"=="0" (set "WEATHER_RESULT=PASS") else (set "WEATHER_RESULT=FAIL")
call :announce === GPU CHECK SUMMARY ===
call :announce horde-upgrade-fixture: %HORDE_RESULT% - exit %HORDE_EXIT%
call :announce world-weather-campaign-journey: %WEATHER_RESULT% - exit %WEATHER_EXIT%
call :announce Output: %OUTPUT%
popd
if not "%HORDE_EXIT%"=="0" exit /b 1
if not "%WEATHER_EXIT%"=="0" exit /b 1
exit /b 0

:announce
echo %*
>> "%OUTPUT%" echo %*
exit /b 0
