@echo off
setlocal
cd /d "%~dp0backend"
if not exist .venv (
  py -3.13 -m venv .venv
  if errorlevel 1 py -3.9 -m venv .venv
)
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
python server.py
pause
