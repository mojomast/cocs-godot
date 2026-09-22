@echo off
setlocal
if not "%~1"=="" goto forward
:menu
cls
echo COCS - Native Deathmatch
echo Local Deathmatch: one human and AI opponents
echo.
echo 1. Prism Foundry
echo 2. Aurora Basin
echo 3. Cinder Array
echo 4. Lacuna Court
echo 5. Vermilion Fold
echo 6. Nacre Engine
echo 0. Exit
choice /c 1234560 /n /m "Choose a Deathmatch arena: "
if errorlevel 7 exit /b 0
if errorlevel 6 goto nacre
if errorlevel 5 goto vermilion
if errorlevel 4 goto lacuna
if errorlevel 3 goto cinder
if errorlevel 2 goto aurora
call "%~dp0Play.cmd" --experience=native-dm --map=prism-foundry
goto menu
:aurora
call "%~dp0Play.cmd" --experience=native-dm --map=aurora-basin
goto menu
:cinder
call "%~dp0Play.cmd" --experience=native-dm --map=cinder-array
goto menu
:lacuna
call "%~dp0Play.cmd" --experience=native-dm --map=lacuna-court
goto menu
:vermilion
call "%~dp0Play.cmd" --experience=native-dm --map=vermilion-fold
goto menu
:nacre
call "%~dp0Play.cmd" --experience=native-dm --map=nacre-engine
goto menu
:forward
call "%~dp0Play.cmd" %*
exit /b %errorlevel%
