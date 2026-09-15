import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../models/template_model.dart';
import '../widgets/template_card.dart';
import '../theme/app_theme.dart';

class TemplateSelectorScreen extends ConsumerWidget {
  const TemplateSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templateListProvider);
    final selected = ref.watch(selectedTemplateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกเทมเพลต'),
        leading: BackButton(onPressed: () => context.go('/')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: 0.25, backgroundColor: Colors.white24, color: AppTheme.primaryGold),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: const Row(
              children: [
                Icon(Icons.palette_outlined, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'เลือกธีมและสไตล์สำหรับวิดีโอของคุณ',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: templatesAsync.when(
              data: (templates) => _TemplateGrid(templates: templates, selected: selected),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _TemplateGrid(
                templates: TemplateModel.defaultTemplates,
                selected: selected,
                warning: 'ใช้เทมเพลตเริ่มต้น (เซิร์ฟเวอร์ไม่ตอบสนอง)',
              ),
            ),
          ),
          _BottomBar(selected: selected),
        ],
      ),
    );
  }
}

class _TemplateGrid extends ConsumerWidget {
  final List<TemplateModel> templates;
  final TemplateModel? selected;
  final String? warning;

  const _TemplateGrid({required this.templates, required this.selected, this.warning});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        if (warning != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              border: Border.all(color: Colors.orange.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(warning!, style: const TextStyle(fontSize: 13, color: Colors.orange))),
              ],
            ),
          ),
        Expanded(
          child: LayoutBuilder(builder: (ctx, constraints) {
            final crossAxisCount = constraints.maxWidth > 700 ? 3 : 2;
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: templates.length,
              itemBuilder: (ctx, i) {
                final t = templates[i];
                return TemplateCard(
                  template: t,
                  isSelected: selected?.id == t.id,
                  onTap: () => ref.read(selectedTemplateProvider.notifier).state = t,
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final TemplateModel? selected;
  const _BottomBar({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (selected != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('เลือก: ${selected!.nameTh}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('${selected!.transition} · ${selected!.effect} · ${selected!.durationPerImage}วิ/รูป',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              )
            else
              const Expanded(child: Text('กรุณาเลือกเทมเพลต', style: TextStyle(color: Colors.grey))),
            const SizedBox(width: 16),
            FilledButton.icon(
              icon: const Icon(Icons.navigate_next),
              label: const Text('ถัดไป'),
              onPressed: selected != null ? () => context.go('/import') : null,
            ),
          ],
        ),
      ),
    );
  }
}
