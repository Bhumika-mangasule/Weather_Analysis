@echo off
REM Runs the R analysis. Creates results\*.json, results\weather_cleaned.csv and plots\*.png
cd /d "%~dp0"
where Rscript >nul 2>nul
if errorlevel 1 (
  echo Rscript was not found. Add R to PATH, e.g. C:\Program Files\R\R-4.4.1\bin
  pause
  exit /b 1
)
Rscript R\main_analysis.R
pause
