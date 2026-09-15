"""
routers/render.py - API สำหรับการ render วิดีโอ
POST /render/{project_id} → เริ่มงาน render (background)
GET  /render/{job_id}/status → สถานะงาน
GET  /render/{job_id}/download/{file_type} → ดาวน์โหลดไฟล์ผลลัพธ์
"""

from __future__ import annotations

import asyncio
import json
import logging
import uuid
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any

from fastapi import APIRouter, BackgroundTasks, HTTPException, WebSocket
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

from core.template_manager import template_manager

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/render", tags=["Render"])

# ────────────────────────────────────────────────────────────────
# ไดเรกทอรี
# ────────────────────────────────────────────────────────────────
UPLOADS_DIR: Path = Path(__file__).parent.parent / "uploads"
OUTPUTS_DIR: Path = Path(__file__).parent.parent / "outputs"
TEMP_DIR: Path = Path(__file__).parent.parent / "temp"


# ────────────────────────────────────────────────────────────────
# Job status models
# ────────────────────────────────────────────────────────────────

class JobState(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    SUCCESS = "success"
    FAILED = "failed"


class JobStatus(BaseModel):
    job_id: str
    project_id: str
    state: JobState = JobState.PENDING
    status: str = "pending"
    progress: int = Field(0, ge=0, le=100)  # 0-100 %
    message: str = ""
    output_files: dict[str, str] = Field(default_factory=dict)
    error: str | None = None
    error_message: str | None = None
    created_at: str = Field(default_factory=lambda: datetime.now().isoformat())
    updated_at: str = Field(default_factory=lambda: datetime.now().isoformat())


class RenderRequest(BaseModel):
    use_tts: bool = Field(False, description="แปลง script เป็นเสียง TTS")
    export_mlt: bool = Field(False, description="สร้างไฟล์ MLT สำหรับ Kdenlive")
    use_blender: bool = Field(False, description="ใช้ Blender เรนเดอร์แทน FFmpeg")
    image_order: list[str] = Field(
        default_factory=list,
        description="ลำดับรูปภาพ (ชื่อไฟล์) — ถ้าว่างจะใช้ตามลำดับเดิม"
    )
    blender_path: str = Field("blender", description="พาธ Blender executable")


# ────────────────────────────────────────────────────────────────
# In-memory job registry
# (ในระบบ production ควรใช้ Redis หรือฐานข้อมูล)
# ────────────────────────────────────────────────────────────────
jobs: dict[str, JobStatus] = {}

# WebSocket connections สำหรับ progress streaming
ws_connections: dict[str, list[WebSocket]] = {}


# ────────────────────────────────────────────────────────────────
# Helper functions
# ────────────────────────────────────────────────────────────────

def _update_job(
    job_id: str,
    state: JobState | None = None,
    progress: int | None = None,
    message: str | None = None,
    output_files: dict[str, str] | None = None,
    error: str | None = None,
) -> None:
    """อัพเดทสถานะงาน render"""
    job = jobs.get(job_id)
    if job is None:
        return
    if state is not None:
        job.state = state
        job.status = state.value
    if progress is not None:
        job.progress = progress
    if message is not None:
        job.message = message
    if output_files is not None:
        job.output_files.update(output_files)
    if error is not None:
        job.error = error
        job.error_message = error
    job.updated_at = datetime.now().isoformat()
    try:
        job_file = TEMP_DIR / f"job_{job_id}.json"
        job_file.write_text(job.model_dump_json(), encoding="utf-8")
    except Exception:
        pass


async def _broadcast_progress(job_id: str) -> None:
    """ส่งสถานะงานไปยัง WebSocket clients ทั้งหมด"""
    connections = ws_connections.get(job_id, [])
    if not connections:
        return

    job = jobs.get(job_id)
    if job is None:
        return

    payload = job.model_dump_json()
    dead: list[WebSocket] = []

    for ws in connections:
        try:
            await ws.send_text(payload)
        except Exception:
            dead.append(ws)

    for ws in dead:
        connections.remove(ws)


def _get_project_meta(project_id: str) -> dict[str, Any]:
    """โหลด metadata ของโปรเจกต์"""
    meta_path = UPLOADS_DIR / project_id / "project.json"
    if not meta_path.exists():
        raise HTTPException(status_code=404, detail=f"ไม่พบโปรเจกต์ ID: {project_id}")
    with meta_path.open(encoding="utf-8") as f:
        return json.load(f)


def _get_ordered_images(project_id: str, image_order: list[str]) -> list[Path]:
    """
    คืนรายการพาธรูปภาพเรียงตาม image_order
    ถ้า image_order ว่างจะใช้ลำดับตามตัวอักษร
    """
    images_dir = UPLOADS_DIR / project_id / "images"
    if not images_dir.exists():
        return []

    exts = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tiff"}
    all_images = {p.name: p for p in images_dir.iterdir() if p.suffix.lower() in exts}

    if image_order:
        ordered = []
        for name in image_order:
            if name in all_images:
                ordered.append(all_images[name])
            else:
                logger.warning("ไม่พบภาพ '%s' ในโปรเจกต์ ข้ามไป", name)
        # เพิ่มภาพที่ยังไม่ได้อยู่ใน order ต่อท้าย
        for name, path in sorted(all_images.items()):
            if name not in image_order:
                ordered.append(path)
        return ordered
    else:
        return sorted(all_images.values(), key=lambda p: p.name)


# ────────────────────────────────────────────────────────────────
# Background render task
# ────────────────────────────────────────────────────────────────

async def _run_render_job(
    job_id: str,
    project_id: str,
    request: RenderRequest,
) -> None:
    """
    งาน render หลักที่รันใน background
    จัดการทุกขั้นตอน: TTS → FFmpeg/Blender → MLT export
    """
    output_dir = OUTPUTS_DIR / job_id
    output_dir.mkdir(parents=True, exist_ok=True)

    try:
        # ── ขั้นตอน 1: โหลดข้อมูลโปรเจกต์ ──────────────────
        _update_job(job_id, state=JobState.RUNNING, progress=5, message="กำลังโหลดข้อมูลโปรเจกต์...")
        await _broadcast_progress(job_id)

        meta = _get_project_meta(project_id)
        template_id: str = meta.get("template_id", "retirement")
        template_config = template_manager.get_template(template_id)
        if template_config is None:
            template_config = template_manager.get_default_template()

        images = _get_ordered_images(project_id, request.image_order)
        if not images:
            raise RuntimeError("ไม่มีรูปภาพในโปรเจกต์ กรุณาอัพโหลดรูปภาพก่อน")

        # ไฟล์เสียงพื้นหลัง
        audio_path: Path | None = None
        audio_file = meta.get("audio")
        if audio_file:
            candidate = UPLOADS_DIR / project_id / "audio" / audio_file
            if candidate.exists():
                audio_path = candidate

        # ── ขั้นตอน 2: TTS (ถ้าเปิดใช้) ────────────────────
        tts_audio_path: Path | None = None
        if request.use_tts:
            _update_job(job_id, progress=15, message="กำลังสร้างเสียงพูด TTS...")
            await _broadcast_progress(job_id)

            script_path = UPLOADS_DIR / project_id / "script" / "script.json"
            if script_path.exists():
                with script_path.open(encoding="utf-8") as f:
                    script_data = json.load(f)

                from core.tts_engine import text_to_speech
                tts_out = output_dir / "tts_script.mp3"
                result_path = await text_to_speech(
                    text=script_data.get("text", ""),
                    lang=script_data.get("lang", "th"),
                    output_path=tts_out,
                    gender=script_data.get("gender", "female"),
                    rate=script_data.get("rate", "+0%"),
                )
                tts_audio_path = Path(result_path)
                logger.info("สร้าง TTS สำเร็จ: %s", tts_audio_path)
            else:
                logger.warning("ไม่พบ script สำหรับ TTS ข้ามขั้นตอนนี้")

        # ── ขั้นตอน 3: Render วิดีโอ ─────────────────────────
        output_mp4 = output_dir / "output.mp4"

        if request.use_blender:
            _update_job(job_id, progress=30, message="กำลังสร้างฉาก 3D และ Render ด้วย Blender...")
            await _broadcast_progress(job_id)

            from core.blender_engine import render_with_blender
            blender_res = render_with_blender(
                images=[str(img) for img in images],
                template_config=template_config,
                output_path=output_mp4,
                audio=str(audio_path) if audio_path else None,
                script_audio=str(tts_audio_path) if tts_audio_path else None,
                job_id=job_id,
                blender_path=request.blender_path,
            )
            actual_mp4_path = blender_res.get("mp4", str(output_mp4))
            output_dict = {"mp4": actual_mp4_path}
            if "blend" in blender_res:
                output_dict["blend"] = blender_res["blend"]
            _update_job(
                job_id,
                progress=80,
                message="Blender 3D Render สำเร็จ",
                output_files=output_dict,
            )
            await _broadcast_progress(job_id)
        else:
            _update_job(job_id, progress=30, message=f"กำลัง render {len(images)} ภาพด้วย FFmpeg...")
            await _broadcast_progress(job_id)

            # รัน FFmpeg ใน thread executor (blocking subprocess)
            loop = asyncio.get_event_loop()
            from core.ffmpeg_engine import build_slideshow

            await loop.run_in_executor(
                None,
                lambda: build_slideshow(
                    images=[str(img) for img in images],
                    audio=str(audio_path) if audio_path else None,
                    template_config=template_config,
                    output_path=output_mp4,
                    job_id=job_id,
                    script_audio=str(tts_audio_path) if tts_audio_path else None,
                )
            )

            _update_job(
                job_id, progress=80,
                message="Render สำเร็จ",
                output_files={"mp4": str(output_mp4)} if output_mp4.exists() else {}
            )
            await _broadcast_progress(job_id)

        # ── ขั้นตอน 4: MLT Export (ถ้าเปิดใช้) ───────────────
        if request.export_mlt:
            _update_job(job_id, progress=85, message="กำลังสร้างไฟล์ MLT...")
            await _broadcast_progress(job_id)

            from core.mlt_exporter import export_mlt
            output_mlt = output_dir / "project.mlt"
            export_mlt(
                images=[str(img) for img in images],
                audio=str(audio_path) if audio_path else None,
                template_config=template_config,
                output_path=output_mlt,
                job_id=job_id,
            )
            _update_job(job_id, output_files={"mlt": str(output_mlt)})
            logger.info("สร้างไฟล์ MLT สำเร็จ: %s", output_mlt)

        # ── เสร็จสิ้น ─────────────────────────────────────────
        _update_job(
            job_id,
            state=JobState.SUCCESS,
            progress=100,
            message="เสร็จสิ้น! วิดีโอพร้อมดาวน์โหลด",
        )
        await _broadcast_progress(job_id)
        logger.info("งาน render เสร็จสิ้น: job_id=%s", job_id)

    except FileNotFoundError as exc:
        logger.error("ไม่พบไฟล์ที่จำเป็น: %s", exc)
        _update_job(
            job_id,
            state=JobState.FAILED,
            progress=0,
            message="ล้มเหลว: ไม่พบไฟล์ที่จำเป็น",
            error=str(exc),
        )
        await _broadcast_progress(job_id)

    except RuntimeError as exc:
        logger.error("Render ล้มเหลว: %s", exc)
        _update_job(
            job_id,
            state=JobState.FAILED,
            progress=0,
            message=f"ล้มเหลว: {exc}",
            error=str(exc),
        )
        await _broadcast_progress(job_id)

    except Exception as exc:
        logger.exception("ข้อผิดพลาดที่ไม่คาดคิด: %s", exc)
        _update_job(
            job_id,
            state=JobState.FAILED,
            progress=0,
            message="เกิดข้อผิดพลาดที่ไม่คาดคิด",
            error=str(exc),
        )
        await _broadcast_progress(job_id)


# ────────────────────────────────────────────────────────────────
# Routes
# ────────────────────────────────────────────────────────────────

@router.post(
    "/{project_id}",
    summary="เริ่มงาน render",
    status_code=202,
)
async def start_render(
    project_id: str,
    body: RenderRequest,
    background_tasks: BackgroundTasks,
) -> dict[str, Any]:
    """
    เริ่มงาน render วิดีโอ (คืน job_id ทันที งานทำใน background)

    - **use_tts**: แปลง script เป็นเสียง TTS ก่อน render
    - **export_mlt**: สร้างไฟล์ MLT เพิ่มเติม
    - **use_blender**: ใช้ Blender แทน FFmpeg
    - **image_order**: ลำดับชื่อไฟล์รูปภาพ
    """
    # ตรวจสอบโปรเจกต์
    meta_path = UPLOADS_DIR / project_id / "project.json"
    if not meta_path.exists():
        raise HTTPException(status_code=404, detail=f"ไม่พบโปรเจกต์ ID: {project_id}")

    job_id = str(uuid.uuid4())
    job = JobStatus(job_id=job_id, project_id=project_id)
    jobs[job_id] = job
    try:
        (TEMP_DIR / f"job_{job_id}.json").write_text(job.model_dump_json(), encoding="utf-8")
    except Exception:
        pass

    # เริ่มงาน background
    background_tasks.add_task(_run_render_job, job_id, project_id, body)

    logger.info("เริ่มงาน render: job_id=%s, project_id=%s", job_id, project_id)
    return {
        "job_id": job_id,
        "project_id": project_id,
        "message": "เริ่มงาน render แล้ว ติดตามสถานะได้ที่ /render/{job_id}/status",
        "status_url": f"/render/{job_id}/status",
        "ws_url": f"/ws/{job_id}",
    }


@router.get(
    "/{job_id}/status",
    summary="สถานะงาน render",
    response_model=JobStatus,
)
async def get_job_status(job_id: str) -> JobStatus:
    """
    ดูสถานะและความคืบหน้าของงาน render

    - **state**: pending / running / success / failed
    - **progress**: 0-100 เปอร์เซ็นต์
    - **output_files**: พาธไฟล์ผลลัพธ์ (mp4, mlt)
    """
    job = jobs.get(job_id)
    if job is None:
        job_file = TEMP_DIR / f"job_{job_id}.json"
        if job_file.exists():
            try:
                job = JobStatus.model_validate_json(job_file.read_text(encoding="utf-8"))
                jobs[job_id] = job
            except Exception:
                pass
    if job is None:
        raise HTTPException(status_code=404, detail=f"ไม่พบงาน ID: {job_id}")
    return job


@router.get(
    "/{job_id}/download/{file_type}",
    summary="ดาวน์โหลดไฟล์ผลลัพธ์",
)
async def download_output(job_id: str, file_type: str) -> FileResponse:
    """
    ดาวน์โหลดไฟล์ผลลัพธ์ของงาน render

    - **file_type**: mp4 หรือ mlt
    """
    job = jobs.get(job_id)
    if job is None:
        job_file = TEMP_DIR / f"job_{job_id}.json"
        if job_file.exists():
            try:
                job = JobStatus.model_validate_json(job_file.read_text(encoding="utf-8"))
                jobs[job_id] = job
            except Exception:
                pass
    if job is None:
        raise HTTPException(status_code=404, detail=f"ไม่พบงาน ID: {job_id}")

    if job.state != JobState.SUCCESS:
        raise HTTPException(
            status_code=400,
            detail=f"งานยังไม่เสร็จสิ้น (สถานะ: {job.state})"
        )

    VALID_TYPES = {"mp4", "mlt", "blend"}
    if file_type not in VALID_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"ประเภทไฟล์ไม่ถูกต้อง รองรับ: {', '.join(VALID_TYPES)}"
        )

    file_path_str = job.output_files.get(file_type)
    if not file_path_str:
        raise HTTPException(
            status_code=404,
            detail=f"ไม่พบไฟล์ประเภท {file_type} สำหรับงานนี้"
        )

    file_path = Path(file_path_str)
    if not file_path.exists():
        raise HTTPException(
            status_code=404,
            detail=f"ไฟล์ถูกลบหรือไม่มีอยู่: {file_path.name}"
        )

    MEDIA_TYPES = {
        "mp4": "video/mp4",
        "mlt": "application/xml",
        "blend": "application/x-blender",
    }

    return FileResponse(
        path=str(file_path),
        media_type=MEDIA_TYPES.get(file_type, "application/octet-stream"),
        filename=f"project_{job_id[:8]}.{file_type}" if file_type != "mp4" else f"output_{job_id[:8]}.mp4",
    )


# ────────────────────────────────────────────────────────────────
# Route Aliases (รองรับทั้ง /render/... และ /jobs/...)
# ────────────────────────────────────────────────────────────────

@router.get("/jobs/{job_id}", include_in_schema=False)
async def get_job_status_alias(job_id: str) -> JobStatus:
    return await get_job_status(job_id)


@router.get("/jobs/{job_id}/download/{file_type}", include_in_schema=False)
async def download_output_alias(job_id: str, file_type: str) -> FileResponse:
    return await download_output(job_id, file_type)