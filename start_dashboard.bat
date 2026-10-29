@echo off
REM Starts a small local web server and opens the dashboard.
cd /d "%~dp0"
start "" http://localhost:8000/frontend/index.html
python -m http.server 8000
