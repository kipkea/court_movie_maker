"""
template_manager.py - จัดการเทมเพลตสำหรับ Court Movie Maker
โหลดและให้บริการข้อมูล template จากไฟล์ JSON ใน backend/templates/
"""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

# ไดเรกทอรีที่เก็บไฟล์ JSON ของเทมเพลต
TEMPLATES_DIR: Path = Path(__file__).parent.parent / "templates"


class TemplateManager:
    """จัดการโหลดและค้นหาเทมเพลตจากไฟล์ JSON"""

    def __init__(self, templates_dir: Path = TEMPLATES_DIR) -> None:
        self.templates_dir = templates_dir
        # แคชเทมเพลตทั้งหมด: {id: template_dict}
        self._cache: dict[str, dict[str, Any]] = {}
        self._loaded: bool = False

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _load_all(self) -> None:
        """โหลดไฟล์ JSON ทั้งหมดจากไดเรกทอรีเทมเพลต"""
        if self._loaded:
            return

        if not self.templates_dir.exists():
            logger.warning("ไดเรกทอรีเทมเพลตไม่พบ: %s", self.templates_dir)
            self._loaded = True
            return

        for json_file in sorted(self.templates_dir.glob("*.json")):
            try:
                with json_file.open(encoding="utf-8") as f:
                    data: dict[str, Any] = json.load(f)

                # ตรวจสอบว่ามี id หรือไม่ ถ้าไม่มีใช้ชื่อไฟล์
                template_id: str = data.get("id", json_file.stem)
                data["id"] = template_id
                self._cache[template_id] = data
                logger.info("โหลดเทมเพลต: %s (%s)", template_id, json_file.name)
            except json.JSONDecodeError as e:
                logger.error("ไม่สามารถแปลง JSON ของ %s: %s", json_file.name, e)
            except OSError as e:
                logger.error("ไม่สามารถเปิดไฟล์ %s: %s", json_file.name, e)

        self._loaded = True
        logger.info("โหลดเทมเพลตทั้งหมด %d รายการ", len(self._cache))

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def list_templates(self) -> list[dict[str, Any]]:
        """คืนรายการเทมเพลตทั้งหมด"""
        self._load_all()
        return list(self._cache.values())

    def get_template(self, template_id: str) -> dict[str, Any] | None:
        """ค้นหาเทมเพลตจาก id คืน None ถ้าไม่พบ"""
        self._load_all()
        return self._cache.get(template_id)

    def reload(self) -> None:
        """บังคับโหลดเทมเพลตใหม่ทั้งหมด (ใช้เมื่อไฟล์ JSON ถูกแก้ไข)"""
        self._loaded = False
        self._cache.clear()
        self._load_all()

    def validate_template(self, template_id: str) -> bool:
        """ตรวจสอบว่า template_id มีอยู่หรือไม่"""
        return self.get_template(template_id) is not None

    def get_default_template(self) -> dict[str, Any]:
        """คืนเทมเพลต default (retirement) หรือเทมเพลตแรกที่พบ"""
        self._load_all()
        if "retirement" in self._cache:
            return self._cache["retirement"]
        if self._cache:
            return next(iter(self._cache.values()))
        # Fallback template เมื่อไม่มีไฟล์ JSON
        return {
            "id": "default",
            "name": "Default",
            "name_th": "ค่าเริ่มต้น",
            "mood": "neutral",
            "colors": {"primary": "#FFFFFF", "secondary": "#000000"},
            "transition": "crossfade",
            "effect": "ken_burns_zoom_in",
            "overlay": None,
            "font": "Sarabun",
            "duration_per_image": 5,
            "intro_text": "",
            "outro_text": "",
            "audio_volume": 0.7,
            "fade_duration": 1.5,
        }


# Singleton instance ใช้งานทั่วทั้งแอป
template_manager = TemplateManager()