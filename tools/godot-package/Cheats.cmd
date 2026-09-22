@echo off
setlocal
set COCS_DEBUG=1
if not "%~1"=="" goto forward
:menu
cls
echo COCS - Cheats and debug panel
echo Local single-player routes only. A DEBUG badge appears in the match.
echo F3 hides the panel, F4 toggles god mode, F5 unlocks all weapons,
echo F6 cycles difficulty. Never available in a human-vs-human lobby.
echo.
echo 1. Domination - Vermilion Fold
echo 2. Deathmatch - Prism Foundry
echo 3. Horde - Nacre Engine
echo 0. Exit
choice /c 1230 /n /m "Choose a route with cheats enabled: "
if errorlevel 4 goto domination
if errorlevel 3 goto deathmatch
if errorlevel 2 goto horde
exit /b 0
:domination
call "%~dp0Play.cmd" --experience=identity-zones --bots=2 --round-seconds=300 --score-limit=100
goto menu
:deathmatch
call "%~dp0Play.cmd" --experience=native-dm --map=prism-foundry --bots=2 --round-seconds=180
goto menu
:horde
call "%~dp0Play.cmd" --experience=horde --map=nacre-engine
goto menu
:forward
call "%~dp0Play.cmd" %*
exit /b %errorlevel%
