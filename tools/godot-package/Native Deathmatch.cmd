@echo off
setlocal
if not "%~1"=="" goto forward
:menu
cls
echo COCS - Native Deathmatch
echo Local matches: one human and AI opponents
echo.
echo 1. Prism Foundry
echo 2. Aurora Basin
echo 3. Cinder Array
echo 0. Exit
choice /c 1230 /n /m "Choose an arena: "
if errorlevel 4 exit /b 0
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
:forward
call "%~dp0Play.cmd" %*
exit /b %errorlevel%
