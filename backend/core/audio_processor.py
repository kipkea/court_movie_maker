"""
audio_processor.py - Multi-track Audio Processing Engine สำหรับ Court Movie Maker
รองรับการตัดช่วงเพลง (Trim), ปรับระดับเสียง (Volume), Fade In / Fade Out,
และการต่อเพลงด้วย Crossfade อย่างนุ่มนวล
"""

from __future__ import annotations

import json
import logging
import math
import subprocess
from pathlib import Path
from typing import Any

from core.ffmpeg_engine import find_ffmpeg_binary

logger = logging.getLogger(__name__)


def get_audio_duration(audio_path: str | Path) -> float:
    """ดึงความยาวของไฟล์เสียงเป็นวินาทีโดยใช้ ffprobe/ffmpeg"""
    audio_path = Path(audio_path)
    if not audio_path.exists():
        return 0.0

    ffmpeg_bin = find_ffmpeg_binary()
    ffprobe_bin = str(Path(ffmpeg_bin).parent / "ffprobe.exe")
    if not Path(ffprobe_bin).is_file():
        ffprobe_bin = "ffprobe"

    try:
        cmd = [
            ffprobe_bin,
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "json",
            str(audio_path.resolve()),
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        data = json.loads(result.stdout)
        dur = float(data.get("format", {}).get("duration", 0.0))
        if dur > 0:
            return dur
    except Exception as e:
        logger.debug("ไม่สามารถอ่านความยาวไฟล์เสียงด้วย ffprobe (%s): %s", audio_path.name, e)

    # Fallback โดยใช้ ffmpeg อ่านข้อมูล
    try:
        cmd = [ffmpeg_bin, "-i", str(audio_path.resolve())]
        res = subprocess.run(cmd, capture_output=True, text=True)
        for line in res.stderr.splitlines():
            if "Duration:" in line:
                dur_str = line.split("Duration:")[1].split(",")[0].strip()
                h, m, s = dur_str.split(":")
                return float(h) * 3600 + float(m) * 60 + float(s)
    except Exception as e:
        logger.error("ไม่สามารถหาความยาวไฟล์เสียง: %s", e)

    return 0.0


def process_audio_tracks(
    tracks: list[dict[str, Any]],
    output_path: str | Path,
    target_total_duration: float | None = None,
    ffmpeg_path: str = "ffmpeg",
) -> str:
    """
    ประมวลผลแทร็กเสียงหลายรายการ ตัดช่วง ปรับความดัง ใส่ fade in/out
    และเชื่อมต่อเพลงด้วย acrossfade หรือ concat

    Args:
        tracks: รายการ dictionary ของแต่ละแทร็ก:
            - path: พาธไฟล์เสียง (str หรือ Path)
            - start_trim: วินาทีที่เริ่มตัด (ค่าเริ่มต้น 0.0)
            - end_trim: วินาทีที่สิ้นสุด (None = จนจบเพลง)
            - volume: ระดับเสียง (0.0 ถึง 2.0, ค่าเริ่มต้น 1.0)
            - fade_in: วินาที fade in (ค่าเริ่มต้น 1.0)
            - fade_out: วินาที fade out / crossfade (ค่าเริ่มต้น 1.5)
        output_path: พาธไฟล์ผลลัพธ์ (.mp3 หรือ .wav)
        target_total_duration: ความยาวเป้าหมาย (หากต้องการตัด/Loop ให้พอดี)
        ffmpeg_path: พาธ ffmpeg executable

    Returns:
        str: พาธไฟล์เสียงที่ประมวลผลเสร็จแล้ว
    """
    ffmpeg_bin = find_ffmpeg_binary(ffmpeg_path)
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # กรองเฉพาะแทร็กที่มีไฟล์จริง
    valid_tracks: list[dict[str, Any]] = []
    for t in tracks:
        p = Path(str(t.get("path", "")))
        if p.is_file() and p.stat().st_size > 0:
            track_copy = dict(t)
            track_copy["path"] = p
            valid_tracks.append(track_copy)

    if not valid_tracks:
        raise ValueError("ไม่มีไฟล์เสียงที่ถูกต้องสำหรับประมวลผล")

    # กรณีมีเพลงเดียว
    if len(valid_tracks) == 1:
        t = valid_tracks[0]
        p = t["path"]
        start_trim = max(0.0, float(t.get("start_trim", 0.0)))
        end_trim = t.get("end_trim")
        volume = max(0.0, float(t.get("volume", 1.0)))
        fade_in = max(0.0, float(t.get("fade_in", 1.0)))
        fade_out = max(0.0, float(t.get("fade_out", 1.5)))

        total_dur = get_audio_duration(p)
        actual_end = float(end_trim) if end_trim is not None and float(end_trim) > start_trim else total_dur
        seg_dur = max(0.5, actual_end - start_trim)

        fade_in = min(fade_in, seg_dur * 0.4)
        fade_out = min(fade_out, seg_dur * 0.4)

        filters: list[str] = [
            f"atrim=start={start_trim:.2f}:end={actual_end:.2f}",
            "asetpts=PTS-STARTPTS",
            f"volume={volume:.2f}",
        ]
        if fade_in > 0:
            filters.append(f"afade=t=in:st=0:d={fade_in:.2f}")
        if fade_out > 0:
            fade_out_st = max(0.0, seg_dur - fade_out)
            filters.append(f"afade=t=out:st={fade_out_st:.2f}:d={fade_out:.2f}")

        filter_str = ",".join(filters)

        cmd = [
            ffmpeg_bin, "-y",
            "-i", str(p.resolve()),
            "-af", filter_str,
            "-c:a", "libmp3lame" if output_path.suffix.lower() == ".mp3" else "pcm_s16le",
            "-b:a", "192k",
            str(output_path.resolve()),
        ]

        logger.info("FFmpeg ประมวลผลเพลงเดี่ยว: %s", output_path.name)
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            logger.error("FFmpeg audio processing failed: %s", res.stderr)
            raise RuntimeError(f"การตัดแต่งเสียงล้มเหลว: {res.stderr}")

        return str(output_path)

    # กรณีมีหลายเพลง: ทำการ Trim + Volume + Fade + Crossfade
    input_args: list[str] = []
    filter_parts: list[str] = []

    for i, t in enumerate(valid_tracks):
        p = t["path"]
        input_args.extend(["-i", str(p.resolve())])

        start_trim = max(0.0, float(t.get("start_trim", 0.0)))
        end_trim = t.get("end_trim")
        volume = max(0.0, float(t.get("volume", 1.0)))
        fade_in = max(0.0, float(t.get("fade_in", 1.0)))
        fade_out = max(0.0, float(t.get("fade_out", 1.5)))

        total_dur = get_audio_duration(p)
        actual_end = float(end_trim) if end_trim is not None and float(end_trim) > start_trim else total_dur
        seg_dur = max(0.5, actual_end - start_trim)

        t["_seg_dur"] = seg_dur
        t["_fade_out"] = fade_out

        seg_filters: list[str] = [
            f"atrim=start={start_trim:.2f}:end={actual_end:.2f}",
            "asetpts=PTS-STARTPTS",
            f"volume={volume:.2f}",
        ]
        # Fade In เพลงแรก
        if i == 0 and fade_in > 0:
            fade_in = min(fade_in, seg_dur * 0.4)
            seg_filters.append(f"afade=t=in:st=0:d={fade_in:.2f}")

        filter_parts.append(f"[{i}:a]" + ",".join(seg_filters) + f"[t{i}]")

    # เชื่อมต่อเพลง (Acrossfade)
    current_label = "[t0]"
    for i in range(1, len(valid_tracks)):
        prev_track = valid_tracks[i - 1]
        curr_track = valid_tracks[i]
        fade_dur = max(0.5, float(prev_track.get("fade_out", 1.5)))
        fade_dur = min(fade_dur, prev_track["_seg_dur"] * 0.4, curr_track["_seg_dur"] * 0.4)
        fade_dur = max(0.2, fade_dur)

        next_label = f"[m{i}]" if i < len(valid_tracks) - 1 else "[mfinal]"
        filter_parts.append(
            f"{current_label}[t{i}]acrossfade=d={fade_dur:.2f}:c1=tri:c2=tri{next_label}"
        )
        current_label = next_label

    filter_complex = ";".join(filter_parts)

    cmd = [
        ffmpeg_bin, "-y",
        *input_args,
        "-filter_complex", filter_complex,
        "-map", current_label,
        "-c:a", "libmp3lame" if output_path.suffix.lower() == ".mp3" else "pcm_s16le",
        "-b:a", "192k",
        str(output_path.resolve()),
    ]

    logger.info("FFmpeg รวมและตัดต่อหลายเพลง (%d แทร็ก) -> %s", len(valid_tracks), output_path.name)
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        logger.error("FFmpeg multi-audio processing failed: %s", res.stderr)
        raise RuntimeError(f"การรวมเสียงล้มเหลว: {res.stderr}")

    return str(output_path)
