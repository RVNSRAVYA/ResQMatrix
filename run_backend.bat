@echo off
setlocal
cd /d "%~dp0backend"
if not exist .venv\Scripts\python.exe (
  echo Backend environment not found. Run setup_backend.bat first.
  pause
  exit /b 1
)
.venv\Scripts\python.exe -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
