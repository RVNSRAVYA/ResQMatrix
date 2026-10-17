@echo off
setlocal
cd /d "%~dp0"
if not exist backend\.venv\Scripts\python.exe (
  echo First run: setting up the backend environment...
  call setup_backend.bat
)
echo Starting the ResQMatrix API in a new window...
start "ResQMatrix API" cmd /k "%~dp0run_backend.bat"
echo Waiting for the API to start...
timeout /t 6 /nobreak >nul
echo Starting the Flutter web app in Chrome...
cd /d "%~dp0mobile"
call flutter pub get
call flutter run -d chrome
