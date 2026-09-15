import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../models/project_model.dart';
import '../theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentProjects = ref.watch(recentProjectsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryGold, Colors.amber],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.movie_creation, color: AppTheme.primaryNavy, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'Court Movie Maker',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: Colors.white),
            tooltip: 'สลับธีม',
            onPressed: () {
              ref.read(themeModeProvider.notifier).state =
                  isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'ตั้งค่า',
            onPressed: () => _showSettings(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroBanner(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _QuickStats(),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _RecentProjectsSection(recentProjects: recentProjects),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: ref.read(backendUrlProvider));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings, color: AppTheme.primaryNavy),
            SizedBox(width: 8),
            Text('ตั้งค่า Backend'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('URL ของเซิร์ฟเวอร์ Backend:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'http://localhost:8000',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                ref.read(backendUrlProvider.notifier).state = url;
                final prefs = ref.read(sharedPreferencesProvider);
                await prefs.setString('backend_url', url);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryNavy, Color(0xFF243580), AppTheme.primaryGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryGold, width: 2),
                  ),
                  child: const Icon(Icons.videocam, color: Colors.white, size: 44),
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1)),
                const SizedBox(height: 16),
                const Text(
                  'Court Movie Maker',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.3, end: 0),
                const SizedBox(height: 8),
                const Text(
                  'สร้างวิดีโอสนามกีฬาระดับมืออาชีพ',
                  style: TextStyle(fontSize: 16, color: Colors.white70, letterSpacing: 0.5),
                ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
                const SizedBox(height: 24),
                Consumer(
                  builder: (ctx, ref, _) => FilledButton.icon(
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                    label: const Text('สร้างวิดีโอใหม่', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: AppTheme.primaryNavy,
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () {
                      ref.read(projectProvider.notifier).reset();
                      ref.read(selectedTemplateProvider.notifier).state = null;
                      ctx.go('/template');
                    },
                  ),
                ).animate().fadeIn(delay: 600.ms, duration: 600.ms).slideY(begin: 0.5, end: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _QuickStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
      return GridView.count(
        crossAxisCount: crossAxisCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.8,
        children: const [
          _StatCard(icon: Icons.palette, label: 'เทมเพลต', value: '6', color: Color(0xFF5C6BC0)),
          _StatCard(icon: Icons.speed, label: 'Render เร็ว', value: '<5 นาที', color: Color(0xFF26A69A)),
          _StatCard(icon: Icons.hd, label: 'คุณภาพ', value: 'Full HD', color: Color(0xFFEF5350)),
        ],
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1, end: 0);
  }
}

class _RecentProjectsSection extends StatelessWidget {
  final AsyncValue<List<ProjectModel>> recentProjects;
  const _RecentProjectsSection({required this.recentProjects});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, color: AppTheme.primaryNavy),
            const SizedBox(width: 8),
            Text('โปรเจกต์ล่าสุด', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 16),
        recentProjects.when(
          data: (projects) {
            if (projects.isEmpty) {
              return _EmptyProjects();
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: projects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _ProjectTile(project: projects[i]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _EmptyProjects(),
        ),
      ],
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.movie_creation_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('ยังไม่มีโปรเจกต์', style: TextStyle(color: Colors.grey, fontSize: 16)),
          SizedBox(height: 4),
          Text('กด "สร้างวิดีโอใหม่" เพื่อเริ่มต้น', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final ProjectModel project;
  const _ProjectTile({required this.project});

  @override
  Widget build(BuildContext context) {
    final statusColors = {
      ProjectStatus.draft: Colors.grey,
      ProjectStatus.uploading: Colors.blue,
      ProjectStatus.rendering: Colors.orange,
      ProjectStatus.done: Colors.green,
      ProjectStatus.error: Colors.red,
    };
    final statusLabels = {
      ProjectStatus.draft: 'ร่าง',
      ProjectStatus.uploading: 'กำลังอัปโหลด',
      ProjectStatus.rendering: 'กำลัง Render',
      ProjectStatus.done: 'เสร็จแล้ว',
      ProjectStatus.error: 'เกิดข้อผิดพลาด',
    };
    final color = statusColors[project.status] ?? Colors.grey;

    return Card(
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryNavy.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.movie, color: AppTheme.primaryNavy),
        ),
        title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${project.imagePaths.length} รูปภาพ · ${project.templateId}'),
        trailing: Chip(
          label: Text(statusLabels[project.status] ?? '', style: const TextStyle(fontSize: 12)),
          backgroundColor: color.withOpacity(0.15),
          side: BorderSide(color: color.withOpacity(0.3)),
          labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
          padding: EdgeInsets.zero,
        ),
        onTap: () {},
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05, end: 0);
  }
}
