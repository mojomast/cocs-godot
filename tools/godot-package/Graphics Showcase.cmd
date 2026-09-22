@echo off
setlocal
rem No arguments opens Showcase. With arguments, choose the route explicitly:
rem "Graphics Showcase.cmd" --experience=aurora-basin
rem Native-only routes: showcase, aurora-basin, cinder-array, particle-lab, shader-lab
rem Optional --smoke runs the selected scene headlessly.
if "%~1"=="" (
  call "%~dp0Play.cmd" --experience=showcase
) else (
  call "%~dp0Play.cmd" %*
)
exit /b %errorlevel%
