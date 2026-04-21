@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

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
    net session >nul 2>&1
    if errorlevel 1 (
        echo Python not found. Requesting admin privileges to install...
        powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WorkingDirectory '%~dp0'"
        exit /b
    )

    where winget >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] winget is not available on this system.
        echo Opening the Python download page. Install Python 3.11 or newer,
        echo then double-click run.bat again.
        start "" "https://www.python.org/downloads/"
        pause
        exit /b 1
    )

    echo Installing Python 3.12 via winget. This takes a few minutes...
    winget install --id Python.Python.3.12 -e --silent --accept-source-agreements --accept-package-agreements
    if errorlevel 1 (
        echo [ERROR] Automatic Python install failed.
        echo Opening the manual download page.
        start "" "https://www.python.org/downloads/"
        pause
        exit /b 1
    )

    REM Make freshly installed Python visible without a terminal restart.
    set "PATH=%LOCALAPPDATA%\Programs\Python\Python312;%LOCALAPPDATA%\Programs\Python\Python312\Scripts;%PATH%"

    where python >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Python installed but is not on PATH.
        echo Please close this window, open a new one, and re-run run.bat.
        pause
        exit /b 1
    )
)

REM =========================================================
REM Step 2. Create virtual environment
REM =========================================================
if not exist ".venv\Scripts\activate.bat" (
    echo Creating virtual environment...
    python -m venv .venv
    if errorlevel 1 (
        echo [ERROR] Failed to create virtual environment.
        pause
        exit /b 1
    )
)

call .venv\Scripts\activate.bat

REM =========================================================
REM Step 3. Install dependencies (first run only)
REM =========================================================
if not exist ".venv\.deps_installed" (
    echo Installing Python dependencies (first run, several minutes)...
    python -m pip install --upgrade pip
    pip install -r requirements.txt
    if errorlevel 1 (
        echo [ERROR] pip install failed.
        pause
        exit /b 1
    )

    echo Downloading Playwright Chromium (about 150 MB)...
    playwright install chromium
    if errorlevel 1 (
        echo [ERROR] Playwright browser download failed.
        pause
        exit /b 1
    )

    type nul > .venv\.deps_installed
    echo Dependencies ready.
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
python crawl_judgments.py --keywords-file keywords.txt --max-pages !MAXPAGES!
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
