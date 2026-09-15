"""
mlt_exporter.py - สร้างไฟล์ MLT XML สำหรับ Kdenlive
สร้างโปรเจกต์วิดีโอ MLT ที่ compatible กับ Kdenlive/Shotcut
"""

from __future__ import annotations

import logging
import math
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any
from xml.dom import minidom

logger = logging.getLogger(__name__)

# ────────────────────────────────────────────────────────────────
# ค่าคงที่ MLT
# ────────────────────────────────────────────────────────────────
MLT_VERSION: str = "7.0.0"
MLT_PROFILE_WIDTH: int = 1920
MLT_PROFILE_HEIGHT: int = 1080
MLT_PROFILE_FPS_NUM: int = 25
MLT_PROFILE_FPS_DEN: int = 1
MLT_PROFILE_SAR_NUM: int = 1
MLT_PROFILE_SAR_DEN: int = 1
MLT_PROFILE_COLORSPACE: int = 709


def _frames(seconds: float, fps: int = MLT_PROFILE_FPS_NUM) -> int:
    """แปลงวินาทีเป็นจำนวนเฟรม"""
    return math.floor(seconds * fps)


def _add_property(parent: ET.Element, name: str, value: str) -> ET.Element:
    """เพิ่ม <property name="...">value</property> ให้กับ element"""
    prop = ET.SubElement(parent, "property", name=name)
    prop.text = str(value)
    return prop


def export_mlt(
    images: list[str | Path],
    audio: str | Path | None,
    template_config: dict[str, Any],
    output_path: str | Path,
    job_id: str = "default",
) -> str:
    """
    สร้างไฟล์ MLT XML (Kdenlive-compatible)

    Args:
        images: รายการพาธรูปภาพ (ตามลำดับ)
        audio: พาธไฟล์เสียงพื้นหลัง (None ถ้าไม่มี)
        template_config: ค่าการตั้งค่าจาก template JSON
        output_path: พาธสำหรับบันทึกไฟล์ .mlt
        job_id: รหัสงาน

    Returns:
        str: พาธของไฟล์ .mlt ที่สร้าง
    """
    images = [Path(img) for img in images]
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    duration_per_image: float = float(template_config.get("duration_per_image", 5))
    fade_duration: float = float(template_config.get("fade_duration", 1.5))
    transition: str = template_config.get("transition", "crossfade")
    intro_text: str = template_config.get("intro_text", "")
    outro_text: str = template_config.get("outro_text", "")
    template_name: str = template_config.get("name_th", template_config.get("name", "Project"))

    fps = MLT_PROFILE_FPS_NUM
    img_frames = _frames(duration_per_image)
    fade_frames = _frames(fade_duration)

    # ────────────────────────────────────────────────────────────
    # Root element <mlt>
    # ────────────────────────────────────────────────────────────
    mlt = ET.Element("mlt", {
        "version": MLT_VERSION,
        "title": template_name,
        "producer": "main_bin",
        "LC_NUMERIC": "C",
    })

    # <profile>
    ET.SubElement(mlt, "profile", {
        "description": "HD 1080p 25fps",
        "width": str(MLT_PROFILE_WIDTH),
        "height": str(MLT_PROFILE_HEIGHT),
        "progressive": "1",
        "sample_aspect_num": str(MLT_PROFILE_SAR_NUM),
        "sample_aspect_den": str(MLT_PROFILE_SAR_DEN),
        "display_aspect_num": "16",
        "display_aspect_den": "9",
        "frame_rate_num": str(MLT_PROFILE_FPS_NUM),
        "frame_rate_den": str(MLT_PROFILE_FPS_DEN),
        "colorspace": str(MLT_PROFILE_COLORSPACE),
    })

    # ────────────────────────────────────────────────────────────
    # Producer สำหรับแต่ละรูปภาพ
    # ────────────────────────────────────────────────────────────
    producer_ids: list[str] = []
    for i, img in enumerate(images):
        pid = f"producer_img_{i}"
        producer_ids.append(pid)
        prod = ET.SubElement(mlt, "producer", {
            "id": pid,
            "in": "0",
            "out": str(img_frames + fade_frames - 1),
        })
        _add_property(prod, "resource", str(img.resolve()))
        _add_property(prod, "mlt_service", "pixbuf")
        _add_property(prod, "ttl", "1")
        _add_property(prod, "length", str(img_frames + fade_frames))
        _add_property(prod, "kdenlive:clipname", img.name)
        _add_property(prod, "kdenlive:clip_type", "2")  # 2 = image

    # ────────────────────────────────────────────────────────────
    # Producer สำหรับเสียง (ถ้ามี)
    # ────────────────────────────────────────────────────────────
    total_frames = img_frames * len(images)
    audio_producer_id: str | None = None
    if audio and Path(str(audio)).exists():
        audio_producer_id = "producer_audio_bg"
        aprod = ET.SubElement(mlt, "producer", {
            "id": audio_producer_id,
            "in": "0",
            "out": str(total_frames - 1),
        })
        _add_property(aprod, "resource", str(Path(str(audio)).resolve()))
        _add_property(aprod, "mlt_service", "avformat")
        _add_property(aprod, "audio_index", "0")
        _add_property(aprod, "video_index", "-1")
        _add_property(aprod, "kdenlive:clipname", Path(str(audio)).name)
        _add_property(aprod, "kdenlive:clip_type", "3")  # 3 = audio

    # ────────────────────────────────────────────────────────────
    # main_bin playlist (bin สำหรับ Kdenlive)
    # ────────────────────────────────────────────────────────────
    main_bin = ET.SubElement(mlt, "playlist", {"id": "main_bin"})
    _add_property(main_bin, "kdenlive:docproperties.activeTrack", "2")
    _add_property(main_bin, "kdenlive:docproperties.version", "1.00")
    _add_property(main_bin, "kdenlive:docproperties.projectfolder", str(output_path.parent))

    for pid in producer_ids:
        ET.SubElement(main_bin, "entry", {"producer": pid, "in": "0", "out": "0"})
    if audio_producer_id:
        ET.SubElement(main_bin, "entry", {"producer": audio_producer_id, "in": "0", "out": "0"})

    # ────────────────────────────────────────────────────────────
    # Video Playlist (V1)
    # ────────────────────────────────────────────────────────────
    v1_playlist = ET.SubElement(mlt, "playlist", {"id": "playlist_v1"})
    _add_property(v1_playlist, "kdenlive:track_name", "Video Track 1")

    for i, pid in enumerate(producer_ids):
        # เฟรมเริ่มต้น (คำนึง overlap สำหรับ transition)
        start = i * img_frames
        entry = ET.SubElement(v1_playlist, "entry", {
            "producer": pid,
            "in": "0",
            "out": str(img_frames + fade_frames - 1),
        })
        # Blank ระหว่างคลิปถ้าไม่ใช่คลิปสุดท้าย
        if i < len(producer_ids) - 1:
            pass  # tractor จัดการ transition — ไม่ต้องใส่ blank ที่นี่

    # ────────────────────────────────────────────────────────────
    # Audio Playlist (A1)
    # ────────────────────────────────────────────────────────────
    a1_playlist = ET.SubElement(mlt, "playlist", {"id": "playlist_a1"})
    _add_property(a1_playlist, "kdenlive:track_name", "Audio Track 1")

    if audio_producer_id:
        ET.SubElement(a1_playlist, "entry", {
            "producer": audio_producer_id,
            "in": "0",
            "out": str(total_frames - 1),
        })
    else:
        ET.SubElement(a1_playlist, "blank", {"length": str(total_frames)})

    # ────────────────────────────────────────────────────────────
    # Tractor (Timeline)
    # ────────────────────────────────────────────────────────────
    tractor = ET.SubElement(mlt, "tractor", {
        "id": "tractor_main",
        "in": "0",
        "out": str(total_frames - 1),
        "title": template_name,
    })
    _add_property(tractor, "kdenlive:docproperties.projectName", template_name)

    # Track entries
    ET.SubElement(tractor, "track", {"producer": "playlist_a1", "hide": "video"})
    ET.SubElement(tractor, "track", {"producer": "playlist_v1", "hide": "audio"})

    # ────────────────────────────────────────────────────────────
    # Transitions (xfade)
    # ────────────────────────────────────────────────────────────
    # Map transition name → MLT transition service
    MLT_TRANS_MAP: dict[str, str] = {
        "crossfade": "luma",
        "push_slide": "slide",
        "wipe_diagonal": "luma",
        "glitter": "luma",
        "zoom_in": "luma",
        "slide": "slide",
        "wipe": "luma",
        "default": "luma",
    }
    mlt_trans = MLT_TRANS_MAP.get(transition, "luma")

    for i in range(len(images) - 1):
        offset = img_frames * (i + 1)
        trans = ET.SubElement(tractor, "transition", {
            "id": f"transition_{i}",
            "in": str(offset),
            "out": str(offset + fade_frames - 1),
        })
        _add_property(trans, "a_track", "0")
        _add_property(trans, "b_track", "1")
        _add_property(trans, "mlt_service", mlt_trans)
        _add_property(trans, "automatic", "1")
        if mlt_trans == "slide":
            _add_property(trans, "direction", "left")

    # ────────────────────────────────────────────────────────────
    # บันทึกไฟล์ .mlt
    # ────────────────────────────────────────────────────────────
    tree_str = ET.tostring(mlt, encoding="unicode", xml_declaration=False)
    # Pretty-print ด้วย minidom
    pretty = minidom.parseString(f'<?xml version="1.0" encoding="utf-8"?>{tree_str}').toprettyxml(indent="  ")
    # ตัดบรรทัดแรกที่ minidom เพิ่มให้ (เพราะเราใส่เองแล้ว)
    lines = pretty.split("\n")
    if lines[0].startswith("<?xml"):
        pretty_output = "\n".join(lines)
    else:
        pretty_output = pretty

    output_path.write_text(pretty_output, encoding="utf-8")
    logger.info("สร้างไฟล์ MLT สำเร็จ: %s", output_path)
    return str(output_path)