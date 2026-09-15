import bpy
import math

# ────────────────────────────────────────────────────
# 1. ล้าง Scene และตั้งค่าระบบ 3D
# ────────────────────────────────────────────────────
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

scene.render.resolution_x = 1920
scene.render.resolution_y = 1080
scene.render.resolution_percentage = 100
scene.render.fps = 25
if hasattr(scene.render.image_settings, "media_type"):
    scene.render.image_settings.media_type = "VIDEO"
scene.render.image_settings.file_format = "FFMPEG"
scene.render.ffmpeg.format = "MPEG4"
scene.render.ffmpeg.codec = "H264"
scene.render.ffmpeg.audio_codec = "AAC"
scene.render.ffmpeg.audio_bitrate = 192
scene.render.ffmpeg.video_bitrate = 9000
scene.render.filepath = r"D:\\keaapp\\court_movie_maker\\backend\\temp\\test_quick.mp4"
scene.frame_start = 1
scene.frame_end = 75

# พยายามใช้ EEVEE เพื่อความสมจริงของ 3D Lighting และ Depth
try:
    if "BLENDER_EEVEE_NEXT" in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    elif "BLENDER_EEVEE" in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items:
        scene.render.engine = "BLENDER_EEVEE"
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
    bg_node.inputs["Color"].default_value = (0.0153, 0.0253, 0.0931, 1.0)
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
fill_light_data.color = (0.788, 0.659, 0.298)
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
images = [r"D:\\keaapp\\court_movie_maker\\backend\\uploads\\3372a743-fa2c-46ec-9fde-a630e88fa185\\images\\0038969238634036be5d041d6977897f.jpg", r"D:\\keaapp\\court_movie_maker\\backend\\uploads\\3372a743-fa2c-46ec-9fde-a630e88fa185\\images\\2d56d6d9f11a4c1cbfa4dd7f02bc80b2.jpg"]
frames_per_image = 25
trans_frames = 12
hold_frames = 13

spacing_x = 14.0  # ระยะห่างการ์ดแต่ละรูปในแนวแกน 3D X

# สร้าง Material ขอบทอง 3D
frame_mat = bpy.data.materials.new(name="GoldFrameMat")
frame_mat.use_nodes = True
frame_bsdf = frame_mat.node_tree.nodes.get("Principled BSDF")
if frame_bsdf:
    frame_bsdf.inputs["Base Color"].default_value = (0.788, 0.659, 0.298, 1.0)
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
    border_obj.name = f"Frame_{i:03d}"
    border_obj.scale = (5.6, 3.35, 1.0)
    border_obj.data.materials.append(frame_mat)

    # 2) รูปภาพ 3D Card (16:9 aspect)
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(pos_x, pos_y, pos_z))
    img_obj = bpy.context.active_object
    img_obj.name = f"PhotoCard_{i:03d}"
    img_obj.scale = (5.333, 3.0, 1.0)

    # Material ของภาพ
    mat = bpy.data.materials.new(name=f"PhotoMat_{i:03d}")
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
        print(f"Error loading image {img_path}: {e}")

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
scene.sequence_editor_create()
seq = scene.sequence_editor.sequences

audio_path = None
script_audio_path = None

# 1) เสียงพื้นหลัง (Background Music)
if audio_path:
    try:
        bg_strip = seq.new_sound(
            name="bg_music",
            filepath=audio_path,
            channel=1,
            frame_start=1,
        )
        bg_strip.volume = 0.6
    except Exception as e:
        print(f"Error adding bg audio: {e}")

# 2) เสียงบรรยายภาษาไทย (Thai TTS Speech)
if script_audio_path:
    try:
        tts_strip = seq.new_sound(
            name="tts_voiceover",
            filepath=script_audio_path,
            channel=2,
            frame_start=int(25 * 0.8),  # เริ่มพูดหลังจากเริ่มวิดีโอ 0.8 วิ
        )
        tts_strip.volume = 1.0
        print("[Blender] เพิ่มเสียงบรรยายภาษาไทย (TTS) บน Channel 2 เรียบร้อย")
    except Exception as e:
        print(f"Error adding TTS audio: {e}")

# ────────────────────────────────────────────────────
# 7. บันทึกไฟล์โปรเจกต์ .blend สำหรับเปิดแก้ไข Manual ได้
# ────────────────────────────────────────────────────
blend_file_path = r"D:\\keaapp\\court_movie_maker\\backend\\temp\\test_quick.blend"
bpy.ops.wm.save_as_mainfile(filepath=blend_file_path)
print(f"[Blender] บันทึก 3D Project File สำเร็จ: {blend_file_path}")

# ────────────────────────────────────────────────────
# 8. Render Animation ออกเป็น MP4
# ────────────────────────────────────────────────────
print("[Blender] เริ่มต้น 3D Rendering...")
bpy.ops.render.render(animation=True)
print("[Blender] Render เสร็จสิ้นสมบูรณ์:", scene.render.filepath)