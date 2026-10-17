@echo off
setlocal
cd /d "%~dp0"
set "PATH=C:\Ruby34-x64\bin;%PATH%"
ruby main.rb %*
exit /b %ERRORLEVEL%
