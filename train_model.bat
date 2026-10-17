@echo off
setlocal
cd /d "%~dp0"
if not exist backend\.venv\Scripts\python.exe (
  echo Backend environment not found. Run setup_backend.bat first.
  pause
  exit /b 1
)
echo Generating historical dataset (optional - skip with Ctrl+C if you use your own CSV)...
backend\.venv\Scripts\python.exe ml\generate_historical_dataset.py
backend\.venv\Scripts\python.exe ml\train_model.py
pause
