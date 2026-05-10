@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0gen_bridge.ps1"
exit /b %ERRORLEVEL%
