import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/template_model.dart';
import '../theme/app_theme.dart';

class TemplateCard extends StatelessWidget {
  final TemplateModel template;
  final bool isSelected;
  final VoidCallback onTap;

  const TemplateCard({
    super.key,
    required this.template,
    required this.isSelected,
    required this.onTap,
  });

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('0xFF${hex.replaceAll('#', '')}'));
    } catch (_) {
      return AppTheme.primaryNavy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _parseColor(template.colors['primary'] ?? '#1A2B5F');
    final secondaryColor = _parseColor(template.colors['secondary'] ?? '#D4AF37');

    final moodColors = {
      'epic': Colors.deepPurple,
      'energetic': Colors.green,
      'intense': Colors.red,
      'elegant': Colors.amber,
      'fun': Colors.orange,
      'dramatic': Colors.blueGrey,
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        transform: Matrix4.diagonal3Values(isSelected ? 1.03 : 1.0, isSelected ? 1.03 : 1.0, 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGold : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppTheme.primaryGold.withOpacity(0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              // Background gradient
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              // Pattern overlay
              Positioned.fill(
                child: CustomPaint(painter: _CardPatternPainter()),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          template.nameTh.split(' ').first, // emoji
                          style: const TextStyle(fontSize: 36),
                        ),
                        if (isSelected)
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryGold,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: AppTheme.primaryNavy, size: 18),
                          ).animate().scale(begin: const Offset(0.3, 0.3), end: const Offset(1, 1), duration: 250.ms),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      template.nameTh.contains(' ') ? template.nameTh.substring(template.nameTh.indexOf(' ') + 1) : template.nameTh,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (moodColors[template.mood] ?? Colors.grey).withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: (moodColors[template.mood] ?? Colors.grey).withOpacity(0.5)),
                      ),
                      child: Text(
                        template.mood,
                        style: TextStyle(
                          color: moodColors[template.mood] ?? Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Color preview bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 6,
                        child: Row(
                          children: [
                            Expanded(child: Container(color: primaryColor.withOpacity(0.8))),
                            Expanded(child: Container(color: secondaryColor.withOpacity(0.8))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.swap_horiz, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(template.transition, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(width: 10),
                        Icon(Icons.auto_awesome, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(template.effect, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }
}

class _CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.1), size.width * 0.4, paint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.9), size.width * 0.3, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
