"""
routers/project.py - API สำหรับจัดการโปรเจกต์
POST /project/create → สร้างโปรเจกต์ใหม่
POST /project/{id}/upload-images → อัพโหลดรูปภาพ
POST /project/{id}/upload-audio → อัพโหลดเสียง
POST /project/{id}/upload-script → อัพโหลด script สำหรับ TTS
GET  /project/{id} → ข้อมูลโปรเจกต์
"""

from __future__ import annotations

import json
import logging
import uuid
from pathlib import Path
from typing import Annotated, Any

import aiofiles
from fastapi import APIRouter, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from core.template_manager import template_manager

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/project", tags=["Project"])

# ────────────────────────────────────────────────────────────────
# Base directory สำหรับ uploads
# ────────────────────────────────────────────────────────────────
UPLOADS_DIR: Path = Path(__file__).parent.parent / "uploads"

# ประเภทไฟล์รูปภาพที่ยอมรับ
ALLOWED_IMAGE_TYPES: set[str] = {
    "image/jpeg", "image/jpg", "image/png", "image/webp", "image/bmp", "image/tiff"
}

# ประเภทไฟล์เสียงที่ยอมรับ
ALLOWED_AUDIO_TYPES: set[str] = {
    "audio/mpeg", "audio/mp3", "audio/wav", "audio/x-wav",
    "audio/ogg", "audio/flac", "audio/aac", "audio/mp4",
}

# ขนาดไฟล์สูงสุด (bytes)
MAX_IMAGE_SIZE: int = 50 * 1024 * 1024   # 50 MB
MAX_AUDIO_SIZE: int = 200 * 1024 * 1024  # 200 MB


# ────────────────────────────────────────────────────────────────
# Pydantic models
# ────────────────────────────────────────────────────────────────

class CreateProjectRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=200, description="ชื่อโปรเจกต์")
    template_id: str = Field(..., description="รหัสเทมเพลต")


class ScriptRequest(BaseModel):
    text: str = Field(..., min_length=1, description="ข้อความสำหรับ TTS")
    lang: str = Field("th", description="รหัสภาษา: th หรือ en")
    gender: str = Field("female", description="เพศเสียง: male หรือ female")
    rate: str = Field("+0%", description="ความเร็วพูด: เช่น +0%, +10%, -10%")


# ────────────────────────────────────────────────────────────────
# Helper functions
# ────────────────────────────────────────────────────────────────

def _get_project_dir(project_id: str) -> Path:
    """คืนพาธของไดเรกทอรีโปรเจกต์"""
    return UPLOADS_DIR / project_id


def _get_project_meta(project_id: str) -> dict[str, Any]:
    """โหลด metadata ของโปรเจกต์จาก project.json"""
    meta_path = _get_project_dir(project_id) / "project.json"
    if not meta_path.exists():
        raise HTTPException(status_code=404, detail=f"ไม่พบโปรเจกต์ ID: {project_id}")
    with meta_path.open(encoding="utf-8") as f:
        return json.load(f)


def _save_project_meta(project_id: str, meta: dict[str, Any]) -> None:
    """บันทึก metadata ของโปรเจกต์"""
    meta_path = _get_project_dir(project_id) / "project.json"
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")


def _list_images(project_dir: Path) -> list[str]:
    """รายการไฟล์รูปภาพในโปรเจกต์ (เรียงตามชื่อ)"""
    images_dir = project_dir / "images"
    if not images_dir.exists():
        return []
    exts = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tiff"}
    return sorted(
        str(p.name) for p in images_dir.iterdir()
        if p.suffix.lower() in exts
    )


# ────────────────────────────────────────────────────────────────
# Routes
# ────────────────────────────────────────────────────────────────

@router.post(
    "/create",
    summary="สร้างโปรเจกต์ใหม่",
    status_code=201,
)
async def create_project(body: CreateProjectRequest) -> dict[str, Any]:
    """
    สร้างโปรเจกต์ใหม่และเตรียมไดเรกทอรี

    - **name**: ชื่อโปรเจกต์ (ภาษาไทยหรืออังกฤษ)
    - **template_id**: รหัสเทมเพลต (เช่น retirement, birthday)
    """
    # ตรวจสอบว่า template มีอยู่
    template = template_manager.get_template(body.template_id)
    if template is None:
        raise HTTPException(status_code=400, detail=f"ไม่พบเทมเพลต: {body.template_id}")

    project_id = str(uuid.uuid4())
    project_dir = _get_project_dir(project_id)

    # สร้างไดเรกทอรีโปรเจกต์
    (project_dir / "images").mkdir(parents=True, exist_ok=True)
    (project_dir / "audio").mkdir(parents=True, exist_ok=True)
    (project_dir / "script").mkdir(parents=True, exist_ok=True)

    meta: dict[str, Any] = {
        "project_id": project_id,
        "name": body.name,
        "template_id": body.template_id,
        "template_name_th": template.get("name_th", ""),
        "images": [],
        "audio": None,
        "script": None,
        "created_at": __import__("datetime").datetime.now().isoformat(),
    }
    _save_project_meta(project_id, meta)

    logger.info("สร้างโปรเจกต์ใหม่: %s (%s)", project_id, body.name)
    return {"project_id": project_id, "message": "สร้างโปรเจกต์สำเร็จ", **meta}


@router.post(
    "/{project_id}/upload-images",
    summary="อัพโหลดรูปภาพหลายไฟล์",
)
async def upload_images(
    project_id: str,
    files: Annotated[list[UploadFile], File(description="รูปภาพ (JPG, PNG, WEBP)")] = [],
    images: Annotated[list[UploadFile], File(description="รูปภาพ (JPG, PNG, WEBP)")] = [],
) -> dict[str, Any]:
    """
    อัพโหลดรูปภาพหลายไฟล์พร้อมกันเข้าโปรเจกต์

    รองรับ: JPEG, PNG, WEBP, BMP, TIFF (รับทั้งฟิลด์ 'files' และ 'images')
    """
    meta = _get_project_meta(project_id)
    project_dir = _get_project_dir(project_id)
    images_dir = project_dir / "images"
    images_dir.mkdir(parents=True, exist_ok=True)

    saved: list[str] = []
    errors: list[str] = []
    target_uploads = images if images else files

    if not target_uploads:
        raise HTTPException(status_code=400, detail="กรุณาเลือกไฟล์รูปภาพสำหรับอัพโหลด")

    for upload in target_uploads:
        # ตรวจสอบประเภทไฟล์
        content_type = upload.content_type or ""
        if content_type not in ALLOWED_IMAGE_TYPES:
            # ตรวจจาก extension แทน
            ext = Path(upload.filename or "").suffix.lower()
            if ext not in {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tiff"}:
                errors.append(f"ไม่รองรับไฟล์: {upload.filename} (type: {content_type})")
                continue

        # อ่านข้อมูล
        data = await upload.read()
        if len(data) > MAX_IMAGE_SIZE:
            errors.append(f"ไฟล์ {upload.filename} ใหญ่เกิน {MAX_IMAGE_SIZE // 1024 // 1024} MB")
            continue

        # สร้างชื่อไฟล์ที่ปลอดภัย
        original_ext = Path(upload.filename or "image.jpg").suffix.lower()
        if original_ext not in {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tiff"}:
            original_ext = ".jpg"
        safe_name = f"{uuid.uuid4().hex}{original_ext}"
        dest = images_dir / safe_name

        async with aiofiles.open(dest, "wb") as f:
            await f.write(data)

        saved.append(safe_name)
        logger.info("บันทึกรูปภาพ: %s → %s", upload.filename, safe_name)

    # อัพเดท metadata
    meta["images"] = _list_images(project_dir)
    _save_project_meta(project_id, meta)

    return {
        "project_id": project_id,
        "saved": saved,
        "errors": errors,
        "total_images": len(meta["images"]),
        "message": f"อัพโหลดสำเร็จ {len(saved)} ไฟล์" + (f", ข้อผิดพลาด {len(errors)} ไฟล์" if errors else ""),
    }


@router.post(
    "/{project_id}/upload-audio",
    summary="อัพโหลดไฟล์เสียงพื้นหลัง",
)
async def upload_audio(
    project_id: str,
    file: Annotated[UploadFile | None, File(description="ไฟล์เสียง (MP3, WAV, OGG)")] = None,
    audio: Annotated[UploadFile | None, File(description="ไฟล์เสียง (MP3, WAV, OGG)")] = None,
) -> dict[str, Any]:
    """
    อัพโหลดไฟล์เสียงพื้นหลังสำหรับโปรเจกต์

    รองรับ: MP3, WAV, OGG, FLAC, AAC (รับทั้งฟิลด์ 'file' และ 'audio')
    """
    meta = _get_project_meta(project_id)
    project_dir = _get_project_dir(project_id)
    audio_dir = project_dir / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)

    upload_file = audio if audio is not None else file
    if upload_file is None:
        raise HTTPException(status_code=400, detail="กรุณาเลือกไฟล์เสียงสำหรับอัพโหลด")

    # ตรวจสอบประเภทไฟล์
    content_type = upload_file.content_type or ""
    ext = Path(upload_file.filename or "audio.mp3").suffix.lower()
    allowed_exts = {".mp3", ".wav", ".ogg", ".flac", ".aac", ".m4a"}

    if content_type not in ALLOWED_AUDIO_TYPES and ext not in allowed_exts:
        raise HTTPException(
            status_code=400,
            detail=f"ไม่รองรับไฟล์เสียงประเภท: {content_type or ext}"
        )

    data = await file.read()
    if len(data) > MAX_AUDIO_SIZE:
        raise HTTPException(
            status_code=413,
            detail=f"ไฟล์เสียงใหญ่เกิน {MAX_AUDIO_SIZE // 1024 // 1024} MB"
        )

    # ลบไฟล์เสียงเก่า (ถ้ามี)
    for old_file in audio_dir.iterdir():
        old_file.unlink(missing_ok=True)

    if ext not in allowed_exts:
        ext = ".mp3"
    audio_filename = f"background{ext}"
    dest = audio_dir / audio_filename

    async with aiofiles.open(dest, "wb") as f:
        await f.write(data)

    meta["audio"] = audio_filename
    _save_project_meta(project_id, meta)

    logger.info("บันทึกไฟล์เสียง: %s → %s", file.filename, audio_filename)
    return {
        "project_id": project_id,
        "audio_file": audio_filename,
        "size_kb": round(len(data) / 1024, 1),
        "message": "อัพโหลดไฟล์เสียงสำเร็จ",
    }


@router.post(
    "/{project_id}/upload-script",
    summary="บันทึก script สำหรับ TTS",
)
async def upload_script(project_id: str, body: ScriptRequest) -> dict[str, Any]:
    """
    บันทึกข้อความสำหรับแปลงเป็นเสียงพูด (TTS)

    - **text**: ข้อความที่ต้องการพูด
    - **lang**: รหัสภาษา (th/en)
    - **gender**: เพศเสียง (male/female)
    """
    meta = _get_project_meta(project_id)
    project_dir = _get_project_dir(project_id)
    script_dir = project_dir / "script"
    script_dir.mkdir(parents=True, exist_ok=True)

    script_data = {
        "text": body.text,
        "lang": body.lang,
        "gender": body.gender,
        "rate": body.rate,
        "char_count": len(body.text),
    }

    script_path = script_dir / "script.json"
    script_path.write_text(
        json.dumps(script_data, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    meta["script"] = script_data
    _save_project_meta(project_id, meta)

    logger.info("บันทึก script TTS: %d ตัวอักษร, ภาษา=%s, เพศ=%s, ความเร็ว=%s", len(body.text), body.lang, body.gender, body.rate)
    return {
        "project_id": project_id,
        "char_count": len(body.text),
        "lang": body.lang,
        "gender": body.gender,
        "rate": body.rate,
        "message": "บันทึก script สำเร็จ",
    }


@router.get(
    "/{project_id}",
    summary="ข้อมูลโปรเจกต์",
)
async def get_project(project_id: str) -> dict[str, Any]:
    """
    ดูข้อมูลและสถานะของโปรเจกต์

    คืนรายการรูปภาพ, ไฟล์เสียง, script และ template ที่ใช้
    """
    meta = _get_project_meta(project_id)
    project_dir = _get_project_dir(project_id)

    # อัพเดทรายการรูปภาพจาก filesystem จริง
    meta["images"] = _list_images(project_dir)

    # ตรวจสอบไฟล์เสียง
    audio_file = meta.get("audio")
    if audio_file:
        audio_path = project_dir / "audio" / audio_file
        meta["audio_exists"] = audio_path.exists()
    else:
        meta["audio_exists"] = False

    # ตรวจสอบ script
    script_path = project_dir / "script" / "script.json"
    if script_path.exists():
        with script_path.open(encoding="utf-8") as f:
            meta["script"] = json.load(f)
    else:
        meta["script"] = None

    return meta


# ────────────────────────────────────────────────────────────────
# Route Aliases & Projects List (รองรับ /projects และ REST รูปแบบสากล)
# ────────────────────────────────────────────────────────────────

@router.get("", summary="รายการโปรเจกต์ทั้งหมด")
async def list_projects() -> list[dict[str, Any]]:
    """คืนรายการโปรเจกต์ทั้งหมดในระบบ"""
    if not UPLOADS_DIR.exists():
        return []
    results: list[dict[str, Any]] = []
    for d in sorted(UPLOADS_DIR.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True):
        if d.is_dir():
            meta_file = d / "project.json"
            if meta_file.exists():
                try:
                    with meta_file.open(encoding="utf-8") as f:
                        results.append(json.load(f))
                except Exception:
                    pass
    return results


# สร้าง sub-router สำหรับ prefix /projects ด้วย
projects_router = APIRouter(prefix="/projects", tags=["Projects"])

@projects_router.get("")
async def projects_list_alias() -> list[dict[str, Any]]:
    return await list_projects()

@projects_router.post("")
async def projects_create_alias(body: CreateProjectRequest) -> dict[str, Any]:
    return await create_project(body)

@projects_router.get("/{project_id}")
async def projects_get_alias(project_id: str) -> dict[str, Any]:
    return await get_project(project_id)

@projects_router.post("/{project_id}/images")
async def projects_images_alias(
    project_id: str,
    files: Annotated[list[UploadFile], File(...)] = [],
    images: Annotated[list[UploadFile], File(...)] = [],
) -> dict[str, Any]:
    return await upload_images(project_id, files=files, images=images)

@projects_router.post("/{project_id}/audio")
async def projects_audio_alias(
    project_id: str,
    file: Annotated[UploadFile | None, File(...)] = None,
    audio: Annotated[UploadFile | None, File(...)] = None,
) -> dict[str, Any]:
    return await upload_audio(project_id, file=file, audio=audio)

@projects_router.post("/{project_id}/script")
async def projects_script_alias(project_id: str, body: ScriptRequest) -> dict[str, Any]:
    return await upload_script(project_id, body)