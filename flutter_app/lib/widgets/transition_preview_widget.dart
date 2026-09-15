import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TransitionItem {
  final String id;
  final String nameTh;
  final String nameEn;
  final String description;
  final IconData icon;

  const TransitionItem({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.description,
    required this.icon,
  });
}

const List<TransitionItem> kAvailableTransitions = [
  TransitionItem(
    id: 'crossfade',
    nameTh: 'เฟดละมุน',
    nameEn: 'Crossfade',
    description: 'ภาพแรกค่อยๆ จางซ้อนสลายเข้าสู่ภาพใหม่อย่างนุ่มนวล',
    icon: Icons.auto_awesome,
  ),
  TransitionItem(
    id: 'push_slide',
    nameTh: 'สไลด์ซ้าย',
    nameEn: 'Push Slide (Left)',
    description: 'ภาพใหม่เลื่อนดันภาพเดิมจากขวาไปซ้าย',
    icon: Icons.keyboard_double_arrow_left,
  ),
  TransitionItem(
    id: 'slide',
    nameTh: 'สไลด์ขวา',
    nameEn: 'Slide Right',
    description: 'ภาพใหม่เลื่อนดันภาพเดิมจากซ้ายไปขวา',
    icon: Icons.keyboard_double_arrow_right,
  ),
  TransitionItem(
    id: 'wipe_diagonal',
    nameTh: 'กวาดทแยง',
    nameEn: 'Wipe Diagonal',
    description: 'กวาดเผยภาพใหม่จากมุมบนลงล่างตามแนวทแยง',
    icon: Icons.call_missed_outgoing,
  ),
  TransitionItem(
    id: 'wipe',
    nameTh: 'กวาดลงล่าง',
    nameEn: 'Wipe Down',
    description: 'ม่านภาพใหม่รูดลงมาจากขอบบนอย่างสง่างาม',
    icon: Icons.keyboard_double_arrow_down,
  ),
  TransitionItem(
    id: 'zoom_in',
    nameTh: 'ซูมทะลุภาพ',
    nameEn: 'Zoom In',
    description: 'ซูมขยายทะลุภาพแรกเข้าสู่ภาพใหม่อย่างมีมิติ',
    icon: Icons.zoom_in,
  ),
  TransitionItem(
    id: 'glitter',
    nameTh: 'พิกเซลประกาย',
    nameEn: 'Pixel / Glitter',
    description: 'ภาพแตกตัวเป็นพิกเซลกระจายเผยภาพใหม่อย่างตื่นตา',
    icon: Icons.grain,
  ),
];

/// วิดเจ็ตแสดงแอนิเมชันจำลอง Transition ระหว่างภาพ A และภาพ B แบบเรียลไทม์
class TransitionLiveCanvas extends StatefulWidget {
  final String transitionId;
  final double durationSeconds;
  final String? imagePathA;
  final String? imagePathB;
  final double height;

  const TransitionLiveCanvas({
    super.key,
    required this.transitionId,
    this.durationSeconds = 1.5,
    this.imagePathA,
    this.imagePathB,
    this.height = 180,
  });

  @override
  State<TransitionLiveCanvas> createState() => _TransitionLiveCanvasState();
}

class _TransitionLiveCanvasState extends State<TransitionLiveCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _loopTimer;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.durationSeconds * 1000).toInt()),
    );
    _startAnimationCycle();
  }

  @override
  void didUpdateWidget(TransitionLiveCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.durationSeconds != widget.durationSeconds) {
      _controller.duration =
          Duration(milliseconds: (widget.durationSeconds * 1000).toInt());
    }
    if (oldWidget.transitionId != widget.transitionId) {
      _restartCycle();
    }
  }

  void _startAnimationCycle() {
    if (!mounted) return;
    _controller.reset();
    _controller.forward().then((_) {
      if (!mounted) return;
      // พักที่ภาพ B สักครู่ (1.2 วินาที) แล้ววนกลับภาพ A
      _loopTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted || !_isPlaying) return;
        _controller.reset();
        // พักที่ภาพ A สักครู่ (800ms) แล้วเล่นใหม่
        _loopTimer = Timer(const Duration(milliseconds: 800), () {
          if (!mounted || !_isPlaying) return;
          _startAnimationCycle();
        });
      });
    });
  }

  void _restartCycle() {
    _loopTimer?.cancel();
    _startAnimationCycle();
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildImageCard(String? path, String label, Color color1, Color color2) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http')) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _fallbackCard(label, color1, color2),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _fallbackCard(label, color1, color2),
        );
      }
    }
    return _fallbackCard(label, color1, color2);
  }

  Widget _fallbackCard(String label, Color color1, Color color2) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo, color: Colors.white70, size: 36),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageA = _buildImageCard(
      widget.imagePathA,
      'ภาพที่ 1 (ภาพต้นทาง)',
      const Color(0xFF1A2B5F),
      const Color(0xFFC9A84C),
    );

    final imageB = _buildImageCard(
      widget.imagePathB ?? widget.imagePathA,
      'ภาพที่ 2 (ภาพถัดไป)',
      const Color(0xFF0D9488),
      const Color(0xFF0284C7),
    );

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            // Animated Canvas
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    return Stack(
                      children: _buildTransitionLayers(
                        widget.transitionId,
                        t,
                        w,
                        h,
                        imageA,
                        imageB,
                      ),
                    );
                  },
                );
              },
            ),

            // Top Status Bar
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'ตัวอย่างการเคลื่อนไหวจริง',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Replay / Pause Controls
            Positioned(
              bottom: 8,
              right: 8,
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.replay, color: Colors.white, size: 18),
                      tooltip: 'เริ่มเล่นใหม่',
                      onPressed: _restartCycle,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: const EdgeInsets.all(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTransitionLayers(
    String id,
    double t,
    double w,
    double h,
    Widget imageA,
    Widget imageB,
  ) {
    switch (id) {
      case 'push_slide':
        // Slide Left: A slides to left (-w), B slides in from right (w -> 0)
        return [
          Transform.translate(
            offset: Offset(-t * w, 0),
            child: SizedBox(width: w, height: h, child: imageA),
          ),
          Transform.translate(
            offset: Offset((1.0 - t) * w, 0),
            child: SizedBox(width: w, height: h, child: imageB),
          ),
        ];

      case 'slide':
        // Slide Right: A slides to right (w), B slides in from left (-w -> 0)
        return [
          Transform.translate(
            offset: Offset(t * w, 0),
            child: SizedBox(width: w, height: h, child: imageA),
          ),
          Transform.translate(
            offset: Offset(-(1.0 - t) * w, 0),
            child: SizedBox(width: w, height: h, child: imageB),
          ),
        ];

      case 'wipe_diagonal':
        // Diagonal Wipe uncovering B on top of A
        return [
          SizedBox(width: w, height: h, child: imageA),
          ClipPath(
            clipper: _DiagonalWipeClipper(t),
            child: SizedBox(width: w, height: h, child: imageB),
          ),
        ];

      case 'wipe':
        // Wipe Down: B sweeps down from top
        return [
          SizedBox(width: w, height: h, child: imageA),
          ClipRect(
            clipper: _VerticalWipeClipper(t),
            child: SizedBox(width: w, height: h, child: imageB),
          ),
        ];

      case 'zoom_in':
        // Zoom In: A scales up 1.0 -> 1.4 with fade out, B scales in from 0.6 -> 1.0 with fade in
        return [
          Opacity(
            opacity: (1.0 - t).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 1.0 + (t * 0.4),
              child: SizedBox(width: w, height: h, child: imageA),
            ),
          ),
          Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.7 + (t * 0.3),
              child: SizedBox(width: w, height: h, child: imageB),
            ),
          ),
        ];

      case 'glitter':
        // Pixel/Shimmer Dissolve
        return [
          SizedBox(width: w, height: h, child: imageA),
          Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: SizedBox(width: w, height: h, child: imageB),
          ),
          if (t > 0.05 && t < 0.95)
            Positioned.fill(
              child: CustomPaint(
                painter: _GlitterParticlePainter(t),
              ),
            ),
        ];

      case 'crossfade':
      default:
        // Crossfade Opacity
        return [
          Opacity(
            opacity: (1.0 - t).clamp(0.0, 1.0),
            child: SizedBox(width: w, height: h, child: imageA),
          ),
          Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: SizedBox(width: w, height: h, child: imageB),
          ),
        ];
    }
  }
}

// ─── Custom Clippers for Wipe Transitions ────────────────────────────────────

class _DiagonalWipeClipper extends CustomClipper<Path> {
  final double progress; // 0.0 to 1.0
  _DiagonalWipeClipper(this.progress);

  @override
  Path getClip(Size size) {
    final path = Path();
    // Progress travels from -size.width to size.width * 2
    final offset = (size.width + size.height) * progress;

    path.moveTo(0, 0);
    path.lineTo(offset.clamp(0.0, size.width), 0);
    path.lineTo(
      (offset - size.height).clamp(0.0, size.width),
      size.height,
    );
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _DiagonalWipeClipper oldClipper) =>
      oldClipper.progress != progress;
}

class _VerticalWipeClipper extends CustomClipper<Rect> {
  final double progress;
  _VerticalWipeClipper(this.progress);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width, size.height * progress);
  }

  @override
  bool shouldReclip(covariant _VerticalWipeClipper oldClipper) =>
      oldClipper.progress != progress;
}

class _GlitterParticlePainter extends CustomPainter {
  final double progress;
  _GlitterParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(42);
    final paint = Paint()..color = Colors.white.withOpacity((1.0 - (progress - 0.5).abs() * 2).clamp(0.0, 0.8));
    final count = (progress * 40).toInt();

    for (int i = 0; i < count; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final radius = rand.nextDouble() * 3 + 1;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlitterParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─── Modal Dialog สำหรับปรับ Transition เฉพาะช่วง ─────────────────────────

Future<void> showClipTransitionDialog({
  required BuildContext context,
  required int slotIndex,
  required String imagePathA,
  required String imagePathB,
  required String currentTransition,
  required double durationSeconds,
  required ValueChanged<String> onSelected,
  required ValueChanged<String> onApplyToAll,
}) {
  return showDialog(
    context: context,
    builder: (ctx) {
      String localSelected = currentTransition;
      return StatefulBuilder(
        builder: (context, setState) {
          final item = kAvailableTransitions.firstWhere(
            (t) => t.id == localSelected,
            orElse: () => kAvailableTransitions.first,
          );

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.swap_horiz, color: AppTheme.primaryNavy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Transition ช่วงที่ ${slotIndex + 1} (ภาพ ${slotIndex + 1} ➔ ${slotIndex + 2})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Live Canvas of this specific slot
                    TransitionLiveCanvas(
                      transitionId: localSelected,
                      durationSeconds: durationSeconds,
                      imagePathA: imagePathA,
                      imagePathB: imagePathB,
                      height: 180,
                    ),
                    const SizedBox(height: 14),

                    // Transition Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: kAvailableTransitions.map((t) {
                        final isSel = t.id == localSelected;
                        return ChoiceChip(
                          avatar: Icon(t.icon, size: 14, color: isSel ? Colors.white : AppTheme.primaryNavy),
                          label: Text(t.nameTh, style: const TextStyle(fontSize: 12)),
                          selected: isSel,
                          selectedColor: AppTheme.primaryNavy,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : Colors.black87,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => localSelected = t.id);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // Description
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.nameTh} (${item.nameEn}): ${item.description}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_all, size: 16),
                label: const Text('ใช้กับทุกช่วง'),
                onPressed: () {
                  onApplyToAll(localSelected);
                  Navigator.pop(ctx);
                },
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('ใช้เฉพาะช่วงนี้'),
                onPressed: () {
                  onSelected(localSelected);
                  Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      );
    },
  );
}

// ─── Transition Inline Card (แสดงใน Timeline Preview Screen) ──────────────────

class TransitionSelectorCard extends StatefulWidget {
  final String currentTransition;
  final double durationSeconds;
  final List<String> imagePaths;
  final List<String> clipTransitions;
  final ValueChanged<String> onTransitionChanged;
  final ValueChanged<double> onDurationChanged;
  final void Function(int index, String transition)? onClipTransitionChanged;
  final VoidCallback? onRandomizeAll;
  final ValueChanged<String>? onApplyToAll;

  const TransitionSelectorCard({
    super.key,
    required this.currentTransition,
    required this.durationSeconds,
    required this.imagePaths,
    this.clipTransitions = const [],
    required this.onTransitionChanged,
    required this.onDurationChanged,
    this.onClipTransitionChanged,
    this.onRandomizeAll,
    this.onApplyToAll,
  });

  @override
  State<TransitionSelectorCard> createState() => _TransitionSelectorCardState();
}

class _TransitionSelectorCardState extends State<TransitionSelectorCard> {
  int _selectedSlot = 0; // 0 = slot 0 (image 0 -> 1), etc.

  int get _totalSlots => max(0, widget.imagePaths.length - 1);

  String _getTransitionForSlot(int slot) {
    if (slot < widget.clipTransitions.length) {
      return widget.clipTransitions[slot];
    }
    return widget.currentTransition;
  }

  @override
  Widget build(BuildContext context) {
    final activeTransition = _totalSlots > 0
        ? _getTransitionForSlot(_selectedSlot.clamp(0, max(0, _totalSlots - 1)))
        : widget.currentTransition;

    final selectedItem = kAvailableTransitions.firstWhere(
      (t) => t.id == activeTransition,
      orElse: () => kAvailableTransitions.first,
    );

    final imageA = widget.imagePaths.isNotEmpty
        ? widget.imagePaths[_selectedSlot.clamp(0, max(0, widget.imagePaths.length - 1))]
        : null;
    final imageB = widget.imagePaths.length > 1
        ? widget.imagePaths[(_selectedSlot + 1).clamp(0, widget.imagePaths.length - 1)]
        : imageA;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.primaryNavy.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with Randomize & Apply All buttons
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.transform, color: AppTheme.primaryNavy, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'การเปลี่ยนรูปภาพ (Transition)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        _totalSlots > 1
                            ? 'เลือกรายช่วง (${_totalSlots} ช่วง) หรือสุ่มเอฟเฟกต์ทั้งหมดได้'
                            : 'เลือกเอฟเฟกต์การเปลี่ยนภาพ และชมตัวอย่างจริงได้ทันที',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (widget.onRandomizeAll != null && _totalSlots > 1) ...[
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.casino, size: 16),
                    label: const Text('สุ่มทั้งหมด', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      widget.onRandomizeAll!();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🎲 สุ่ม Transition ให้ทุกช่วงเรียบร้อยแล้ว'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                Chip(
                  avatar: Icon(selectedItem.icon, size: 16, color: Colors.white),
                  label: Text(
                    selectedItem.nameTh,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: AppTheme.primaryNavy,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Interval / Slot selector tabs (if more than 1 slot)
            if (_totalSlots > 1) ...[
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _totalSlots,
                  itemBuilder: (context, slot) {
                    final isSel = slot == _selectedSlot;
                    final slotTrans = _getTransitionForSlot(slot);
                    final slotItem = kAvailableTransitions.firstWhere(
                      (t) => t.id == slotTrans,
                      orElse: () => kAvailableTransitions.first,
                    );

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: Icon(
                          slotItem.icon,
                          size: 13,
                          color: isSel ? Colors.white : AppTheme.primaryNavy,
                        ),
                        label: Text(
                          'ช่วง ${slot + 1} (${slot + 1}➔${slot + 2}): ${slotItem.nameTh}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: isSel,
                        selectedColor: AppTheme.primaryNavy,
                        labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black87),
                        onSelected: (val) {
                          if (val) setState(() => _selectedSlot = slot);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Live Animated Preview of the selected slot's 2 images
            TransitionLiveCanvas(
              key: ValueKey('${activeTransition}_${_selectedSlot}_${widget.durationSeconds}'),
              transitionId: activeTransition,
              durationSeconds: widget.durationSeconds,
              imagePathA: imageA,
              imagePathB: imageB,
              height: 200,
            ),

            const SizedBox(height: 14),

            // Transition Chips / Grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kAvailableTransitions.map((item) {
                final isSelected = item.id == activeTransition;
                return ChoiceChip(
                  avatar: Icon(
                    item.icon,
                    size: 16,
                    color: isSelected ? Colors.white : AppTheme.primaryNavy,
                  ),
                  label: Text(item.nameTh),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryNavy,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12.5,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      if (_totalSlots > 1 && widget.onClipTransitionChanged != null) {
                        widget.onClipTransitionChanged!(_selectedSlot, item.id);
                      } else {
                        widget.onTransitionChanged(item.id);
                      }
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 8),

            // Description & Action Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${selectedItem.nameTh} (${selectedItem.nameEn}): ${selectedItem.description}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                    ),
                  ),
                  if (_totalSlots > 1 && widget.onApplyToAll != null)
                    TextButton.icon(
                      icon: const Icon(Icons.copy_all, size: 14),
                      label: const Text('ใช้กับทุกช่วง', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        widget.onApplyToAll!(activeTransition);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('นำ "${selectedItem.nameTh}" ไปใช้กับทุกช่วงแล้ว'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Duration Slider
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  'ระยะเวลา Transition: ${widget.durationSeconds.toStringAsFixed(1)} วินาที',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Expanded(
                  child: Slider(
                    value: widget.durationSeconds,
                    min: 0.5,
                    max: 3.0,
                    divisions: 10,
                    label: '${widget.durationSeconds.toStringAsFixed(1)}s',
                    onChanged: widget.onDurationChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

