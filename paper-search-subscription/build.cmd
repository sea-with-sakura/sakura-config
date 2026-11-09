@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0generate.ps1"
if errorlevel 1 (
    echo.
    echo Build failed. Read the error above; fix domains.txt and try again.
    pause
    exit /b 1
)
echo.
echo Done. Local preview generated. GitHub Actions also builds automatically on push.
pause
