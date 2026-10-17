@echo off
setlocal
cd /d "%~dp0mobile"
call flutter pub get
call flutter run
