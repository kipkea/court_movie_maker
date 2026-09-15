"""
main.py - FastAPI application สำหรับ Court Movie Maker
ระบบสร้างวิดีโออัตโนมัติสำหรับงานศาล (งานเกษียณ, วันเกิด, งานส่งลา ฯลฯ)
"""

from __future__ import annotations

import asyncio
import json
import logging
import sys
from contextlib import asynccontextmanager
from pathlib import Path
from typing import AsyncGenerator

import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

# ────────────────────────────────────────────────────────────────
# ตั้งค่า logging
# ────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
    ],
)
logger = logging.getLogger(__name__)

# ────────────────────────────────────────────────────────────────
# ไดเรกทอรีสำคัญ
# ────────────────────────────────────────────────────────────────
BASE_DIR: Path = Path(__file__).parent
UPLOADS_DIR: Path = BASE_DIR / "uploads"
OUTPUTS_DIR: Path = BASE_DIR / "outputs"
TEMP_DIR: Path = BASE_DIR / "temp"
TEMPLATES_DIR: Path = BASE_DIR / "templates"


def _create_directories() -> None:
    """สร้างไดเรกทอรีที่จำเป็นเมื่อเริ่มต้นแอป"""
    dirs = [UPLOADS_DIR, OUTPUTS_DIR, TEMP_DIR, TEMPLATES_DIR]
    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)
        logger.info("ตรวจสอบไดเรกทอรี: %s", d)


# ────────────────────────────────────────────────────────────────
# Lifespan (startup / shutdown)
# ────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """จัดการ lifecycle ของแอป"""
    # Startup
    logger.info("=" * 60)
    logger.info("Court Movie Maker Backend เริ่มต้นทำงาน")
    logger.info("=" * 60)
    _create_directories()
    logger.info("พร้อมรับคำขอ")
    yield
    # Shutdown
    logger.info("Court Movie Maker Backend หยุดทำงาน")


# ────────────────────────────────────────────────────────────────
# FastAPI Application
# ────────────────────────────────────────────────────────────────

app = FastAPI(
    title="Court Movie Maker API",
    description=(
        "API สำหรับระบบสร้างวิดีโออัตโนมัติ\n\n"
        "รองรับงาน: เกษียณราชการ, วันเกิด, งานส่งลา, ปีใหม่, สงกรานต์\n\n"
        "Features:\n"
        "- Ken Burns effect (zoom/pan)\n"
        "- Transitions (crossfade, slide, wipe)\n"
        "- Text overlay (ภาษาไทย)\n"
        "- TTS ด้วย edge-tts\n"
        "- MLT Export (Kdenlive)\n"
        "- Blender VSE render"
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# ────────────────────────────────────────────────────────────────
# CORS Middleware (อนุญาตทุก origin สำหรับ development)
# ────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ────────────────────────────────────────────────────────────────
# Static Files
# ────────────────────────────────────────────────────────────────
app.mount("/uploads", StaticFiles(directory=str(UPLOADS_DIR)), name="uploads")
app.mount("/outputs", StaticFiles(directory=str(OUTPUTS_DIR)), name="outputs")

# ────────────────────────────────────────────────────────────────
# Include Routers
# ────────────────────────────────────────────────────────────────
from routers.templates import router as templates_router
from routers.project import router as project_router, projects_router
from routers.render import router as render_router, ws_connections, jobs, JobStatus

app.include_router(templates_router)
app.include_router(project_router)
app.include_router(projects_router)
app.include_router(render_router)

# ────────────────────────────────────────────────────────────────
# WebSocket: progress streaming
# ────────────────────────────────────────────────────────────────

@app.websocket("/ws/{job_id}")
async def websocket_progress(websocket: WebSocket, job_id: str) -> None:
    """
    WebSocket endpoint สำหรับติดตาม progress ของงาน render

    Client เชื่อมต่อที่ ws://localhost:8000/ws/{job_id}
    ได้รับ JSON ของ JobStatus ทุกครั้งที่ progress เปลี่ยนแปลง
    """
    await websocket.accept()
    logger.info("WebSocket เชื่อมต่อ: job_id=%s", job_id)

    # ลงทะเบียน connection
    if job_id not in ws_connections:
        ws_connections[job_id] = []
    ws_connections[job_id].append(websocket)

    # ส่งสถานะปัจจุบันทันทีที่เชื่อมต่อ
    job = jobs.get(job_id)
    if job:
        await websocket.send_text(job.model_dump_json())
    else:
        await websocket.send_text(json.dumps({"error": f"ไม่พบงาน ID: {job_id}"}))

    try:
        # Keep connection alive จนกว่า client จะตัด
        while True:
            try:
                # รอ ping หรือข้อความจาก client (timeout 30 วินาที)
                data = await asyncio.wait_for(websocket.receive_text(), timeout=30.0)
                if data == "ping":
                    await websocket.send_text("pong")
            except asyncio.TimeoutError:
                # ส่ง heartbeat
                await websocket.send_text(json.dumps({"heartbeat": True}))
    except WebSocketDisconnect:
        logger.info("WebSocket ตัดการเชื่อมต่อ: job_id=%s", job_id)
    finally:
        # ลบออกจาก registry
        if job_id in ws_connections:
            try:
                ws_connections[job_id].remove(websocket)
            except ValueError:
                pass


# ────────────────────────────────────────────────────────────────
# Health check endpoint
# ────────────────────────────────────────────────────────────────

@app.get("/", tags=["Health"])
async def root() -> dict[str, str]:
    """Health check endpoint"""
    return {
        "status": "ok",
        "app": "Court Movie Maker API",
        "version": "1.0.0",
        "message": "ระบบพร้อมทำงาน",
    }


@app.get("/health", tags=["Health"])
async def health_check() -> dict[str, str]:
    """ตรวจสอบสถานะระบบ"""
    return {
        "status": "healthy",
        "uploads_dir": str(UPLOADS_DIR),
        "outputs_dir": str(OUTPUTS_DIR),
        "uploads_exists": str(UPLOADS_DIR.exists()),
        "outputs_exists": str(OUTPUTS_DIR.exists()),
    }


# ────────────────────────────────────────────────────────────────
# Entry point
# ────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        reload_dirs=[str(BASE_DIR)],
        log_level="info",
    )