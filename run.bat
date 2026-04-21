@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"
title Taiwan Judgment Crawler

echo.
echo =====================================================
echo   Taiwan Judgment Crawler
echo =====================================================
echo.

REM =========================================================
REM Step 1. Ensure Python is installed
REM =========================================================
where python >nul 2>&1
if errorlevel 1 (
    echo Python not found.
    net session >nul 2>&1
    if errorlevel 1 (
        echo Requesting admin privileges to install Python...
        powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WorkingDirectory '%~dp0'"
        exit /b
    )

    where winget >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] winget not available. Install Python 3.11+ manually and re-run.
        start "" "https://www.python.org/downloads/"
        pause
        exit /b 1
    )

    echo Installing Python 3.12 via winget. This takes a few minutes...
    winget install --id Python.Python.3.12 -e --silent --accept-source-agreements --accept-package-agreements
    if errorlevel 1 (
        echo [ERROR] Automatic Python install failed.
        start "" "https://www.python.org/downloads/"
        pause
        exit /b 1
    )

    set "PATH=%LOCALAPPDATA%\Programs\Python\Python312;%LOCALAPPDATA%\Programs\Python\Python312\Scripts;%PATH%"

    where python >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Python installed but not on PATH.
        echo Please close this window, open a new one, and re-run run.bat.
        pause
        exit /b 1
    )
)
echo [OK] Python detected.
python --version
echo.

REM =========================================================
REM Step 2. Create virtual environment
REM =========================================================
set "VENV_PY=.venv\Scripts\python.exe"

if not exist "%VENV_PY%" (
    echo Creating virtual environment in .venv ...
    python -m venv .venv
    if errorlevel 1 (
        echo [ERROR] Failed to create virtual environment.
        pause
        exit /b 1
    )
)
echo [OK] Virtual environment ready.
echo.

REM =========================================================
REM Step 3. Install dependencies (first run only)
REM =========================================================
if not exist ".venv\.deps_installed" (
    echo Installing Python dependencies. This may take several minutes.
    echo Please do not close this window.
    echo.

    echo ^> [1/3] Upgrading pip ...
    "%VENV_PY%" -m pip install --upgrade pip
    if errorlevel 1 (
        echo [ERROR] pip upgrade failed.
        pause
        exit /b 1
    )

    echo.
    echo ^> [2/3] Installing playwright / beautifulsoup4 / lxml ...
    "%VENV_PY%" -m pip install -r requirements.txt
    if errorlevel 1 (
        echo [ERROR] pip install failed.
        pause
        exit /b 1
    )

    echo.
    echo ^> [3/3] Downloading Chromium browser (~150 MB) ...
    "%VENV_PY%" -m playwright install chromium
    if errorlevel 1 (
        echo [ERROR] Playwright browser download failed.
        pause
        exit /b 1
    )

    type nul > .venv\.deps_installed
    echo.
    echo [OK] Dependencies installed.
    echo.
)

REM =========================================================
REM Step 4. Verify keywords.txt
REM =========================================================
if not exist "keywords.txt" (
    echo [ERROR] keywords.txt not found.
    pause
    exit /b 1
)

set "KWSIZE=0"
for %%F in (keywords.txt) do set "KWSIZE=%%~zF"
if "!KWSIZE!"=="0" (
    echo [ERROR] keywords.txt is empty. Add one keyword per line and try again.
    pause
    exit /b 1
)

REM =========================================================
REM Step 5. Ask for max-pages
REM =========================================================
set "MAXPAGES="
set /p "MAXPAGES=Pages per keyword? [default 3]: "
if "!MAXPAGES!"=="" set "MAXPAGES=3"

REM =========================================================
REM Step 6. Run the crawler
REM =========================================================
echo.
echo Starting crawl. Results append to output\crawled.jsonl.
echo ----------------------------------------
"%VENV_PY%" crawl_judgments.py --keywords-file keywords.txt --max-pages !MAXPAGES!
if errorlevel 1 (
    echo.
    echo [ERROR] Crawler exited with an error.
    pause
    exit /b 1
)

echo.
echo =====================================================
echo   Done. Results saved to: output\crawled.jsonl
echo =====================================================
pause
endlocal
