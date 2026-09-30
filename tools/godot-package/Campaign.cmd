@echo off
setlocal
call "%~dp0Play.cmd" --experience=campaign %*
exit /b %errorlevel%
