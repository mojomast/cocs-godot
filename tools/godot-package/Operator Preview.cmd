@echo off
setlocal
cd /d "%~dp0"
"%~dp0cocs.exe" --main-pack "%~dp0cocs.pck" res://player_models/preview.tscn
set "result=%errorlevel%"
if not "%result%"=="0" pause
exit /b %result%
