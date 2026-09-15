"""
routers/templates.py - API สำหรับจัดการเทมเพลต
GET /templates → รายการเทมเพลตทั้งหมด
GET /templates/{id} → รายละเอียดเทมเพลต
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, HTTPException

from core.template_manager import template_manager

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/templates", tags=["Templates"])


@router.get(
    "",
    summary="รายการเทมเพลตทั้งหมด",
    response_model=list[dict[str, Any]],
)
async def list_templates() -> list[dict[str, Any]]:
    """
    คืนรายการเทมเพลตทั้งหมดที่มีในระบบ
    """
    templates = template_manager.list_templates()
    logger.info("เรียกดูเทมเพลตทั้งหมด: %d รายการ", len(templates))
    return templates


@router.get(
    "/{template_id}",
    summary="รายละเอียดเทมเพลต",
    response_model=dict[str, Any],
)
async def get_template(template_id: str) -> dict[str, Any]:
    """
    คืนรายละเอียดเทมเพลตตาม ID

    - **template_id**: รหัสเทมเพลต เช่น retirement, birthday
    """
    template = template_manager.get_template(template_id)
    if template is None:
        raise HTTPException(
            status_code=404,
            detail=f"ไม่พบเทมเพลต ID: {template_id}"
        )
    logger.info("เรียกดูเทมเพลต: %s", template_id)
    return template