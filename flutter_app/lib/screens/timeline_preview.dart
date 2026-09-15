import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../models/project_model.dart';
import '../widgets/progress_dialog.dart';
import '../widgets/transition_preview_widget.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class TimelinePreviewScreen extends ConsumerStatefulWidget {
  const TimelinePreviewScreen({super.key});

  @override
  ConsumerState<TimelinePreviewScreen> createState() => _TimelinePreviewScreenState();
}

class _TimelinePreviewScreenState extends ConsumerState<TimelinePreviewScreen> {
  late List<String> _orderedImages;
  bool _initialized = false;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    ref.read(webSocketServiceProvider).disconnect();
    super.dispose();
  }

  void _initImages() {
    if (!_initialized) {
      _orderedImages = List<String>.from(ref.read(projectProvider).imagePaths);
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    _initImages();
    final project = ref.watch(projectProvider);
    final selected = ref.watch(selectedTemplateProvider);
    final renderJob = ref.watch(renderJobProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตรวจสอบและ Render'),
        leading: const BackButton(),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: LinearProgressIndicator(value: 0.75, backgroundColor: Colors.white24, color: AppTheme.primaryGold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Template info card
                  if (selected != null)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(int.parse('0xFF${(selected.colors['primary'] ?? '#1A2B5F').substring(1)}')),
                            Color(int.parse('0xFF${(selected.colors['secondary'] ?? '#D4AF37').substring(1)}')),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.movie_filter, color: Colors.white, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(selected.nameTh, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                                Text(
                                  'Transition: ${selected.transition} · Effect: ${selected.effect} · ${selected.durationPerImage}วิ/รูป',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(selected.mood, style: const TextStyle(color: Colors.white, fontSize: 11)),
                            backgroundColor: Colors.white24,
                            side: const BorderSide(color: Colors.white30),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0),

                  // Timeline section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.timeline, size: 18, color: AppTheme.primaryNavy),
                        const SizedBox(width: 6),
                        Text('Timeline (${_orderedImages.length} รูปภาพ)', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        const Text('ลากเพื่อจัดลำดับ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: _orderedImages.isEmpty
                        ? const Center(child: Text('ไม่มีรูปภาพ', style: TextStyle(color: Colors.grey)))
                        : ReorderableListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _orderedImages.length,
                            onReorderItem: (oldIndex, newIndex) {
                              setState(() {
                                final item = _orderedImages.removeAt(oldIndex);
                                _orderedImages.insert(newIndex, item);
                              });
                            },
                            itemBuilder: (ctx, i) {
                              final defaultTrans = project.customTransition ?? selected?.transition ?? 'crossfade';
                              final clipTrans = i < project.clipTransitions.length
                                  ? project.clipTransitions[i]
                                  : defaultTrans;
                              return _TimelineItem(
                                key: ValueKey(_orderedImages[i]),
                                path: _orderedImages[i],
                                index: i,
                                totalCount: _orderedImages.length,
                                duration: selected?.durationPerImage ?? 3,
                                transitionName: clipTrans,
                                onTapTransition: i < _orderedImages.length - 1
                                    ? () {
                                        showClipTransitionDialog(
                                          context: context,
                                          slotIndex: i,
                                          imagePathA: _orderedImages[i],
                                          imagePathB: _orderedImages[i + 1],
                                          currentTransition: clipTrans,
                                          durationSeconds: project.transitionDuration,
                                          onSelected: (t) => ref.read(projectProvider.notifier).setClipTransition(i, t),
                                          onApplyToAll: (t) => ref.read(projectProvider.notifier).setAllClipTransitions(t),
                                        );
                                      }
                                    : null,
                              );
                            },
                          ),
                  ),

                  // Transition Selector & Live Preview Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TransitionSelectorCard(
                      currentTransition: project.customTransition ?? selected?.transition ?? 'crossfade',
                      durationSeconds: project.transitionDuration,
                      imagePaths: _orderedImages,
                      clipTransitions: project.clipTransitions,
                      onTransitionChanged: (t) => ref.read(projectProvider.notifier).setTransition(t),
                      onDurationChanged: (d) => ref.read(projectProvider.notifier).setTransition(
                        project.customTransition ?? selected?.transition ?? 'crossfade',
                        duration: d,
                      ),
                      onClipTransitionChanged: (idx, t) => ref.read(projectProvider.notifier).setClipTransition(idx, t),
                      onRandomizeAll: () => ref.read(projectProvider.notifier).randomizeClipTransitions(),
                      onApplyToAll: (t) => ref.read(projectProvider.notifier).setAllClipTransitions(t),
                    ),
                  ),

                  // Script preview
                  if (project.scriptText != null && project.scriptText!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.record_voice_over, size: 18, color: AppTheme.primaryNavy),
                                  const SizedBox(width: 6),
                                  const Text('สคริปต์เสียงบรรยาย (Thai TTS)', style: TextStyle(fontWeight: FontWeight.w700)),
                                  const Spacer(),
                                  Chip(
                                    label: Text(project.ttsGender == 'male' ? 'เสียงชาย (นิวัฒน์)' : 'เสียงหญิง (เปรมวดี)', style: const TextStyle(fontSize: 10)),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(project.scriptText!, style: const TextStyle(fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // ─── Render Options (3D & Settings Card) ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.tune, size: 18, color: AppTheme.primaryNavy),
                                SizedBox(width: 6),
                                Text('การตั้งค่า Effect และการ Render', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              ],
                            ),
                            const Divider(height: 20),
                            // Switch 3D Effect Blender
                            SwitchListTile(
                              title: const Row(
                                children: [
                                  Icon(Icons.view_in_ar, size: 20, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text('3D Effect & Parallax (Blender)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                ],
                              ),
                              subtitle: const Text(
                                'สร้างฉาก 3D Camera Fly-through, แสงเงา 3D Depth และบันทึกไฟล์ .blend เพื่อเปิดแก้แบบ Manual',
                                style: TextStyle(fontSize: 12),
                              ),
                              value: project.useBlender,
                              onChanged: (val) {
                                ref.read(projectProvider.notifier).setUseBlender(val);
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                            if (project.useBlender)
                              Container(
                                margin: const EdgeInsets.only(top: 6, bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle_outline, color: Colors.orange, size: 18),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'ระบบตรวจพบ Blender 5.2 บนเครื่อง Windows แล้ว จะสร้างทั้งวิดีโอ 3D MP4 และไฟล์โปรเจกต์ .blend',
                                        style: TextStyle(fontSize: 11, color: Colors.orange),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Switch Export Project Files
                            const ListTile(
                              leading: Icon(Icons.folder_zip_outlined, size: 20, color: Colors.purple),
                              title: Text('ส่งออกไฟล์โปรเจกต์สำหรับ Manual Edit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: Text('สร้างไฟล์ .mlt (Kdenlive) และ .blend (Blender) อัตโนมัติ', style: TextStyle(fontSize: 11)),
                              trailing: Icon(Icons.check, color: Colors.green, size: 20),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar & Render button
          if (renderJob.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(renderJob.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: Icon(project.useBlender ? Icons.view_in_ar : Icons.video_call, size: 22),
                  label: Text(
                    project.useBlender ? 'เริ่ม Render วิดีโอ 3D (Blender)' : 'เริ่ม Render วิดีโอ (FFmpeg)',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: AppTheme.primaryNavy,
                  ),
                  onPressed: _startRender,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startRender() async {
    final projectState = ref.read(projectProvider);
    if (projectState.projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่พบ Project ID')));
      return;
    }

    final api = ref.read(apiServiceProvider);
    final renderNotifier = ref.read(renderJobProvider.notifier);
    final ws = ref.read(webSocketServiceProvider);

    try {
      final defaultTrans = projectState.customTransition ?? ref.read(selectedTemplateProvider)?.transition ?? 'crossfade';
      final effectiveTransitions = ref.read(projectProvider.notifier).getEffectiveClipTransitions(defaultTrans);

      final jobId = await api.startRender(
        projectState.projectId!,
        useTts: projectState.scriptText != null && projectState.scriptText!.isNotEmpty,
        exportMlt: true,
        useBlender: projectState.useBlender,
        blenderPath: projectState.blenderPath,
        imageOrder: _orderedImages,
        transition: defaultTrans,
        transitions: effectiveTransitions,
        transitionDuration: projectState.transitionDuration,
      );

      renderNotifier.startRender(jobId);

      if (!mounted) return;

      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ProgressDialog(
          jobId: jobId,
          onComplete: () {
            Navigator.pop(ctx);
            context.go('/export');
          },
          onCancel: () {
            Navigator.pop(ctx);
            ws.disconnect();
            renderNotifier.reset();
          },
        ),
      );

      // WebSocket stream
      final stream = ws.connect(jobId);
      _wsSub?.cancel();
      _wsSub = stream.listen(
        (progress) {
          renderNotifier.updateProgress(progress);
        },
        onError: (e) {
          renderNotifier.setError('WebSocket error: $e');
          _pollFallback(jobId, api, renderNotifier);
        },
      );
    } on ApiException catch (e) {
      renderNotifier.setError(e.message);
    } catch (e) {
      renderNotifier.setError('เกิดข้อผิดพลาด: $e');
    }
  }

  Future<void> _pollFallback(String jobId, ApiService api, RenderJobNotifier notifier) async {
    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        final job = await api.getRenderStatus(jobId);
        notifier.updateProgress(RenderProgress(
          progress: job.progress,
          message: job.message,
          status: job.status,
          outputFiles: job.outputFiles,
        ));
        if (job.status == RenderStatus.completed || job.status == RenderStatus.failed) break;
      } catch (_) {}
    }
  }
}

class _TimelineItem extends StatelessWidget {
  final String path;
  final int index;
  final int totalCount;
  final int duration;
  final String transitionName;
  final VoidCallback? onTapTransition;

  const _TimelineItem({
    super.key,
    required this.path,
    required this.index,
    required this.totalCount,
    required this.duration,
    required this.transitionName,
    this.onTapTransition,
  });

  Widget _buildImage() {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    try {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        );
      }
    } catch (_) {}
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.primaryNavy.withOpacity(0.15),
      child: const Center(
        child: Icon(Icons.image, size: 36, color: AppTheme.primaryNavy),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 124,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryNavy.withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildImage(),
            ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.black54,
                child: Text('$durationวิ', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
            // Transition Badge to next clip (Interactive)
            if (index < totalCount - 1)
              Positioned(
                bottom: 26,
                right: 4,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTapTransition,
                    borderRadius: BorderRadius.circular(6),
                    child: Tooltip(
                      message: 'เปลี่ยน Transition ช่วงนี้',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.swap_horiz, size: 11, color: Colors.black),
                            const SizedBox(width: 2),
                            Text(
                              transitionName,
                              style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.edit, size: 8, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Drag handle
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.drag_handle, size: 18, color: Colors.white70),
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 80)).fadeIn(duration: 300.ms).slideX(begin: 0.2, end: 0);
  }
}
