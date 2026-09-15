"""
mlt_exporter.py - สร้างไฟล์โปรเจกต์ Kdenlive (.kdenlive) และ MLT (.mlt)
รองรับ Kdenlive เวอร์ชันล่าสุด (22.x, 24.x, 26.x) และ Shotcut
สร้างไทม์ไลน์แบบมัลติแทร็ก (A/B Roll) พร้อมทรานซิชัน Crossfade/Luma และแทร็กเสียง
"""

from __future__ import annotations

import logging
import math
import time
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any
from xml.dom import minidom

logger = logging.getLogger(__name__)

# ────────────────────────────────────────────────────────────────
# ค่าคงที่ MLT และ Kdenlive
# ────────────────────────────────────────────────────────────────
MLT_VERSION: str = "7.13.0"
MLT_PROFILE_WIDTH: int = 1920
MLT_PROFILE_HEIGHT: int = 1080
MLT_PROFILE_FPS_NUM: int = 25
MLT_PROFILE_FPS_DEN: int = 1
MLT_PROFILE_SAR_NUM: int = 1
MLT_PROFILE_SAR_DEN: int = 1
MLT_PROFILE_COLORSPACE: int = 709


def _frames(seconds: float, fps: int = MLT_PROFILE_FPS_NUM) -> int:
    """แปลงวินาทีเป็นจำนวนเฟรม"""
    return max(1, math.floor(seconds * fps))


def _add_property(parent: ET.Element, name: str, value: str) -> ET.Element:
    """เพิ่ม <property name="...">value</property> ให้กับ element"""
    prop = ET.SubElement(parent, "property", name=name)
    prop.text = str(value)
    return prop


def export_mlt(
    images: list[str | Path],
    audio: str | Path | None = None,
    template_config: dict[str, Any] | None = None,
    output_path: str | Path = "project.kdenlive",
    job_id: str = "default",
    script_audio: str | Path | None = None,
) -> dict[str, str]:
    """
    สร้างไฟล์โปรเจกต์ Kdenlive (.kdenlive) และ MLT (.mlt)

    Args:
        images: รายการพาธรูปภาพ (ตามลำดับ)
        audio: พาธไฟล์เสียงพื้นหลัง (None ถ้าไม่มี)
        template_config: ค่าการตั้งค่าจาก template JSON
        output_path: พาธสำหรับบันทึกไฟล์ (เช่น .../project.kdenlive หรือ project.mlt)
        job_id: รหัสงาน
        script_audio: พาธไฟล์เสียงพูด TTS (None ถ้าไม่มี)

    Returns:
        dict[str, str]: {'kdenlive': path_kdenlive, 'mlt': path_mlt}
    """
    cfg = template_config or {}
    images = [Path(img) for img in images]
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    duration_per_image: float = float(cfg.get("duration_per_image", 4.0))
    fade_duration: float = float(cfg.get("fade_duration", 1.0))
    template_name: str = cfg.get("name_th", cfg.get("name", "Project"))

    fps = MLT_PROFILE_FPS_NUM
    img_frames = _frames(duration_per_image, fps)
    fade_frames = _frames(fade_duration, fps)
    if fade_frames >= img_frames:
        fade_frames = max(1, img_frames // 2)

    num_imgs = len(images)
    if num_imgs == 0:
        logger.warning("ไม่มีรูปภาพสำหรับสร้างไฟล์ Kdenlive/MLT")
        return {}

    # คำนวณความยาวเฟรมรวมของไทม์ไลน์
    step_frames = img_frames - fade_frames
    total_timeline_frames = (num_imgs * img_frames) - ((num_imgs - 1) * fade_frames) if num_imgs > 1 else img_frames

    # ────────────────────────────────────────────────────────────
    # 1. Root Element <mlt>
    # ────────────────────────────────────────────────────────────
    mlt = ET.Element("mlt", {
        "LC_NUMERIC": "C",
        "version": MLT_VERSION,
        "title": template_name,
        "producer": "main_bin",
        "root": "",
    })

    # <profile>
    ET.SubElement(mlt, "profile", {
        "description": "HD 1080p 25 fps",
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
    # 2. Producers สำหรับรูปภาพ
    # ────────────────────────────────────────────────────────────
    producer_ids: list[str] = []
    for i, img in enumerate(images):
        pid = f"prod_img_{i}"
        producer_ids.append(pid)
        prod = ET.SubElement(mlt, "producer", {
            "id": pid,
            "in": "0",
            "out": str(img_frames - 1),
        })
        _add_property(prod, "resource", str(img.resolve()))
        _add_property(prod, "mlt_service", "pixbuf")
        _add_property(prod, "ttl", "1")
        _add_property(prod, "length", str(img_frames))
        _add_property(prod, "aspect_ratio", "1")
        _add_property(prod, "kdenlive:clipname", img.name)
        _add_property(prod, "kdenlive:folderid", "-1")
        _add_property(prod, "kdenlive:id", str(i + 2))
        _add_property(prod, "kdenlive:clip_type", "2")  # 2 = Image

    # Producer สำหรับเพลงพื้นหลัง
    audio_path = Path(str(audio)) if audio and Path(str(audio)).exists() else None
    audio_pid: str | None = None
    if audio_path:
        audio_pid = "prod_audio_bg"
        aprod = ET.SubElement(mlt, "producer", {
            "id": audio_pid,
            "in": "0",
            "out": str(total_timeline_frames - 1),
        })
        _add_property(aprod, "resource", str(audio_path.resolve()))
        _add_property(aprod, "mlt_service", "avformat")
        _add_property(aprod, "audio_index", "0")
        _add_property(aprod, "video_index", "-1")
        _add_property(aprod, "kdenlive:clipname", audio_path.name)
        _add_property(aprod, "kdenlive:folderid", "-1")
        _add_property(aprod, "kdenlive:clip_type", "3")  # 3 = Audio
        _add_property(aprod, "kdenlive:id", str(num_imgs + 2))

    # Producer สำหรับเสียงบรรยาย TTS
    tts_path = Path(str(script_audio)) if script_audio and Path(str(script_audio)).exists() else None
    tts_pid: str | None = None
    if tts_path:
        tts_pid = "prod_audio_tts"
        tprod = ET.SubElement(mlt, "producer", {
            "id": tts_pid,
            "in": "0",
            "out": str(total_timeline_frames - 1),
        })
        _add_property(tprod, "resource", str(tts_path.resolve()))
        _add_property(tprod, "mlt_service", "avformat")
        _add_property(tprod, "audio_index", "0")
        _add_property(tprod, "video_index", "-1")
        _add_property(tprod, "kdenlive:clipname", tts_path.name)
        _add_property(tprod, "kdenlive:folderid", "-1")
        _add_property(tprod, "kdenlive:clip_type", "3")
        _add_property(tprod, "kdenlive:id", str(num_imgs + 3))

    # ────────────────────────────────────────────────────────────
    # 3. Project Bin (main_bin playlist)
    # ────────────────────────────────────────────────────────────
    main_bin = ET.SubElement(mlt, "playlist", {"id": "main_bin"})
    _add_property(main_bin, "kdenlive:docproperties.version", "1.04")
    _add_property(main_bin, "kdenlive:docproperties.kdenliveversion", "22.12.3")
    _add_property(main_bin, "kdenlive:docproperties.profile", "atsc_1080p_25")
    _add_property(main_bin, "kdenlive:docproperties.documentid", str(int(time.time() * 1000)))
    _add_property(main_bin, "kdenlive:docproperties.compositing", "1")
    _add_property(main_bin, "kdenlive:docproperties.enableproxy", "0")
    _add_property(main_bin, "kdenlive:docproperties.generateproxy", "0")
    _add_property(main_bin, "kdenlive:docproperties.projectfolder", str(output_path.parent.resolve()))

    for pid in producer_ids:
        ET.SubElement(main_bin, "entry", {"producer": pid, "in": "0", "out": str(img_frames - 1)})
    if audio_pid:
        ET.SubElement(main_bin, "entry", {"producer": audio_pid, "in": "0", "out": str(total_timeline_frames - 1)})
    if tts_pid:
        ET.SubElement(main_bin, "entry", {"producer": tts_pid, "in": "0", "out": str(total_timeline_frames - 1)})

    # ────────────────────────────────────────────────────────────
    # 4. Multi-track A/B Roll Playlists (V1 and V2)
    # สลับภาพลงแทร็ก V1 และ V2 เพื่อให้ทำ Crossfade/Dissolve ได้สมบูรณ์
    # ────────────────────────────────────────────────────────────
    pl_v1 = ET.SubElement(mlt, "playlist", {"id": "playlist_v1"})
    _add_property(pl_v1, "kdenlive:track_name", "Video 1")

    pl_v2 = ET.SubElement(mlt, "playlist", {"id": "playlist_v2"})
    _add_property(pl_v2, "kdenlive:track_name", "Video 2")

    v1_pos = 0
    v2_pos = 0

    for i, pid in enumerate(producer_ids):
        start_time = i * step_frames
        end_time = start_time + img_frames

        if i % 2 == 0:
            # วางลง Track V1
            if start_time > v1_pos:
                ET.SubElement(pl_v1, "blank", {"length": str(start_time - v1_pos)})
            entry = ET.SubElement(pl_v1, "entry", {"producer": pid, "in": "0", "out": str(img_frames - 1)})
            _add_property(entry, "kdenlive:id", str(i + 2))
            v1_pos = end_time
        else:
            # วางลง Track V2
            if start_time > v2_pos:
                ET.SubElement(pl_v2, "blank", {"length": str(start_time - v2_pos)})
            entry = ET.SubElement(pl_v2, "entry", {"producer": pid, "in": "0", "out": str(img_frames - 1)})
            _add_property(entry, "kdenlive:id", str(i + 2))
            v2_pos = end_time

    # ────────────────────────────────────────────────────────────
    # 5. Audio Playlists (A1 สำหรับเพลง, A2 สำหรับ TTS)
    # ────────────────────────────────────────────────────────────
    audio_tracks: list[str] = []

    if audio_pid:
        pl_a1 = ET.SubElement(mlt, "playlist", {"id": "playlist_a1"})
        _add_property(pl_a1, "kdenlive:audio_track", "1")
        _add_property(pl_a1, "kdenlive:track_name", "Background Music")
        entry = ET.SubElement(pl_a1, "entry", {"producer": audio_pid, "in": "0", "out": str(total_timeline_frames - 1)})
        _add_property(entry, "kdenlive:id", str(num_imgs + 2))
        audio_tracks.append("playlist_a1")

    if tts_pid:
        pl_a2 = ET.SubElement(mlt, "playlist", {"id": "playlist_a2"})
        _add_property(pl_a2, "kdenlive:audio_track", "1")
        _add_property(pl_a2, "kdenlive:track_name", "Voiceover (TTS)")
        # เว้นช่วง 0.8 วิ ก่อนเริ่มพูด
        pre_delay = _frames(0.8, fps)
        ET.SubElement(pl_a2, "blank", {"length": str(pre_delay)})
        entry = ET.SubElement(pl_a2, "entry", {"producer": tts_pid, "in": "0", "out": str(total_timeline_frames - 1)})
        _add_property(entry, "kdenlive:id", str(num_imgs + 3))
        audio_tracks.append("playlist_a2")

    # ────────────────────────────────────────────────────────────
    # 6. Timeline Tractor
    # ────────────────────────────────────────────────────────────
    tractor = ET.SubElement(mlt, "tractor", {
        "id": "tractor_main",
        "in": "0",
        "out": str(total_timeline_frames - 1),
        "title": template_name,
    })
    _add_property(tractor, "kdenlive:timeline_active", "1")
    _add_property(tractor, "kdenlive:docproperties.projectName", template_name)

    # แทร็กเรียงลำดับ: Audio แทร็กก่อน ตามด้วย Video แทร็ก
    track_index = 0
    for atrack in audio_tracks:
        ET.SubElement(tractor, "track", {"producer": atrack, "hide": "video"})
        track_index += 1

    v1_track_idx = track_index
    ET.SubElement(tractor, "track", {"producer": "playlist_v1", "hide": "audio"})
    track_index += 1

    v2_track_idx = track_index
    ET.SubElement(tractor, "track", {"producer": "playlist_v2", "hide": "audio"})
    track_index += 1

    # ────────────────────────────────────────────────────────────
    # 7. Transitions ระหว่าง Track V1 และ V2 (Luma Crossfade)
    # ────────────────────────────────────────────────────────────
    for i in range(num_imgs - 1):
        trans_start = (i + 1) * step_frames
        trans_end = trans_start + fade_frames - 1

        tr = ET.SubElement(tractor, "transition", {
            "id": f"transition_{i}",
            "in": str(trans_start),
            "out": str(trans_end),
        })
        _add_property(tr, "a_track", str(v1_track_idx))
        _add_property(tr, "b_track", str(v2_track_idx))
        _add_property(tr, "mlt_service", "luma")
        _add_property(tr, "kdenlive_id", "luma")
        _add_property(tr, "automatic", "1")

    # ────────────────────────────────────────────────────────────
    # 8. บันทึกเป็นไฟล์ .kdenlive และ .mlt
    # ────────────────────────────────────────────────────────────
    tree_str = ET.tostring(mlt, encoding="unicode", xml_declaration=False)
    pretty = minidom.parseString(f'<?xml version="1.0" encoding="utf-8"?>{tree_str}').toprettyxml(indent="  ")
    lines = pretty.split("\n")
    pretty_output = "\n".join(lines) if lines[0].startswith("<?xml") else pretty

    # บันทึกทั้ง .kdenlive และ .mlt
    kdenlive_path = output_path.with_suffix(".kdenlive")
    mlt_path = output_path.with_suffix(".mlt")

    kdenlive_path.write_text(pretty_output, encoding="utf-8")
    mlt_path.write_text(pretty_output, encoding="utf-8")

    logger.info("สร้างไฟล์โปรเจกต์สำเร็จ: %s และ %s", kdenlive_path, mlt_path)
    return {
        "kdenlive": str(kdenlive_path),
        "mlt": str(mlt_path),
    }