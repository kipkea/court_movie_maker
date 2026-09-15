import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:court_movie_maker/widgets/transition_preview_widget.dart';
import 'package:court_movie_maker/providers/app_providers.dart';

void main() {
  group('Transition Features Tests', () {
    test('Available transitions contain expected transition IDs', () {
      final ids = kAvailableTransitions.map((t) => t.id).toList();
      expect(ids, contains('crossfade'));
      expect(ids, contains('push_slide'));
      expect(ids, contains('slide'));
      expect(ids, contains('wipe_diagonal'));
      expect(ids, contains('wipe'));
      expect(ids, contains('zoom_in'));
      expect(ids, contains('glitter'));
    });

    test('ProjectNotifier updates transition and duration correctly', () {
      final notifier = ProjectNotifier();
      expect(notifier.state.customTransition, isNull);
      expect(notifier.state.transitionDuration, equals(1.5));

      notifier.setTransition('push_slide', duration: 2.0);
      expect(notifier.state.customTransition, equals('push_slide'));
      expect(notifier.state.transitionDuration, equals(2.0));

      notifier.setTransition('zoom_in');
      expect(notifier.state.customTransition, equals('zoom_in'));
      expect(notifier.state.transitionDuration, equals(2.0)); // Keeps previous duration
    });

    test('ProjectNotifier manages per-clip transitions and randomization', () {
      final notifier = ProjectNotifier();
      notifier.setImagePaths(['img1.jpg', 'img2.jpg', 'img3.jpg', 'img4.jpg']);
      // 4 images = 3 transition slots
      expect(notifier.state.clipTransitions, isEmpty);

      // Set transition for slot 0
      notifier.setClipTransition(0, 'zoom_in');
      expect(notifier.state.clipTransitions.length, equals(3));
      expect(notifier.state.clipTransitions[0], equals('zoom_in'));
      expect(notifier.state.clipTransitions[1], equals('crossfade'));
      expect(notifier.state.clipTransitions[2], equals('crossfade'));

      // Set transition for slot 2
      notifier.setClipTransition(2, 'wipe_diagonal');
      expect(notifier.state.clipTransitions.length, equals(3));
      expect(notifier.state.clipTransitions[0], equals('zoom_in'));
      expect(notifier.state.clipTransitions[1], equals('crossfade')); // filled with default
      expect(notifier.state.clipTransitions[2], equals('wipe_diagonal'));

      // Effective transitions
      final effective = notifier.getEffectiveClipTransitions('crossfade');
      expect(effective, equals(['zoom_in', 'crossfade', 'wipe_diagonal']));

      // Set all transitions to glitter
      notifier.setAllClipTransitions('glitter');
      expect(notifier.state.clipTransitions, equals(['glitter', 'glitter', 'glitter']));

      // Randomize transitions
      notifier.randomizeClipTransitions();
      expect(notifier.state.clipTransitions.length, equals(3));
      for (final t in notifier.state.clipTransitions) {
        expect(kAvailableTransitions.any((item) => item.id == t), isTrue);
      }
    });

    testWidgets('TransitionSelectorCard renders and triggers callback on change', (tester) async {
      String selected = 'crossfade';
      double duration = 1.5;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TransitionSelectorCard(
                currentTransition: selected,
                durationSeconds: duration,
                imagePaths: const [],
                onTransitionChanged: (t) => selected = t,
                onDurationChanged: (d) => duration = d,
              ),
            ),
          ),
        ),
      );

      // Verify UI elements
      expect(find.text('การเปลี่ยนรูปภาพ (Transition)'), findsOneWidget);
      expect(find.text('เฟดละมุน'), findsWidgets);
      expect(find.text('สไลด์ซ้าย'), findsOneWidget);
      expect(find.text('ซูมทะลุภาพ'), findsOneWidget);

      // Tap on a different transition chip
      await tester.tap(find.text('สไลด์ซ้าย'));
      await tester.pump();
      expect(selected, equals('push_slide'));
    });
  });
}
