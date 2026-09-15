import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MediaThumbnail extends StatelessWidget {
  final String path;
  final int order;
  final VoidCallback onDelete;

  const MediaThumbnail({
    super.key,
    required this.path,
    required this.order,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main image
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 110,
            height: 110,
            child: _buildImage(),
          ),
        ),
        // Order badge
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppTheme.primaryNavy.withOpacity(0.9),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              '$order',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        // Delete button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.85),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white, width: 1),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close, size: 13, color: Colors.white),
            ),
          ),
        ),
        // Drag handle
        const Positioned(
          bottom: 4,
          right: 4,
          child: Icon(Icons.drag_indicator, size: 16, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildImage() {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    try {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } catch (_) {
      return _placeholder();
    }
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.primaryNavy.withOpacity(0.15),
      child: const Center(
        child: Icon(Icons.image, size: 32, color: AppTheme.primaryNavy),
      ),
    );
  }
}
