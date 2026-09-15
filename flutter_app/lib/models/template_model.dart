class TemplateModel {
  final String id;
  final String name;
  final String nameTh;
  final String mood;
  final Map<String, String> colors;
  final String transition;
  final String effect;
  final String? overlay;
  final int durationPerImage;
  final String introText;
  final String outroText;

  const TemplateModel({
    required this.id,
    required this.name,
    required this.nameTh,
    required this.mood,
    required this.colors,
    required this.transition,
    required this.effect,
    this.overlay,
    required this.durationPerImage,
    required this.introText,
    required this.outroText,
  });

  factory TemplateModel.fromJson(Map<String, dynamic> json) {
    return TemplateModel(
      id: json['id'] as String,
      name: json['name'] as String,
      nameTh: (json['name_th'] ?? json['name']) as String,
      mood: (json['mood'] ?? 'neutral') as String,
      colors: Map<String, String>.from(
        (json['colors'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()),
            ) ??
            {'primary': '#1A2B5F', 'secondary': '#D4AF37'},
      ),
      transition: (json['transition'] ?? 'fade') as String,
      effect: (json['effect'] ?? 'none') as String,
      overlay: json['overlay'] as String?,
      durationPerImage: (json['duration_per_image'] ?? 3) as int,
      introText: (json['intro_text'] ?? '') as String,
      outroText: (json['outro_text'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'name_th': nameTh,
    'mood': mood,
    'colors': colors,
    'transition': transition,
    'effect': effect,
    'overlay': overlay,
    'duration_per_image': durationPerImage,
    'intro_text': introText,
    'outro_text': outroText,
  };

  static List<TemplateModel> get defaultTemplates => [
    const TemplateModel(
      id: 'champion',
      name: 'Champion',
      nameTh: '🏆 แชมเปียน',
      mood: 'epic',
      colors: {'primary': '#1A2B5F', 'secondary': '#D4AF37'},
      transition: 'fade',
      effect: 'zoom',
      durationPerImage: 3,
      introText: 'เส้นทางสู่ความยิ่งใหญ่',
      outroText: 'แชมเปียนตลอดกาล',
    ),
    const TemplateModel(
      id: 'stadium',
      name: 'Stadium',
      nameTh: '🏟️ สนามกีฬา',
      mood: 'energetic',
      colors: {'primary': '#2D5016', 'secondary': '#90EE90'},
      transition: 'slide',
      effect: 'pan',
      durationPerImage: 2,
      introText: 'ยินดีต้อนรับสู่สนาม',
      outroText: 'ขอบคุณทุกการสนับสนุน',
    ),
    const TemplateModel(
      id: 'highlight',
      name: 'Highlight',
      nameTh: '⚡ ไฮไลท์',
      mood: 'intense',
      colors: {'primary': '#8B0000', 'secondary': '#FF4500'},
      transition: 'wipe',
      effect: 'flash',
      durationPerImage: 2,
      introText: 'ช่วงเวลาสุดยอด',
      outroText: 'ความทรงจำที่ไม่รู้ลืม',
    ),
    const TemplateModel(
      id: 'ceremony',
      name: 'Ceremony',
      nameTh: '🎖️ พิธีมอบรางวัล',
      mood: 'elegant',
      colors: {'primary': '#4A0E8F', 'secondary': '#FFD700'},
      transition: 'dissolve',
      effect: 'glow',
      durationPerImage: 4,
      introText: 'พิธีมอบรางวัล',
      outroText: 'ขอแสดงความยินดี',
    ),
    const TemplateModel(
      id: 'team',
      name: 'Team Spirit',
      nameTh: '👥 ทีมสปิริต',
      mood: 'fun',
      colors: {'primary': '#003366', 'secondary': '#FF6600'},
      transition: 'cube',
      effect: 'bounce',
      durationPerImage: 3,
      introText: 'ทีมเดียวกัน ฝันเดียวกัน',
      outroText: 'ร่วมกันสู่ความสำเร็จ',
    ),
    const TemplateModel(
      id: 'cinematic',
      name: 'Cinematic',
      nameTh: '🎬 ซีนีมาติก',
      mood: 'dramatic',
      colors: {'primary': '#1C1C1C', 'secondary': '#C0C0C0'},
      transition: 'fade',
      effect: 'letterbox',
      durationPerImage: 5,
      introText: 'บันทึกประวัติศาสตร์',
      outroText: 'ตำนานที่ยังคงอยู่',
    ),
  ];
}
