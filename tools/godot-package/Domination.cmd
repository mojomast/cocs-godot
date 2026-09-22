@echo off
setlocal
if not "%~1"=="" goto forward
:menu
cls
echo COCS - Domination
echo Vermilion Fold: three capture zones, both teams scoring
echo.
echo 1. Standard        2 bots - 5 min - 100 points
echo 2. Quick           2 bots - 2 min - 30 points
echo 3. Solo practice   0 bots - 5 min - 100 points
echo 4. Crowded         6 bots - 5 min - 100 points
echo 0. Exit
choice /c 12340 /n /m "Choose a Domination setup: "
if errorlevel 5 exit /b 0
if errorlevel 4 goto crowded
if errorlevel 3 goto solo
if errorlevel 2 goto quick
goto standard
:standard
call "%~dp0Play.cmd" --experience=identity-zones --bots=2 --round-seconds=300 --score-limit=100
goto menu
:quick
call "%~dp0Play.cmd" --experience=identity-zones --bots=2 --round-seconds=120 --score-limit=30
goto menu
:solo
call "%~dp0Play.cmd" --experience=identity-zones --bots=0 --round-seconds=300 --score-limit=100
goto menu
:crowded
call "%~dp0Play.cmd" --experience=identity-zones --bots=6 --round-seconds=300 --score-limit=100
goto menu
:forward
call "%~dp0Play.cmd" %*
exit /b %errorlevel%
