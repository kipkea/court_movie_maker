"""
ffmpeg_engine.py - FFmpeg pipeline builder สำหรับ Court Movie Maker
สร้างวิดีโอ slideshow ด้วย Ken Burns effect, transitions, text overlay และ audio mixing
"""

from __future__ import annotations

import logging
import math
import subprocess
import shutil
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

# ────────────────────────────────────────────────────────────────
# ค่าคงที่
# ────────────────────────────────────────────────────────────────
OUTPUT_WIDTH: int = 1920
OUTPUT_HEIGHT: int = 1080
OUTPUT_FRAMERATE: int = 25
OUTPUT_CODEC: str = "libx264"
OUTPUT_PROFILE: str = "high"
OUTPUT_CRF: str = "18"
OUTPUT_PRESET: str = "medium"
AUDIO_CODEC: str = "aac"
AUDIO_BITRATE: str = "192k"

# พาธฟอนต์ภาษาไทย (ค้นหาอัตโนมัติหากไม่กำหนด)
THAI_FONT_CANDIDATES: list[str] = [
    r"C:/Windows/Fonts/Sarabun-Regular.ttf",
    r"C:/Windows/Fonts/THSarabunNew.ttf",
    r"C:/Windows/Fonts/tahoma.ttf",
    r"/usr/share/fonts/truetype/thai/Sarabun-Regular.ttf",
    r"/usr/share/fonts/truetype/thai-scalable/Sarabun-Regular.ttf",
]


def _find_thai_font() -> str:
    """ค้นหาพาธฟอนต์ภาษาไทยที่มีในระบบ"""
    for candidate in THAI_FONT_CANDIDATES:
        if Path(candidate).exists():
            return candidate
    logger.warning("ไม่พบฟอนต์ภาษาไทย ใช้ค่าเริ่มต้น")
    return "tahoma.ttf"


def _escape_drawtext(text: str) -> str:
    """Escape อักขระพิเศษสำหรับ FFmpeg drawtext filter"""
    # ต้อง escape: ' : \ ' [
    text = text.replace("\\", "\\\\")
    text = text.replace("'", "\\'")
    text = text.replace(":", "\\:")
    text = text.replace("[", "\\[")
    text = text.replace("]", "\\]")
    return text


def _build_ken_burns_filter(
    index: int,
    effect: str,
    duration: float,
    fps: int = OUTPUT_FRAMERATE,
) -> str:
    """
    สร้าง FFmpeg zoompan filter สำหรับ Ken Burns effect

    Args:
        index: ลำดับภาพ (ใช้สำหรับคำนวณทิศทาง pan)
        effect: ชื่อ effect เช่น ken_burns_zoom_in, ken_burns_zoom_out, ken_burns_pan_right
        duration: ระยะเวลาแสดงภาพ (วินาที)
        fps: เฟรมต่อวินาที

    Returns:
        str: สตริง filter สำหรับใส่ใน filter_complex
    """
    total_frames = int(duration * fps)
    # ขนาด zoompan ต้องประมวลผลในขนาดใหญ่กว่าแล้ว crop
    iw = OUTPUT_WIDTH
    ih = OUTPUT_HEIGHT

    if effect == "ken_burns_zoom_in":
        zoom_expr = f"'min(zoom+0.0005,1.5)'"
        x_expr = "iw/2-(iw/zoom/2)"
        y_expr = "ih/2-(ih/zoom/2)"
    elif effect == "ken_burns_zoom_out":
        zoom_expr = f"'if(eq(on\\,1)\\,1.5\\,max(zoom-0.0005\\,1.0))'"
        x_expr = "iw/2-(iw/zoom/2)"
        y_expr = "ih/2-(ih/zoom/2)"
    elif effect == "ken_burns_pan_right":
        zoom_expr = "'1.2'"
        x_expr = f"'if(eq(on\\,1)\\,0\\,x+1)'"
        y_expr = "ih/2-(ih/zoom/2)"
    elif effect == "ken_burns_pan_left":
        zoom_expr = "'1.2'"
        x_expr = f"'if(eq(on\\,1)\\,iw/zoom/2\\,x-1)'"
        y_expr = "ih/2-(ih/zoom/2)"
    else:
        # Default: zoom in เบาๆ
        zoom_expr = "'min(zoom+0.0003,1.3)'"
        x_expr = "iw/2-(iw/zoom/2)"
        y_expr = "ih/2-(ih/zoom/2)"

    return (
        f"scale={iw * 2}:{ih * 2},"
        f"zoompan=z={zoom_expr}:x={x_expr}:y={y_expr}"
        f":d={total_frames}:s={iw}x{ih}:fps={fps},"
        f"setsar=1"
    )


def _build_transition_filter(
    transition: str,
    n_clips: int,
    duration: float,
    fade_dur: float,
    fps: int = OUTPUT_FRAMERATE,
) -> list[str]:
    """
    สร้าง xfade / blend transition filter สำหรับทุกช่วงเชื่อมต่อภาพ

    Returns:
        list[str]: รายการ filter segments (ใส่ใน filter_complex)
    """
    segments: list[str] = []

    # xfade transition ที่รองรับ
    XFADE_MAP: dict[str, str] = {
        "crossfade": "fade",
        "push_slide": "slideleft",
        "wipe_diagonal": "wipebl",
        "glitter": "pixelize",
        "zoom_in": "zoomin",
        "slide": "slideright",
        "wipe": "wipetop",
        "default": "fade",
    }

    xfade_name = XFADE_MAP.get(transition, XFADE_MAP["default"])

    for i in range(n_clips - 1):
        offset = (duration - fade_dur) * (i + 1)
        if i == 0:
            in_a = "[v0]"
            in_b = "[v1]"
        else:
            in_a = f"[xf{i-1}]"
            in_b = f"[v{i+1}]"
        out = f"[xf{i}]" if i < n_clips - 2 else "[vout]"
        seg = (
            f"{in_a}{in_b}xfade=transition={xfade_name}"
            f":duration={fade_dur:.2f}:offset={offset:.4f}{out}"
        )
        segments.append(seg)

    return segments


def _build_drawtext_filter(
    text: str,
    font_path: str,
    position: str = "bottom",
    color: str = "white",
    size: int = 48,
    box_color: str = "black@0.5",
    start_time: float = 0.0,
    end_time: float | None = None,
) -> str:
    """
    สร้าง drawtext filter สำหรับ overlay ข้อความ

    Args:
        position: 'bottom', 'top', 'center'
        start_time: เวลาเริ่มแสดงข้อความ (วินาที)
        end_time: เวลาหยุดแสดงข้อความ (None = แสดงตลอด)
    """
    escaped = _escape_drawtext(text)
    font_path_escaped = font_path.replace("\\", "/").replace(":", "\\:")

    if position == "top":
        y_expr = "h*0.08"
    elif position == "center":
        y_expr = "(h-text_h)/2"
    else:  # bottom
        y_expr = "h*0.85"

    enable_expr = f"between(t\\,{start_time:.2f}\\,{end_time:.2f})" if end_time else f"gte(t\\,{start_time:.2f})"

    return (
        f"drawtext=fontfile='{font_path_escaped}'"
        f":text='{escaped}'"
        f":fontcolor={color}"
        f":fontsize={size}"
        f":x=(w-text_w)/2"
        f":y={y_expr}"
        f":box=1"
        f":boxcolor={box_color}"
        f":boxborderw=10"
        f":enable='{enable_expr}'"
    )


def build_slideshow(
    images: list[str | Path],
    audio: str | Path | None,
    template_config: dict[str, Any],
    output_path: str | Path,
    job_id: str = "default",
    script_audio: str | Path | None = None,
    ffmpeg_path: str = "ffmpeg",
) -> str:
    """
    สร้างวิดีโอ slideshow ด้วย FFmpeg

    Args:
        images: รายการพาธรูปภาพ (ตามลำดับ)
        audio: พาธไฟล์เสียงพื้นหลัง (None ถ้าไม่มี)
        template_config: ค่าการตั้งค่าจาก template JSON
        output_path: พาธไฟล์ผลลัพธ์ (.mp4)
        job_id: รหัสงาน สำหรับ log ไฟล์
        script_audio: พาธไฟล์เสียง TTS (None ถ้าไม่มี)
        ffmpeg_path: พาธ ffmpeg executable

    Returns:
        str: พาธของไฟล์วิดีโอที่สร้าง

    Raises:
        FileNotFoundError: เมื่อไม่พบ ffmpeg หรือไฟล์รูปภาพ
        RuntimeError: เมื่อ ffmpeg ทำงานล้มเหลว
    """
    if not shutil.which(ffmpeg_path):
        raise FileNotFoundError(
            f"ไม่พบ ffmpeg ที่ '{ffmpeg_path}' กรุณาติดตั้ง FFmpeg และเพิ่มใน PATH"
        )

    images = [Path(img) for img in images]
    for img in images:
        if not img.exists():
            raise FileNotFoundError(f"ไม่พบไฟล์รูปภาพ: {img}")

    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # อ่านค่าจาก template
    effect: str = template_config.get("effect", "ken_burns_zoom_in")
    transition: str = template_config.get("transition", "crossfade")
    duration: float = float(template_config.get("duration_per_image", 5))
    fade_dur: float = float(template_config.get("fade_duration", 1.5))
    intro_text: str = template_config.get("intro_text", "")
    outro_text: str = template_config.get("outro_text", "")
    bg_volume: float = float(template_config.get("audio_volume", 0.7))

    font_path = _find_thai_font()
    primary_color = template_config.get("colors", {}).get("primary", "#FFFFFF")
    # แปลง hex → ffmpeg color (ตัดสัญลักษณ์ #)
    primary_hex = primary_color.lstrip("#")

    n = len(images)
    fps = OUTPUT_FRAMERATE
    log_path = Path(__file__).parent.parent / "temp" / f"ffmpeg_{job_id}.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)

    logger.info("เริ่มสร้างวิดีโอ: %d ภาพ, duration=%.1fs, transition=%s", n, duration, transition)

    # ────────────────────────────────────────────────────────────
    # สร้าง filter_complex
    # ────────────────────────────────────────────────────────────
    filter_parts: list[str] = []

    # 1) Input video streams: scale + Ken Burns สำหรับแต่ละภาพ
    for i in range(n):
        kb = _build_ken_burns_filter(i, effect, duration + fade_dur, fps)
        filter_parts.append(f"[{i}:v]{kb}[v{i}]")

    # 2) Transition chain
    if n == 1:
        # ภาพเดียว ไม่ต้องทำ transition
        filter_parts.append(f"[v0]copy[vout]")
    else:
        trans_filters = _build_transition_filter(transition, n, duration, fade_dur, fps)
        filter_parts.extend(trans_filters)

    # 3) Text overlay (intro / outro)
    total_video_dur = duration * n
    text_filters: list[str] = []

    if intro_text:
        text_filters.append(
            _build_drawtext_filter(
                intro_text, font_path,
                position="bottom",
                color=f"0x{primary_hex}",
                start_time=0.5,
                end_time=min(4.0, duration),
            )
        )
    if outro_text:
        text_filters.append(
            _build_drawtext_filter(
                outro_text, font_path,
                position="bottom",
                color=f"0x{primary_hex}",
                start_time=max(0.0, total_video_dur - duration),
                end_time=total_video_dur - 0.5,
            )
        )

    if text_filters:
        text_chain = ",".join(text_filters)
        filter_parts.append(f"[vout]{text_chain}[vfinal]")
        video_out_label = "[vfinal]"
    else:
        video_out_label = "[vout]"

    # 4) Audio mixing
    audio_out_label: str = ""
    has_bg = audio is not None and Path(str(audio)).exists()
    has_tts = script_audio is not None and Path(str(script_audio)).exists()

    # ดัชนี input เสียง (ตามหลัง input รูปภาพ)
    audio_input_idx = n

    if has_bg and has_tts:
        bg_idx = audio_input_idx
        tts_idx = audio_input_idx + 1
        filter_parts.append(
            f"[{bg_idx}:a]aloop=loop=-1:size=2e+09,atrim=duration={total_video_dur:.2f},"
            f"volume={bg_volume:.2f},afade=t=out:st={total_video_dur - fade_dur:.2f}:d={fade_dur:.2f}[abg]"
        )
        filter_parts.append(
            f"[{tts_idx}:a]volume=1.0[atts]"
        )
        filter_parts.append(
            f"[abg][atts]amix=inputs=2:duration=longest:dropout_transition=2[aout]"
        )
        audio_out_label = "[aout]"
    elif has_bg:
        bg_idx = audio_input_idx
        filter_parts.append(
            f"[{bg_idx}:a]aloop=loop=-1:size=2e+09,atrim=duration={total_video_dur:.2f},"
            f"volume={bg_volume:.2f},afade=t=in:st=0:d=1,afade=t=out:st={total_video_dur - fade_dur:.2f}:d={fade_dur:.2f}[aout]"
        )
        audio_out_label = "[aout]"
    elif has_tts:
        tts_idx = audio_input_idx
        filter_parts.append(
            f"[{tts_idx}:a]volume=1.0[aout]"
        )
        audio_out_label = "[aout]"

    filter_complex = ";".join(filter_parts)

    # ────────────────────────────────────────────────────────────
    # สร้าง FFmpeg command
    # ────────────────────────────────────────────────────────────
    cmd: list[str] = [ffmpeg_path, "-y"]

    # Input รูปภาพ (อ่านทีละภาพ)
    for img in images:
        cmd += ["-loop", "1", "-t", str(duration + fade_dur), "-i", str(img)]

    # Input เสียง
    if has_bg:
        cmd += ["-i", str(audio)]
    if has_tts:
        cmd += ["-i", str(script_audio)]

    # filter_complex
    cmd += ["-filter_complex", filter_complex]

    # Map output streams
    cmd += ["-map", video_out_label]
    if audio_out_label:
        cmd += ["-map", audio_out_label]

    # Output encoding
    cmd += [
        "-c:v", OUTPUT_CODEC,
        "-profile:v", OUTPUT_PROFILE,
        "-crf", OUTPUT_CRF,
        "-preset", OUTPUT_PRESET,
        "-r", str(fps),
        "-pix_fmt", "yuv420p",
    ]
    if audio_out_label:
        cmd += ["-c:a", AUDIO_CODEC, "-b:a", AUDIO_BITRATE]

    # ตัด video ให้ได้ duration ที่ถูกต้อง
    cmd += ["-t", str(total_video_dur)]
    cmd += ["-movflags", "+faststart"]
    cmd += [str(output_path)]

    logger.debug("FFmpeg command: %s", " ".join(cmd))

    # ────────────────────────────────────────────────────────────
    # รัน FFmpeg
    # ────────────────────────────────────────────────────────────
    with log_path.open("w", encoding="utf-8") as log_file:
        log_file.write(f"Command: {' '.join(cmd)}\n\n")
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        log_file.write(result.stdout or "")

    if result.returncode != 0:
        logger.error("FFmpeg ล้มเหลว (code %d) ดู log: %s", result.returncode, log_path)
        raise RuntimeError(
            f"FFmpeg ล้มเหลว (exit code {result.returncode}) "
            f"ดูรายละเอียดที่ {log_path}"
        )

    logger.info("สร้างวิดีโอสำเร็จ: %s", output_path)
    return str(output_path)