import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/app_providers.dart';
import '../widgets/media_thumbnail.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class MediaImportScreen extends ConsumerStatefulWidget {
  const MediaImportScreen({super.key});

  @override
  ConsumerState<MediaImportScreen> createState() => _MediaImportScreenState();
}

class _MediaImportScreenState extends ConsumerState<MediaImportScreen> {
  int _currentStep = 0;
  final _scriptController = TextEditingController();
  bool _isUploading = false;
  String? _uploadError;

  @override
  void dispose() {
    _scriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider);
    final selected = ref.watch(selectedTemplateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('นำเข้าสื่อ'),
        leading: BackButton(onPressed: () => context.go('/template')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: 0.5,
            backgroundColor: Colors.white24,
            color: AppTheme.primaryGold,
          ),
        ),
      ),
      body: Column(
        children: [
          if (selected != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.primaryNavy.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.palette, size: 16, color: AppTheme.primaryNavy),
                  const SizedBox(width: 6),
                  Text('เทมเพลต: ${selected.nameTh}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          Expanded(
            child: Stepper(
              currentStep: _currentStep,
              type: StepperType.horizontal,
              controlsBuilder: (ctx, details) => const SizedBox.shrink(),
              steps: [
                Step(
                  title: const Text('รูปภาพ'),
                  subtitle: Text('${project.imagePaths.length} รูป'),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 && project.imagePaths.isNotEmpty ? StepState.complete : StepState.indexed,
                  content: _ImageStep(onNext: _nextStep),
                ),
                Step(
                  title: const Text('เสียงเพลง'),
                  subtitle: project.audioPath != null ? const Text('เลือกแล้ว') : null,
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  content: _AudioStep(onNext: _nextStep, onBack: _prevStep),
                ),
                Step(
                  title: const Text('สคริปต์'),
                  isActive: _currentStep >= 2,
                  state: StepState.indexed,
                  content: _ScriptStep(
                    controller: _scriptController,
                    onBack: _prevStep,
                    onSubmit: _handleSubmit,
                    isUploading: _isUploading,
                    error: _uploadError,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < 2) setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _handleSubmit() async {
    final projectState = ref.read(projectProvider);
    final selectedTemplate = ref.read(selectedTemplateProvider);

    if (projectState.imagePaths.isEmpty) {
      setState(() => _uploadError = 'กรุณาเลือกรูปภาพอย่างน้อย 1 รูป');
      return;
    }
    if (selectedTemplate == null) {
      setState(() => _uploadError = 'กรุณาเลือกเทมเพลตก่อน');
      return;
    }

    setState(() { _isUploading = true; _uploadError = null; });
    final api = ref.read(apiServiceProvider);
    final notifier = ref.read(projectProvider.notifier);

    try {
      final projectName = 'Project_${DateTime.now().millisecondsSinceEpoch}';
      final projectId = await api.createProject(projectName, selectedTemplate.id);
      notifier.setProjectId(projectId);

      final images = projectState.imagePaths.map((p) => File(p)).toList();
      await api.uploadImages(projectId, images);

      if (projectState.audioPath != null) {
        await api.uploadAudio(projectId, File(projectState.audioPath!));
      }

      final script = _scriptController.text.trim();
      if (script.isNotEmpty) {
        await api.uploadScript(
          projectId,
          script,
          'th',
          gender: projectState.ttsGender,
          rate: projectState.ttsRate,
        );
        notifier.setScriptText(script);
      }

      if (mounted) context.go('/preview');
    } on ApiException catch (e) {
      setState(() => _uploadError = e.message);
    } catch (e) {
      setState(() => _uploadError = 'เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}

// ─── Step 1: Images ──────────────────────────────────────────────────────────
class _ImageStep extends ConsumerWidget {
  final VoidCallback onNext;
  const _ImageStep({required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final notifier = ref.read(projectProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('เลือกรูปภาพ (เลือกหลายรูปได้)'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
          ),
          onPressed: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.image,
              allowMultiple: true,
            );
            if (result != null) {
              final existing = List<String>.from(project.imagePaths);
              final newPaths = result.paths.whereType<String>().toList();
              notifier.setImagePaths([...existing, ...newPaths]);
            }
          },
        ),
        const SizedBox(height: 16),
        if (project.imagePaths.isEmpty)
          Container(
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3), style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined, size: 52, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('ยังไม่ได้เลือกรูปภาพ', style: TextStyle(color: Colors.grey)),
                  Text('กดปุ่มด้านบนเพื่อเลือกรูป', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${project.imagePaths.length} รูปภาพ (ลากเพื่อจัดลำดับ)',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: project.imagePaths.length,
                  onReorderItem: (oldIndex, newIndex) => notifier.reorderImages(oldIndex, newIndex),
                  itemBuilder: (ctx, i) {
                    return Padding(
                      key: ValueKey(project.imagePaths[i]),
                      padding: const EdgeInsets.only(right: 8),
                      child: MediaThumbnail(
                        path: project.imagePaths[i],
                        order: i + 1,
                        onDelete: () => notifier.removeImage(i),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          icon: const Icon(Icons.navigate_next),
          label: const Text('ถัดไป: เสียงเพลง'),
          onPressed: project.imagePaths.isNotEmpty ? onNext : null,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Step 2: Audio ──────────────────────────────────────────────────────────
class _AudioStep extends ConsumerWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const _AudioStep({required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final notifier = ref.read(projectProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.music_note),
          label: const Text('เลือกไฟล์เสียงเพลง (MP3, WAV, M4A)'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
          ),
          onPressed: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.audio,
              allowMultiple: false,
            );
            if (result != null && result.paths.isNotEmpty) {
              notifier.setAudioPath(result.paths.first);
            }
          },
        ),
        const SizedBox(height: 16),
        if (project.audioPath != null) ...[
          _AudioPreviewCard(path: project.audioPath!, onRemove: () => notifier.setAudioPath(null)),
        ] else
          Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.music_off, size: 40, color: Colors.grey),
                  SizedBox(height: 6),
                  Text('ไม่บังคับ - สามารถข้ามได้', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.navigate_before),
              label: const Text('ย้อนกลับ'),
              onPressed: onBack,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.navigate_next),
                label: const Text('ถัดไป: สคริปต์'),
                onPressed: onNext,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _AudioPreviewCard extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  const _AudioPreviewCard({required this.path, required this.onRemove});

  String get _filename => path.replaceAll('\\', '/').split('/').last;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.purple, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_filename, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const Text('ไฟล์เสียงเพลง', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: onRemove,
                  tooltip: 'ลบ',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Waveform placeholder
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(painter: _WaveformPainter()),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }
}

class _WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.purple.withOpacity(0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const bars = 50;
    final barWidth = size.width / bars;
    final heights = [0.3, 0.6, 0.8, 0.4, 0.9, 0.5, 0.7, 0.3, 0.85, 0.6, 0.4, 0.75, 0.5, 0.9, 0.3, 0.65, 0.8, 0.4, 0.7, 0.55];
    for (int i = 0; i < bars; i++) {
      final h = size.height * heights[i % heights.length];
      final x = i * barWidth + barWidth / 2;
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Step 3: Script ──────────────────────────────────────────────────────────
class _ScriptStep extends ConsumerWidget {
  final TextEditingController controller;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final bool isUploading;
  final String? error;

  const _ScriptStep({
    required this.controller,
    required this.onBack,
    required this.onSubmit,
    required this.isUploading,
    this.error,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final notifier = ref.read(projectProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ToggleButton(
                label: 'พิมพ์สคริปต์',
                icon: Icons.edit_note,
                selected: !project.useScriptAudio,
                onTap: () => notifier.setUseScriptAudio(false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ToggleButton(
                label: 'อัปโหลดเสียงบรรยาย',
                icon: Icons.mic,
                selected: project.useScriptAudio,
                onTap: () => notifier.setUseScriptAudio(true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!project.useScriptAudio) ...[
          TextField(
            controller: controller,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'พิมพ์สคริปต์หรือคำบรรยายภาษาไทยที่ต้องการให้ระบบอ่านออกเสียง (TTS)...\nตัวอย่าง: "ขอแสดงความยินดีและขอบคุณในความเสียสละตลอดอายุราชการ ขอให้ท่านมีสุขภาพแข็งแรงและมีความสุขในชีวิตเกษียณ"',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
          ),
          const SizedBox(height: 12),
          // เลือกเสียงผู้บรรยาย (Voice Selection)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryNavy.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryNavy.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.record_voice_over, size: 18, color: AppTheme.primaryNavy),
                    SizedBox(width: 8),
                    Text('เสียงบรรยายภาษาไทย (Thai TTS)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.female, size: 16),
                        label: const Text('เสียงหญิง (เปรมวดี)'),
                        selected: project.ttsGender == 'female',
                        onSelected: (selected) {
                          if (selected) notifier.setTtsGender('female');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.male, size: 16),
                        label: const Text('เสียงชาย (นิวัฒน์)'),
                        selected: project.ttsGender == 'male',
                        onSelected: (selected) {
                          if (selected) notifier.setTtsGender('male');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('ความเร็วเสียงพูด:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in [
                        ('-15%', 'ช้าลง (-15%)'),
                        ('+0%', 'ปกติ (0%)'),
                        ('+10%', 'เร็วขึ้น (+10%)'),
                        ('+20%', 'เร็วมาก (+20%)'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(entry.$2, style: const TextStyle(fontSize: 11)),
                            selected: project.ttsRate == entry.$1,
                            onSelected: (selected) {
                              if (selected) notifier.setTtsRate(entry.$1);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.mic),
            label: const Text('เลือกไฟล์เสียงบรรยาย'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
            ),
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(type: FileType.audio);
              if (result != null && result.paths.isNotEmpty) {
                notifier.setScriptAudioPath(result.paths.first);
              }
            },
          ),
          if (project.scriptAudioPath != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Chip(
                label: Text(project.scriptAudioPath!.split('/').last.split('\\').last),
                onDeleted: () => notifier.setScriptAudioPath(null),
                avatar: const Icon(Icons.mic, size: 16),
              ),
            ),
        ],
        if (error != null)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.navigate_before),
              label: const Text('ย้อนกลับ'),
              onPressed: isUploading ? null : onBack,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                icon: isUploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryNavy))
                    : const Icon(Icons.cloud_upload),
                label: Text(isUploading ? 'กำลังอัปโหลด...' : 'สร้างโปรเจกต์'),
                onPressed: isUploading ? null : onSubmit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleButton({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryNavy : Colors.transparent,
          border: Border.all(color: selected ? AppTheme.primaryNavy : Colors.grey.withOpacity(0.4), width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : Colors.grey),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: selected ? Colors.white : Colors.grey, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
