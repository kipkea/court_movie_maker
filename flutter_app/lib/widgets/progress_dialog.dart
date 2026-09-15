import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../providers/app_providers.dart';
import '../models/project_model.dart';
import '../theme/app_theme.dart';

class ProgressDialog extends ConsumerStatefulWidget {
  final String jobId;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const ProgressDialog({
    super.key,
    required this.jobId,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  ConsumerState<ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends ConsumerState<ProgressDialog> {
  final ScrollController _logScroll = ScrollController();
  bool _completeCalled = false;

  @override
  void dispose() {
    _logScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renderJob = ref.watch(renderJobProvider);
    final job = renderJob.job;
    final progress = job?.progress ?? 0.0;
    final status = job?.status ?? RenderStatus.pending;
    final isComplete = status == RenderStatus.completed;
    final isFailed = status == RenderStatus.failed;

    // Auto-trigger complete callback
    if (isComplete && !_completeCalled) {
      _completeCalled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) widget.onComplete();
        });
      });
    }

    // Auto-scroll log
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.animateTo(
          _logScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isComplete
                        ? Colors.green.withOpacity(0.15)
                        : isFailed
                            ? Colors.red.withOpacity(0.15)
                            : AppTheme.primaryNavy.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isComplete ? Icons.check_circle : isFailed ? Icons.error : Icons.movie_creation,
                    color: isComplete ? Colors.green : isFailed ? Colors.red : AppTheme.primaryNavy,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isComplete ? 'Render สำเร็จ! 🎉' : isFailed ? 'Render ล้มเหลว' : 'กำลัง Render...',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Job: ${widget.jobId.substring(0, widget.jobId.length.clamp(0, 12))}...',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Circular progress
            Center(
              child: CircularPercentIndicator(
                radius: 65,
                lineWidth: 10,
                percent: progress.clamp(0.0, 1.0),
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: isComplete ? Colors.green : isFailed ? Colors.red : AppTheme.primaryNavy,
                      ),
                    ),
                    if (!isComplete && !isFailed)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                progressColor: isComplete ? Colors.green : isFailed ? Colors.red : AppTheme.primaryGold,
                backgroundColor: Colors.grey.withOpacity(0.2),
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
                animateFromLastPercent: true,
              ),
            ),
            const SizedBox(height: 16),
            // Status message
            Text(
              job?.message ?? 'กำลังเริ่มต้น...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            // Linear progress
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.withOpacity(0.2),
              color: isComplete ? Colors.green : isFailed ? Colors.red : AppTheme.primaryGold,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 20),
            // Log messages
            Container(
              height: 130,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.builder(
                controller: _logScroll,
                padding: const EdgeInsets.all(10),
                itemCount: renderJob.logMessages.length,
                itemBuilder: (ctx, i) {
                  final msg = renderJob.logMessages[i];
                  final color = msg.startsWith('❌')
                      ? Colors.red
                      : msg.startsWith('🚀')
                          ? Colors.greenAccent
                          : Colors.white70;
                  return Text(
                    msg,
                    style: TextStyle(fontSize: 11, color: color, fontFamily: 'monospace'),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isComplete && !isFailed)
                  TextButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('ยกเลิก'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: widget.onCancel,
                  ),
                if (isComplete)
                  FilledButton.icon(
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('ดูผลลัพธ์'),
                    onPressed: widget.onComplete,
                  ),
                if (isFailed)
                  FilledButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('ปิด'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: widget.onCancel,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
