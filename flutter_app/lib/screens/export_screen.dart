import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_providers.dart';
import '../models/project_model.dart';
import '../theme/app_theme.dart';

class ExportScreen extends ConsumerWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final renderJob = ref.watch(renderJobProvider);
    final job = renderJob.job;
    final isSuccess = job?.status == RenderStatus.completed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ผลลัพธ์ Render'),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: 1.0, backgroundColor: Colors.white24, color: AppTheme.primaryGold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success / Error animation
            _StatusBanner(isSuccess: isSuccess, job: job),
            const SizedBox(height: 32),

            if (isSuccess && job != null && job.outputFiles.isNotEmpty) ...[
              Text('ไฟล์ผลลัพธ์', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...job.outputFiles.map((filePath) => _FileCard(
                    filePath: filePath,
                    key: ValueKey(filePath),
                  )),
              const SizedBox(height: 24),
              _ActionButtons(outputFiles: job.outputFiles, ref: ref, context: context),
            ] else if (!isSuccess && job != null) ...[
              _ErrorDetails(job: job),
            ],

            const SizedBox(height: 32),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('สร้างวิดีโอใหม่', style: TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
              ),
              onPressed: () {
                ref.read(projectProvider.notifier).reset();
                ref.read(renderJobProvider.notifier).reset();
                ref.read(selectedTemplateProvider.notifier).state = null;
                context.go('/');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool isSuccess;
  final RenderJob? job;

  const _StatusBanner({required this.isSuccess, required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSuccess
              ? [const Color(0xFF1B5E20), const Color(0xFF4CAF50)]
              : [const Color(0xFFB71C1C), const Color(0xFFEF5350)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              size: 48,
              color: Colors.white,
            ),
          )
              .animate()
              .scale(begin: const Offset(0.3, 0.3), end: const Offset(1, 1), duration: 600.ms, curve: Curves.elasticOut)
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 16),
          Text(
            isSuccess ? '🎉 Render สำเร็จ!' : '❌ Render ล้มเหลว',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
          ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
          if (isSuccess)
            const Text('วิดีโอของคุณพร้อมแล้ว', style: TextStyle(color: Colors.white70, fontSize: 14))
                .animate()
                .fadeIn(delay: 500.ms, duration: 500.ms),
        ],
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final String filePath;
  const _FileCard({required this.filePath, super.key});

  String get _filename => filePath.replaceAll('\\', '/').split('/').last;
  String get _extension => _filename.split('.').last.toUpperCase();
  bool get _isVideo => ['MP4', 'AVI', 'MOV', 'MKV'].contains(_extension);
  bool get _isMlt => ['MLT', 'KDENLIVE'].contains(_extension);
  bool get _isBlend => _extension == 'BLEND';

  Color get _typeColor {
    if (_isVideo) return Colors.blue;
    if (_extension == 'KDENLIVE') return Colors.teal;
    if (_isMlt) return Colors.purple;
    if (_isBlend) return Colors.orange;
    return Colors.grey;
  }

  IconData get _typeIcon {
    if (_isVideo) return Icons.videocam;
    if (_extension == 'KDENLIVE' || _isMlt) return Icons.video_library;
    if (_isBlend) return Icons.view_in_ar;
    return Icons.insert_drive_file;
  }

  String get _chipLabel {
    if (_isBlend) return '3D BLEND';
    if (_extension == 'KDENLIVE') return 'KDENLIVE';
    if (_extension == 'MLT') return 'MLT XML';
    return _extension;
  }

  String get _tooltip {
    if (_isBlend) return 'เปิดใน Blender';
    if (_extension == 'KDENLIVE' || _isMlt) return 'เปิดใน Kdenlive';
    if (_isVideo) return 'เปิดเล่นวิดีโอ';
    return 'เปิดไฟล์';
  }

  String _getFileSize() {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (_) {}
    return 'ไม่ทราบขนาด';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _typeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_typeIcon, color: _typeColor, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_filename, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(
                    children: [
                      Chip(
                        label: Text(_chipLabel, style: const TextStyle(fontSize: 10)),
                        backgroundColor: _typeColor.withOpacity(0.1),
                        side: BorderSide(color: _typeColor.withOpacity(0.3)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                      Text(_getFileSize(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: _tooltip,
              onPressed: () async {
                final result = await OpenFile.open(filePath);
                if (result.type != ResultType.done) {
                  if (_extension == 'KDENLIVE' || _isMlt) {
                    const kdenliveExe = r'C:\Program Files\Kdenlive\bin\kdenlive.exe';
                    if (File(kdenliveExe).existsSync()) {
                      await Process.run(kdenliveExe, [filePath]);
                      return;
                    }
                  } else if (_isBlend) {
                    final blenderCandidates = [
                      r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe',
                      r'C:\Program Files\Blender Foundation\Blender 5.0\blender.exe',
                      r'C:\Program Files\Blender Foundation\Blender 4.3\blender.exe',
                    ];
                    for (final b in blenderCandidates) {
                      if (File(b).existsSync()) {
                        await Process.run(b, [filePath]);
                        return;
                      }
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }
}

class _ActionButtons extends StatelessWidget {
  final List<String> outputFiles;
  final WidgetRef ref;
  final BuildContext context;

  const _ActionButtons({required this.outputFiles, required this.ref, required this.context});

  String? get _folderPath {
    if (outputFiles.isEmpty) return null;
    final file = outputFiles.first.replaceAll('\\', '/');
    final parts = file.split('/');
    parts.removeLast();
    return parts.join('/');
  }

  @override
  Widget build(BuildContext ctx) {
    String? blendFile;
    for (final f in outputFiles) {
      if (f.toLowerCase().endsWith('.blend')) {
        blendFile = f;
        break;
      }
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (outputFiles.isNotEmpty)
          FilledButton.icon(
            icon: const Icon(Icons.play_circle_filled),
            label: const Text('เปิดไฟล์วิดีโอ'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            onPressed: () async {
              final mp4 = outputFiles.firstWhere(
                (f) => f.toLowerCase().endsWith('.mp4'),
                orElse: () => outputFiles.first,
              );
              await OpenFile.open(mp4);
            },
          ),
        if (blendFile != null)
          FilledButton.icon(
            icon: const Icon(Icons.view_in_ar),
            label: const Text('เปิดใน Blender (.blend)'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            onPressed: () async {
              await OpenFile.open(blendFile!);
            },
          ),
        if (_folderPath != null)
          OutlinedButton.icon(
            icon: const Icon(Icons.folder_open),
            label: const Text('เปิดโฟลเดอร์'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            onPressed: () async {
              final uri = Uri.file(_folderPath!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
      ],
    );
  }
}

class _ErrorDetails extends StatelessWidget {
  final RenderJob job;
  const _ErrorDetails({required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('รายละเอียดข้อผิดพลาด', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 8),
          Text(job.errorMessage ?? job.message, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
