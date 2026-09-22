@echo off
setlocal
if not "%~1"=="" (
  call "%~dp0Play.cmd" %*
  exit /b
)
:menu
cls
echo COCS - Godot Graphics Showcase
echo.
echo 1. Prism Foundry - reactor atrium and mezzanine loop
echo 2. Aurora Basin - polar observatory and skywalk
echo 3. Cinder Array - volcanic caldera and suspended bridge
echo 4. Particle Observatory - 8K to 1M GPU particles
echo 5. Moth Shader Gallery - shield, energy and phase effects
echo 0. Exit
choice /c 123450 /n /m "Choose a showcase: "
if errorlevel 6 exit /b 0
if errorlevel 5 goto shaders
if errorlevel 4 goto particles
if errorlevel 3 goto cinder
if errorlevel 2 goto aurora
call "%~dp0Play.cmd" --experience=showcase
goto menu
:aurora
call "%~dp0Play.cmd" --experience=aurora-basin
goto menu
:cinder
call "%~dp0Play.cmd" --experience=cinder-array
goto menu
:particles
call "%~dp0Play.cmd" --experience=particle-lab
goto menu
:shaders
call "%~dp0Play.cmd" --experience=shader-lab
goto menu
