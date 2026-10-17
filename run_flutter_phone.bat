@echo off
setlocal
if "%~1"=="" (
  echo Usage: run_flutter_phone.bat 192.168.1.10
  echo Replace the address with your computer's IPv4 address.
  pause
  exit /b 1
)
cd /d "%~dp0mobile"
call flutter pub get
call flutter run --dart-define=API_BASE_URL=http://%~1:8000
