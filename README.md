# Court Movie Maker 🎬

ระบบ Automation สร้างวิดีโออัตโนมัติจากรูปภาพ + เสียงเพลง + สคริปต์ พร้อม template ตามอารมณ์งาน

---

## Features

- 🎖️ Template ตามอารมณ์งาน: เกษียณราชการ, วันเกิด, งานเลี้ยงส่ง, ปีใหม่, สงกรานต์
- 🎞️ Transition ระหว่างภาพ: crossfade, slide, wipe, zoom
- ✨ Effect: Ken Burns (pan+zoom), vignette, color grade, text overlay
- 🔊 Audio: fade in/out, ducking, รองรับ TTS ภาษาไทย
- 📁 Export: MP4 (1080p) + MLT project file (เปิดแก้ไขด้วย Kdenlive/Shotcut)
- 🌐 UI: Flutter (Windows, macOS, Linux, Android, iOS)

---

## Requirements

| Software | Version | Download |
|---|---|---|
| Python | 3.11+ | https://python.org |
| FFmpeg | 6.0+ | https://ffmpeg.org/download.html |
| Flutter | 3.22+ | https://flutter.dev |
| Blender (optional) | 4.0+ | https://blender.org |
| Kdenlive (optional) | any | https://kdenlive.org |

---

## Quick Start

### 1. Start Backend

**Windows:**
```bat
run_backend.bat
```

**macOS / Linux:**
```bash
chmod +x run_backend.sh
./run_backend.sh
```

Backend จะเปิดที่ `http://localhost:8000`  
API docs: `http://localhost:8000/docs`

### 2. Run Flutter App

```bash
cd flutter_app
flutter pub get
flutter run
```

เลือก platform: Windows / macOS / Linux / Chrome / Android / iOS

---

## Project Structure

```
court_movie_maker/
├── backend/
│   ├── main.py                 # FastAPI entry point
│   ├── requirements.txt
│   ├── core/
│   │   ├── ffmpeg_engine.py    # FFmpeg pipeline builder
│   │   ├── mlt_exporter.py     # MLT/Kdenlive project exporter
│   │   ├── tts_engine.py       # Text-to-Speech (Thai + EN)
│   │   ├── blender_engine.py   # Optional Blender render
│   │   └── template_manager.py # Template loader
│   ├── routers/
│   │   ├── project.py          # Project CRUD + file upload
│   │   ├── render.py           # Render job management
│   │   └── templates.py        # Template listing
│   └── templates/              # JSON template configs
│       ├── retirement.json
│       ├── birthday.json
│       ├── farewell.json
│       ├── newyear.json
│       └── songkran.json
│
├── flutter_app/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   ├── services/
│   │   ├── providers/
│   │   ├── screens/
│   │   └── widgets/
│   └── pubspec.yaml
│
├── assets/
│   ├── overlays/   # PNG overlay sequences (sparkle, firework, splash)
│   ├── fonts/      # Thai fonts (Sarabun, Prompt)
│   └── luts/       # Color grade LUT files
│
├── run_backend.bat  # Windows launcher
├── run_backend.sh   # macOS/Linux launcher
└── README.md
```

---

## Architecture

```
Flutter UI  ──REST/WebSocket──▶  FastAPI Backend
                                       │
                          ┌────────────┼────────────┐
                          ▼            ▼             ▼
                     FFmpeg        MLT XML      Blender
                    (render)     (project)    (optional)
                          │
                          ▼
                    MP4 + .mlt output
```

---

## Templates

| ID | ชื่อ | Transition | Effect |
|---|---|---|---|
| `retirement` | เกษียณราชการ | crossfade | Ken Burns zoom-out |
| `birthday` | วันเกิด | push slide | Sparkle overlay |
| `farewell` | งานเลี้ยงส่ง | wipe diagonal | Bokeh |
| `newyear` | ปีใหม่ | glitter | Firework overlay |
| `songkran` | สงกรานต์ | zoom | Splash overlay |

---

## Output Files

- **`output.mp4`** — วิดีโอสำเร็จรูป H.264 1080p
- **`project.mlt`** — MLT project file เปิดแก้ไขด้วย Kdenlive หรือ Shotcut

---

## Editing Output in Kdenlive

1. ดาวน์โหลด [Kdenlive](https://kdenlive.org) (ฟรี)
2. เปิดไฟล์ `project.mlt`
3. แก้ไข timeline, เพิ่ม effect, render ใหม่ได้

---

## Environment Variables (Backend)

| Variable | Default | Description |
|---|---|---|
| `THAI_FONT_PATH` | `/usr/share/fonts/truetype/thai/Sarabun-Regular.ttf` | Path to Thai font |
| `BLENDER_PATH` | `blender` | Path to Blender executable |
| `MAX_RENDER_JOBS` | `3` | Max concurrent render jobs |
| `UPLOAD_DIR` | `uploads/` | Upload directory |
| `OUTPUT_DIR` | `outputs/` | Output directory |

---

## License

MIT — ใช้เพื่อการศึกษาและงานส่วนตัวได้เลย
