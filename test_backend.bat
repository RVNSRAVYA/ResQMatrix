@echo off
setlocal
cd /d "%~dp0backend"
if not exist .venv\Scripts\python.exe (
  echo Backend environment not found. Run setup_backend.bat first.
  pause
  exit /b 1
)
.venv\Scripts\python.exe test_backend.py
if errorlevel 1 (
  echo One or more backend tests failed. See the error above.
  pause
  exit /b 1
)
echo All backend smoke tests passed.
pause
