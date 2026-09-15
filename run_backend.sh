#!/bin/bash
# ====================================================
#  Court Movie Maker — Backend Launcher (macOS/Linux)
# ====================================================

set -e

echo "[*] Court Movie Maker Backend"
echo

# Check Python
if ! command -v python3 &>/dev/null; then
    echo "[ERROR] Python3 not found. Install Python 3.11+"
    exit 1
fi

# Create venv
if [ ! -d "backend/venv" ]; then
    echo "[*] Creating virtual environment..."
    python3 -m venv backend/venv
fi

# Activate
source backend/venv/bin/activate

# Install
echo "[*] Installing dependencies..."
pip install -r backend/requirements.txt -q

# Check FFmpeg
if ! command -v ffmpeg &>/dev/null; then
    echo "[WARNING] FFmpeg not found!"
    echo "  macOS:  brew install ffmpeg"
    echo "  Ubuntu: sudo apt install ffmpeg"
    exit 1
fi

echo
echo "[*] Starting backend at http://localhost:8000"
echo "[*] API docs: http://localhost:8000/docs"
echo

cd backend
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
