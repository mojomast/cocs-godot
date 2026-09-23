@echo off
setlocal
cd /d "%~dp0"
:menu
cls
echo COCS: DESTINATIONS - Windows demo
echo.
echo 1. Meridian team combat - candidate operators
echo 2. Verdant deathmatch
echo 3. Ember rockets
echo 4. Horde survival
echo 5. Arms Race
echo 6. Multiplayer lobby
echo 7. Sunscar vehicle demo
echo 8. Ion Speedway race
echo 9. Operator model viewer
echo G. New maps, shaders and particle experiments
echo D. Native Deathmatch - Prism, Aurora, Cinder, Lacuna, Vermilion, Nacre
echo C. Domination - Vermilion Fold capture zones
echo X. Cheats and debug panel
echo 0. Exit
choice /c 123456789GDCX0 /n /m "Choose a demo: "
if errorlevel 14 exit /b 0
if errorlevel 13 goto cheats
if errorlevel 12 goto domination
if errorlevel 11 goto native_dm
if errorlevel 10 goto graphics
if errorlevel 9 goto models
if errorlevel 8 goto race
if errorlevel 7 goto vehicle
if errorlevel 6 goto lobby
if errorlevel 5 goto arms
if errorlevel 4 goto horde
if errorlevel 3 goto rockets
if errorlevel 2 goto verdant
call "%~dp0Play.cmd" --play --map=meridian-exchange --mode=teamdeathmatch
goto menu
:verdant
call "%~dp0Play.cmd" --play --map=verdant-reliquary
goto menu
:rockets
call "%~dp0Play.cmd" --play --map=ember-crucible --mode=rockets
goto menu
:horde
call "%~dp0Play.cmd" --experience=horde
goto menu
:arms
call "%~dp0Play.cmd" --experience=arms-race
goto menu
:lobby
call "%~dp0Play.cmd" --experience=lobby
goto menu
:vehicle
call "%~dp0Play.cmd" --experience=combined-arms
goto menu
:race
call "%~dp0Play.cmd" --experience=sports --map=ion-speedway
goto menu
:models
call "%~dp0Operator Preview.cmd"
goto menu
:graphics
call "%~dp0Graphics Showcase.cmd"
goto menu
:native_dm
call "%~dp0Native Deathmatch.cmd"
goto menu
:domination
call "%~dp0Domination.cmd"
goto menu
:cheats
call "%~dp0Cheats.cmd"
goto menu
