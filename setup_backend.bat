@echo off
setlocal
cd /d "%~dp0backend"
if not exist .venv\Scripts\python.exe (
  echo Creating backend virtual environment using the installed Python...
  python -m venv .venv
  if errorlevel 1 (
    echo Could not create the environment. Install Python 3.11 and ensure python.exe is on PATH.
    pause
    exit /b 1
  )
)
echo Installing backend dependencies...
.venv\Scripts\python.exe -m pip install --upgrade pip
.venv\Scripts\python.exe -m pip install -r requirements.txt
if errorlevel 1 (
  echo Dependency installation failed. Check your internet connection and Python version.
  pause
  exit /b 1
)
echo Backend setup completed. Run run_backend.bat next.
pause
