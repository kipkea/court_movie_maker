import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/template_selector.dart';
import 'screens/media_import.dart';
import 'screens/timeline_preview.dart';
import 'screens/export_screen.dart';
import 'theme/app_theme.dart';
import 'providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const CourtMovieMakerApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (ctx, state) => const HomeScreen()),
    GoRoute(path: '/template', builder: (ctx, state) => const TemplateSelectorScreen()),
    GoRoute(path: '/import', builder: (ctx, state) => const MediaImportScreen()),
    GoRoute(path: '/preview', builder: (ctx, state) => const TimelinePreviewScreen()),
    GoRoute(path: '/export', builder: (ctx, state) => const ExportScreen()),
  ],
);

class CourtMovieMakerApp extends ConsumerWidget {
  const CourtMovieMakerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Court Movie Maker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
