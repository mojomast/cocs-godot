@echo off
setlocal
cd /d "%~dp0"
if not exist "%~dp0node.exe" goto missing
if not exist "%~dp0cocs.pck" goto missing
if "%~1"=="" (
  "%~dp0node.exe" "%~dp0run.mjs" --play --mode=teamdeathmatch
) else (
  "%~dp0node.exe" "%~dp0run.mjs" %*
)
set "result=%errorlevel%"
if not "%result%"=="0" if not defined CI pause
exit /b %result%
:missing
echo Extract the entire ZIP before playing. Keep node.exe, cocs.exe and cocs.pck together.
if not defined CI pause
exit /b 1
