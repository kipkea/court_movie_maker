# Assets Directory

## overlays/
วางไฟล์ PNG overlay sequences ที่นี่:
- `sparkle_%04d.png` — sparkle particle animation (สำหรับ template วันเกิด)
- `firework_%04d.png` — firework animation (สำหรับ template ปีใหม่)
- `splash_%04d.png` — water splash animation (สำหรับ template สงกรานต์)
- `petals_%04d.png` — flower petals (สำหรับ template เกษียณ)

PNG sequences ควรมี pre-multiplied alpha channel ขนาด 1920x1080

## fonts/
วาง Thai font files ที่นี่:
- `Sarabun-Regular.ttf`
- `Sarabun-Bold.ttf`
- `Prompt-Regular.ttf`
- `Prompt-Bold.ttf`

ดาวน์โหลด Sarabun ได้จาก: https://fonts.google.com/specimen/Sarabun
ดาวน์โหลด Prompt ได้จาก: https://fonts.google.com/specimen/Prompt

## luts/
วาง LUT files (.cube) สำหรับ color grading:
- `warm_gold.cube` — warm gold tone (เกษียณ, วันเกิด)
- `cool_blue.cube` — cool blue (สงกรานต์)
- `vintage.cube` — vintage tone (งานเลี้ยงส่ง)
- `vivid.cube` — vivid/bright (ปีใหม่)

LUTs ใช้กับ FFmpeg: `lut3d=file=warm_gold.cube`
