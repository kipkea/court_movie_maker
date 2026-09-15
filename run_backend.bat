@echo off
REM ====================================================
REM  Court Movie Maker — Backend Launcher (Windows)
REM ====================================================

echo [*] Court Movie Maker Backend
echo.

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found. Install Python 3.11+ from https://python.org
    pause
    exit /b 1
)

REM Create venv if not exists
if not exist "backend\venv" (
    echo [*] Creating virtual environment...
    python -m venv backend\venv
)

REM Activate venv
call backend\venv\Scripts\activate.bat

REM Install dependencies
echo [*] Installing dependencies...
pip install -r backend\requirements.txt --quiet

REM Check Blender
echo [*] Checking Blender 3D...
if exist "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" (
    echo [*] Found Blender 5.2 at C:\Program Files\Blender Foundation\Blender 5.2\blender.exe [3D Engine Ready]
) else if exist "C:\Program Files\Blender Foundation\Blender 5.0\blender.exe" (
    echo [*] Found Blender 5.0 at C:\Program Files\Blender Foundation\Blender 5.0\blender.exe [3D Engine Ready]
) else (
    where blender.exe >nul 2>&1
    if not errorlevel 1 (
        echo [*] Found Blender in PATH [3D Engine Ready]
    ) else (
        echo [INFO] Blender not found in default path. 3D effects will use fallback mode.
    )
)

REM Check FFmpeg
ffmpeg -version >nul 2>&1
if errorlevel 1 (
    echo [INFO] FFmpeg not found in PATH. 2D slideshow requires FFmpeg, or use Blender 3D engine.
) else (
    echo [*] Found FFmpeg in PATH [2D Engine Ready]
)

REM Start backend
echo.
echo ====================================================
echo  Court Movie Maker Backend is running!
echo  URL:      http://localhost:8000
echo  Swagger:  http://localhost:8000/docs
echo  Platform: Windows Localhost
echo ====================================================
echo.
cd backend
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
