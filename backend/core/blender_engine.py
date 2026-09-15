"""
blender_engine.py - 3D Video & Scene Render Engine ด้วย Blender
สร้างภาพเคลื่อนไหว 3D Cinematic Parallax / Camera Dolly พร้อม Export .blend และ Render MP4
รองรับการ Mix เพลงพื้นหลังและเสียงบรรยายภาษาไทย (TTS)
"""

from __future__ import annotations

import glob
import logging
import os
import shutil
import subprocess
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

# ────────────────────────────────────────────────────────────────
# ค่าคงที่สำหรับ Blender
# ────────────────────────────────────────────────────────────────
BLENDER_FPS: int = 25
BLENDER_WIDTH: int = 1920
BLENDER_HEIGHT: int = 1080
BLENDER_OUTPUT_FORMAT: str = "FFMPEG"
BLENDER_FFMPEG_FORMAT: str = "MPEG4"
BLENDER_FFMPEG_CODEC: str = "H264"
BLENDER_AUDIO_CODEC: str = "AAC"


def find_blender_binary(custom_path: str = "blender") -> str | None:
    """
    ค้นหา Blender executable ในระบบ Windows หรือ PATH
    """
    # 1. ตรวจสอบ path ที่ระบุมา
    if custom_path and custom_path != "blender":
        p = Path(custom_path)
        if p.is_file():
            return str(p.resolve())

    # 2. ตรวจสอบใน PATH
    which_path = shutil.which("blender")
    if which_path:
        return which_path

    # 3. ตรวจสอบพาธมาตรฐานใน Windows
    win_candidates = [
        r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 4.1\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 4.0\blender.exe",
    ]
    for cand in win_candidates:
        if os.path.isfile(cand):
            return cand

    # 4. ค้นหาแบบ glob ใน Program Files
    glob_candidates = glob.glob(r"C:\Program Files\Blender Foundation\*\blender.exe")
    if glob_candidates:
        return sorted(glob_candidates, reverse=True)[0]

    return None


def _generate_3d_blender_script(
    images: list[Path],
    audio: Path | None,
    script_audio: Path | None,
    template_config: dict[str, Any],
    output_path: Path,
    blend_path: Path,
) -> str:
    """
    สร้าง Python script สำหรับ Blender 3D Scene + Camera Animation + VSE Audio
    """
    duration_per_image: float = float(template_config.get("duration_per_image", 4.5))
    transition_duration: float = float(template_config.get("fade_duration", 1.2))
    fps = BLENDER_FPS

    frames_per_image = int(duration_per_image * fps)
    trans_frames = int(transition_duration * fps)
    hold_frames = max(10, frames_per_image - trans_frames)
    total_frames = frames_per_image * len(images) + fps  # เผื่อ 1 วิ ตอนท้าย

    def p(path: Path | None) -> str:
        if path is None:
            return "None"
        return str(path.resolve()).replace("\\", "\\\\")

    img_list_str = "[" + ", ".join(f'r"{p(img)}"' for img in images) + "]"
    audio_str = f'r"{p(audio)}"' if audio and audio.exists() else "None"
    script_audio_str = f'r"{p(script_audio)}"' if script_audio and script_audio.exists() else "None"

    # อ่านสี Template
    primary_color = template_config.get("colors", {}).get("primary", "#C9A84C")
    secondary_color = template_config.get("colors", {}).get("secondary", "#1A2B5F")

    # แปลง Hex Color เป็น RGBA (0.0 - 1.0)
    def hex_to_rgb(hex_str: str) -> tuple[float, float, float]:
        hex_str = hex_str.lstrip("#")
        if len(hex_str) == 6:
            r = int(hex_str[0:2], 16) / 255.0
            g = int(hex_str[2:4], 16) / 255.0
            b = int(hex_str[4:6], 16) / 255.0
            return (r, g, b)
        return (0.8, 0.65, 0.2)

    bg_rgb = hex_to_rgb(secondary_color)
    frame_rgb = hex_to_rgb(primary_color)
    audio_volume = float(template_config.get("audio_volume", 0.6))

    script = f'''
import bpy
import math

# ────────────────────────────────────────────────────
# 1. ล้าง Scene และตั้งค่าระบบ 3D
# ────────────────────────────────────────────────────
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

scene.render.resolution_x = {BLENDER_WIDTH}
scene.render.resolution_y = {BLENDER_HEIGHT}
scene.render.resolution_percentage = 100
scene.render.fps = {fps}
if hasattr(scene.render.image_settings, "media_type"):
    scene.render.image_settings.media_type = "VIDEO"
scene.render.image_settings.file_format = "{BLENDER_OUTPUT_FORMAT}"
scene.render.ffmpeg.format = "{BLENDER_FFMPEG_FORMAT}"
scene.render.ffmpeg.codec = "{BLENDER_FFMPEG_CODEC}"
scene.render.ffmpeg.audio_codec = "{BLENDER_AUDIO_CODEC}"
scene.render.ffmpeg.audio_bitrate = 192
scene.render.ffmpeg.video_bitrate = 9000
scene.render.filepath = r"{p(output_path)}"
scene.frame_start = 1
scene.frame_end = {total_frames}

# พยายามใช้ EEVEE เพื่อความสมจริงของ 3D Lighting และ Depth พร้อมปรับ samples เพื่อความเร็ว
try:
    if "BLENDER_EEVEE_NEXT" in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    elif "BLENDER_EEVEE" in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items:
        scene.render.engine = "BLENDER_EEVEE"
    if hasattr(scene, "eevee"):
        if hasattr(scene.eevee, "taa_render_samples"):
            scene.eevee.taa_render_samples = 16
        if hasattr(scene.eevee, "use_raytracing"):
            scene.eevee.use_raytracing = False
except Exception:
    pass

# ────────────────────────────────────────────────────
# 2. ตั้งค่า World Background และ 3D Lighting
# ────────────────────────────────────────────────────
world = bpy.data.worlds.new("CourtWorld")
world.use_nodes = True
scene.world = world
bg_node = world.node_tree.nodes.get("Background")
if bg_node:
    # พื้นหลังสีตาม Template ปรับมืดเพื่อขับภาพเด่น
    bg_node.inputs["Color"].default_value = ({bg_rgb[0] * 0.15:.4f}, {bg_rgb[1] * 0.15:.4f}, {bg_rgb[2] * 0.25:.4f}, 1.0)
    bg_node.inputs["Strength"].default_value = 1.0

# แสง Key Light
key_light_data = bpy.data.lights.new(name="KeyLight", type="SUN")
key_light_data.energy = 3.0
key_light_data.color = (1.0, 0.98, 0.92)
key_light_obj = bpy.data.objects.new("KeyLight", key_light_data)
scene.collection.objects.link(key_light_obj)
key_light_obj.rotation_euler = (math.radians(45), math.radians(15), math.radians(30))

# แสง Fill Light สีทองอบอุ่น
fill_light_data = bpy.data.lights.new(name="FillLight", type="POINT")
fill_light_data.energy = 500.0
fill_light_data.color = ({frame_rgb[0]:.3f}, {frame_rgb[1]:.3f}, {frame_rgb[2]:.3f})
fill_light_obj = bpy.data.objects.new("FillLight", fill_light_data)
scene.collection.objects.link(fill_light_obj)
fill_light_obj.location = (0, -3.0, 2.0)

# ────────────────────────────────────────────────────
# 3. สร้าง 3D Camera และ Animate Path
# ────────────────────────────────────────────────────
cam_data = bpy.data.cameras.new("Main3DCamera")
cam_data.lens = 50
cam_data.dof.use_dof = True
cam_data.dof.focus_distance = 6.0
cam_data.dof.aperture_fstop = 2.8

cam_obj = bpy.data.objects.new("Main3DCamera", cam_data)
scene.collection.objects.link(cam_obj)
scene.camera = cam_obj

# ────────────────────────────────────────────────────
# 4. วางรูปภาพใน 3D Space พร้อม 3D Frame และ Material
# ────────────────────────────────────────────────────
images = {img_list_str}
frames_per_image = {frames_per_image}
trans_frames = {trans_frames}
hold_frames = {hold_frames}

spacing_x = 14.0  # ระยะห่างการ์ดแต่ละรูปในแนวแกน 3D X

# สร้าง Material ขอบทอง 3D
frame_mat = bpy.data.materials.new(name="GoldFrameMat")
frame_mat.use_nodes = True
frame_bsdf = frame_mat.node_tree.nodes.get("Principled BSDF")
if frame_bsdf:
    frame_bsdf.inputs["Base Color"].default_value = ({frame_rgb[0]:.3f}, {frame_rgb[1]:.3f}, {frame_rgb[2]:.3f}, 1.0)
    frame_bsdf.inputs["Metallic"].default_value = 0.85
    frame_bsdf.inputs["Roughness"].default_value = 0.25

card_targets = []

for i, img_path in enumerate(images):
    pos_x = i * spacing_x
    pos_y = 0.0
    pos_z = 0.0
    card_targets.append((pos_x, pos_y, pos_z))

    # 1) ขอบกรอบการ์ด 3D Frame
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(pos_x, pos_y + 0.04, pos_z))
    border_obj = bpy.context.active_object
    border_obj.name = f"Frame_{{i:03d}}"
    border_obj.scale = (5.6, 3.35, 1.0)
    border_obj.data.materials.append(frame_mat)

    # 2) รูปภาพ 3D Card (16:9 aspect)
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(pos_x, pos_y, pos_z))
    img_obj = bpy.context.active_object
    img_obj.name = f"PhotoCard_{{i:03d}}"
    img_obj.scale = (5.333, 3.0, 1.0)

    # Material ของภาพ
    mat = bpy.data.materials.new(name=f"PhotoMat_{{i:03d}}")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")

    tex_node = nodes.new("ShaderNodeTexImage")
    try:
        img_tex = bpy.data.images.load(img_path)
        tex_node.image = img_tex
        links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
        # ให้มีความมันเงาเล็กน้อยเหมือนรูปถ่ายจริง
        bsdf.inputs["Roughness"].default_value = 0.15
        bsdf.inputs["Specular IOR Level"].default_value = 0.4
    except Exception as e:
        print(f"Error loading image {{img_path}}: {{e}}")

    img_obj.data.materials.append(mat)

# ────────────────────────────────────────────────────
# 5. Keyframe 3D Camera Movement (Parallax + Dolly + Tilt)
# ────────────────────────────────────────────────────
for i, target in enumerate(card_targets):
    start_frame = i * frames_per_image + 1
    end_hold_frame = start_frame + hold_frames
    end_trans_frame = start_frame + frames_per_image

    tx, ty, tz = target

    # Start: กล้องอยู่ห่างเล็กน้อย + มุมเอียง 3D Parallax เล็กน้อย
    cam_start_loc = (tx - 0.7, ty - 6.2, tz + 0.35)
    cam_start_rot = (math.radians(88), math.radians(-1.5), math.radians(4.0))

    # End Hold: ดอลลี่เข้าใกล้ (3D Dolly-in / Ken Burns 3D)
    cam_mid_loc = (tx + 0.5, ty - 5.4, tz - 0.2)
    cam_mid_rot = (math.radians(91), math.radians(1.2), math.radians(-3.0))

    # Set start keyframe
    cam_obj.location = cam_start_loc
    cam_obj.rotation_euler = cam_start_rot
    cam_obj.keyframe_insert(data_path="location", frame=start_frame)
    cam_obj.keyframe_insert(data_path="rotation_euler", frame=start_frame)

    # Set mid hold keyframe
    cam_obj.location = cam_mid_loc
    cam_obj.rotation_euler = cam_mid_rot
    cam_obj.keyframe_insert(data_path="location", frame=end_hold_frame)
    cam_obj.keyframe_insert(data_path="rotation_euler", frame=end_hold_frame)

    # Transition ไปยังการ์ดถัดไป (3D Fly-through)
    if i < len(card_targets) - 1:
        next_target = card_targets[i + 1]
        nx, ny, nz = next_target
        cam_fly_loc = (nx - 0.7, ny - 6.2, nz + 0.35)
        cam_fly_rot = (math.radians(88), math.radians(-1.5), math.radians(4.0))

        cam_obj.location = cam_fly_loc
        cam_obj.rotation_euler = cam_fly_rot
        cam_obj.keyframe_insert(data_path="location", frame=end_trans_frame)
        cam_obj.keyframe_insert(data_path="rotation_euler", frame=end_trans_frame)

# ปรับ Curve ของการเคลื่อนที่ให้สมูท (รองรับทั้ง Blender 4.x และ Blender 5.x)
try:
    if cam_obj.animation_data and cam_obj.animation_data.action:
        action = cam_obj.animation_data.action
        fcurves = getattr(action, "fcurves", None)
        if fcurves:
            for fcurve in fcurves:
                for kf in fcurve.keyframe_points:
                    kf.interpolation = 'BEZIER'
except Exception:
    pass

# ────────────────────────────────────────────────────
# 6. Audio Mixing ใน Blender VSE (เพลง + เสียงพูด TTS)
# ────────────────────────────────────────────────────
seq_editor = scene.sequence_editor or scene.sequence_editor_create()
seq = getattr(seq_editor, "strips", getattr(seq_editor, "sequences", None))

audio_path = {audio_str}
script_audio_path = {script_audio_str}

if seq is not None:
    # 1) เสียงพื้นหลัง (Background Music)
    if audio_path:
        try:
            bg_strip = seq.new_sound(
                name="bg_music",
                filepath=audio_path,
                channel=1,
                frame_start=1,
            )
            # ถ้ามีเสียงบรรยาย ให้ลดเสียงดนตรีลงเพื่อให้ได้ยินเสียงพูดชัดเจน
            bg_strip.volume = {audio_volume * 0.35 if script_audio else audio_volume:.2f}
        except Exception as e:
            print(f"Error adding bg audio: {{e}}")

    # 2) เสียงบรรยายภาษาไทย (Thai TTS Speech)
    if script_audio_path:
        try:
            tts_strip = seq.new_sound(
                name="tts_voiceover",
                filepath=script_audio_path,
                channel=2,
                frame_start=int({fps} * 0.8),  # เริ่มพูดหลังจากเริ่มวิดีโอ 0.8 วิ
            )
            tts_strip.volume = 1.3
            print("[Blender] เพิ่มเสียงบรรยายภาษาไทย (TTS) บน Channel 2 เรียบร้อย")
        except Exception as e:
            print(f"Error adding TTS audio: {{e}}")

# ────────────────────────────────────────────────────
# 7. บันทึกไฟล์โปรเจกต์ .blend สำหรับเปิดแก้ไข Manual ได้
# ────────────────────────────────────────────────────
blend_file_path = r"{p(blend_path)}"
bpy.ops.wm.save_as_mainfile(filepath=blend_file_path)
print(f"[Blender] บันทึก 3D Project File สำเร็จ: {{blend_file_path}}")

# ────────────────────────────────────────────────────
# 8. Render Animation ออกเป็น MP4
# ────────────────────────────────────────────────────
print("[Blender] เริ่มต้น 3D Rendering...")
bpy.ops.render.render(animation=True)
print("[Blender] Render เสร็จสิ้นสมบูรณ์:", scene.render.filepath)
'''
    return script.strip()


def render_with_blender(
    images: list[str | Path],
    template_config: dict[str, Any],
    output_path: str | Path,
    audio: str | Path | None = None,
    script_audio: str | Path | None = None,
    job_id: str = "default",
    blender_path: str = "blender",
) -> dict[str, str]:
    """
    เรนเดอร์วิดีโอ 3D ด้วย Blender พร้อมบันทึก .blend project file

    Args:
        images: รายการพาธรูปภาพ
        template_config: ค่าการตั้งค่า template
        output_path: พาธ output วิดีโอ (.mp4)
        audio: พาธไฟล์เสียงพื้นหลัง
        script_audio: พาธไฟล์เสียงพูดบรรยาย TTS
        job_id: รหัสงาน
        blender_path: พาธ blender executable

    Returns:
        dict[str, str]: {'mp4': output_mp4, 'blend': blend_file}
    """
    resolved_blender = find_blender_binary(blender_path)
    if not resolved_blender:
        raise FileNotFoundError(
            f"ไม่พบ Blender ในระบบ (ระบุ: '{blender_path}') "
            "กรุณาติดตั้ง Blender จาก https://blender.org หรือระบุพาธให้ถูกต้อง"
        )

    images_path = [Path(img) for img in images]
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    blend_output = output_path.parent / "project.blend"
    audio_path = Path(str(audio)) if audio else None
    script_audio_path = Path(str(script_audio)) if script_audio else None

    # สร้าง Python script สำหรับ Blender
    script_content = _generate_3d_blender_script(
        images=images_path,
        audio=audio_path,
        script_audio=script_audio_path,
        template_config=template_config,
        output_path=output_path,
        blend_path=blend_output,
    )

    temp_dir = Path(__file__).parent.parent / "temp"
    temp_dir.mkdir(parents=True, exist_ok=True)
    script_path = temp_dir / f"blender_3d_{job_id}.py"
    script_path.write_text(script_content, encoding="utf-8")

    log_path = temp_dir / f"blender_{job_id}.log"

    logger.info("รัน Blender 3D render ด้วย: %s", resolved_blender)
    logger.debug("Blender script: %s", script_path)

    cmd = [
        resolved_blender,
        "--background",
        "--python", str(script_path),
    ]

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

    stdout_text = result.stdout or ""
    has_traceback = "Traceback (most recent call last):" in stdout_text

    if result.returncode != 0 or has_traceback:
        logger.error("Blender ล้มเหลว (code %d) ดู log: %s", result.returncode, log_path)
        err_detail = ""
        if has_traceback:
            err_lines = [
                line.strip()
                for line in stdout_text.splitlines()
                if line.strip().startswith(("Error:", "AttributeError:", "TypeError:", "ValueError:", "RuntimeError:", "Exception:"))
            ]
            if err_lines:
                err_detail = f": {err_lines[-1]}"
        raise RuntimeError(
            f"Blender 3D render ล้มเหลว{err_detail} (exit code {result.returncode}) "
            f"ดูรายละเอียดที่ {log_path}"
        )

    # ตรวจสอบไฟล์ผลลัพธ์
    actual_mp4 = output_path
    if not output_path.exists():
        candidates = list(output_path.parent.glob(f"{output_path.stem}*.mp4"))
        if candidates:
            cand = sorted(candidates)[-1]
            try:
                shutil.copy2(cand, output_path)
                actual_mp4 = output_path
            except Exception:
                actual_mp4 = cand
        else:
            raise RuntimeError(f"Blender render สำเร็จแต่ไม่พบไฟล์ output: {output_path}")

    res = {"mp4": str(actual_mp4)}
    if blend_output.exists():
        res["blend"] = str(blend_output)

    logger.info("Blender 3D render สำเร็จ: %s (พร้อม project.blend: %s)", actual_mp4, blend_output.exists())
    return res