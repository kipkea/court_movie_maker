"""
tts_engine.py - Text-to-Speech ด้วย edge-tts สำหรับ Court Movie Maker
รองรับเสียงภาษาไทยและภาษาอังกฤษ พร้อม fallback เมื่อเกิดข้อผิดพลาด
"""

from __future__ import annotations

import asyncio
import logging
import struct
import wave
from pathlib import Path

logger = logging.getLogger(__name__)

# เสียงภาษาไทยที่รองรับ
THAI_VOICES: dict[str, str] = {
    "male": "th-TH-NiwatNeural",
    "female": "th-TH-PremwadeeNeural",
}

# เสียงภาษาอังกฤษ fallback
ENGLISH_VOICES: dict[str, str] = {
    "male": "en-US-GuyNeural",
    "female": "en-US-JennyNeural",
}


def _create_silent_wav(output_path: Path, duration_seconds: float = 3.0) -> None:
    """สร้างไฟล์ WAV เงียบเมื่อ TTS ล้มเหลว"""
    sample_rate = 44100
    num_channels = 1
    sampwidth = 2  # 16-bit
    num_frames = int(sample_rate * duration_seconds)
    silence = b"\x00\x00" * num_frames

    with wave.open(str(output_path), "w") as wf:
        wf.setnchannels(num_channels)
        wf.setsampwidth(sampwidth)
        wf.setframerate(sample_rate)
        wf.writeframes(silence)

    logger.info("สร้างไฟล์เสียงเงียบ: %s (%.1f วินาที)", output_path.name, duration_seconds)


async def text_to_speech(
    text: str,
    lang: str = "th",
    output_path: str | Path = "output.mp3",
    gender: str = "female",
    rate: str = "+0%",
    volume: str = "+0%",
) -> str:
    """
    แปลงข้อความเป็นเสียงพูด ด้วย edge-tts

    Args:
        text: ข้อความที่ต้องการแปลง
        lang: รหัสภาษา ('th' = ไทย, 'en' = อังกฤษ)
        output_path: พาธสำหรับบันทึกไฟล์เสียง (.mp3)
        gender: เพศเสียง ('male' หรือ 'female')
        rate: ความเร็วพูด (เช่น '+10%', '-20%')
        volume: ระดับเสียง (เช่น '+0%', '+10%')

    Returns:
        str: พาธของไฟล์เสียงที่สร้าง
    """
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # เลือกเสียงตามภาษาและเพศ
    if lang == "th":
        voice = THAI_VOICES.get(gender, THAI_VOICES["female"])
    else:
        voice = ENGLISH_VOICES.get(gender, ENGLISH_VOICES["female"])

    logger.info("เริ่มสร้างเสียงพูด: เสียง=%s, ข้อความ=%d ตัวอักษร", voice, len(text))

    try:
        import edge_tts  # type: ignore[import]

        communicate = edge_tts.Communicate(
            text=text,
            voice=voice,
            rate=rate,
            volume=volume,
        )

        await communicate.save(str(output_path))

        if not output_path.exists() or output_path.stat().st_size == 0:
            if output_path.exists():
                output_path.unlink(missing_ok=True)
            raise RuntimeError("ไฟล์เสียงที่สร้างมีขนาดเป็นศูนย์")

        logger.info("สร้างเสียงพูดสำเร็จ: %s (%.1f KB)", output_path.name, output_path.stat().st_size / 1024)
        return str(output_path)

    except ImportError:
        logger.error("ไม่พบ edge-tts ติดตั้งด้วย: pip install edge-tts")
        if output_path.exists() and output_path.stat().st_size == 0:
            output_path.unlink(missing_ok=True)
        # Fallback: สร้างไฟล์เสียงเงียบ WAV
        fallback_path = output_path.with_suffix(".wav")
        _create_silent_wav(fallback_path, duration_seconds=max(3.0, len(text) * 0.1))
        return str(fallback_path)

    except Exception as exc:
        logger.error("สร้างเสียงพูดล้มเหลว: %s — ใช้ไฟล์เงียบแทน", exc)
        if output_path.exists() and output_path.stat().st_size == 0:
            output_path.unlink(missing_ok=True)
        # Fallback: สร้างไฟล์เสียงเงียบ WAV
        fallback_path = output_path.with_suffix(".wav")
        _create_silent_wav(fallback_path, duration_seconds=max(3.0, len(text) * 0.1))
        return str(fallback_path)


async def text_to_speech_batch(
    texts: list[str],
    lang: str = "th",
    output_dir: str | Path = ".",
    prefix: str = "tts",
    gender: str = "female",
) -> list[str]:
    """
    แปลงข้อความหลายรายการพร้อมกัน

    Args:
        texts: รายการข้อความ
        lang: รหัสภาษา
        output_dir: ไดเรกทอรีสำหรับบันทึกไฟล์
        prefix: คำนำหน้าชื่อไฟล์
        gender: เพศเสียง

    Returns:
        list[str]: รายการพาธของไฟล์เสียงที่สร้าง
    """
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    tasks = [
        text_to_speech(
            text=text,
            lang=lang,
            output_path=output_dir / f"{prefix}_{i:03d}.mp3",
            gender=gender,
        )
        for i, text in enumerate(texts)
    ]

    return list(await asyncio.gather(*tasks))