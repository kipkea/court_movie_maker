import 'package:flutter_test/flutter_test.dart';
import 'package:court_movie_maker/models/audio_track_model.dart';
import 'package:court_movie_maker/providers/app_providers.dart';

void main() {
  group('AudioTrackConfig Tests', () {
    test('Calculates trimmed duration accurately', () {
      const track = AudioTrackConfig(
        id: 't1',
        path: 'C:/music/song1.mp3',
        name: 'song1.mp3',
        duration: 180.0,
        startTrim: 15.0,
        endTrim: 45.0,
        volume: 1.2,
        fadeIn: 2.0,
        fadeOut: 2.5,
      );

      expect(track.trimmedDuration, equals(30.0));
      expect(track.volume, equals(1.2));
      expect(track.fadeIn, equals(2.0));
      expect(track.fadeOut, equals(2.5));
    });

    test('Serializes to and from JSON correctly', () {
      const original = AudioTrackConfig(
        id: 't2',
        path: 'D:/audio/sample.mp3',
        name: 'sample.mp3',
        duration: 120.0,
        startTrim: 10.0,
        endTrim: 90.0,
        volume: 0.8,
        fadeIn: 1.5,
        fadeOut: 2.0,
        serverFilename: 'server_sample.mp3',
      );

      final json = original.toJson();
      expect(json['id'], equals('t2'));
      expect(json['filename'], equals('server_sample.mp3'));
      expect(json['volume'], equals(0.8));

      final deserialized = AudioTrackConfig.fromJson(json);
      expect(deserialized.id, equals('t2'));
      expect(deserialized.startTrim, equals(10.0));
      expect(deserialized.endTrim, equals(90.0));
      expect(deserialized.volume, equals(0.8));
    });
  });

  group('ProjectNotifier Audio Tracks Tests', () {
    test('Manages multi-track audio list correctly', () {
      final notifier = ProjectNotifier();
      expect(notifier.state.audioTracks, isEmpty);

      const track1 = AudioTrackConfig(
        id: 't1',
        path: 'D:/audio/song1.mp3',
        name: 'song1.mp3',
        duration: 100.0,
        startTrim: 0.0,
        endTrim: 100.0,
      );
      const track2 = AudioTrackConfig(
        id: 't2',
        path: 'D:/audio/song2.mp3',
        name: 'song2.mp3',
        duration: 80.0,
        startTrim: 5.0,
        endTrim: 75.0,
      );

      notifier.addAudioTrack(track1);
      notifier.addAudioTrack(track2);
      expect(notifier.state.audioTracks.length, equals(2));
      expect(notifier.state.audioPath, equals('D:/audio/song1.mp3'));

      // Reorder
      notifier.reorderAudioTracks(0, 1);
      expect(notifier.state.audioTracks.first.id, equals('t2'));
      expect(notifier.state.audioPath, equals('D:/audio/song2.mp3'));

      // Update
      final updated = notifier.state.audioTracks.first.copyWith(volume: 1.4);
      notifier.updateAudioTrack(0, updated);
      expect(notifier.state.audioTracks.first.volume, equals(1.4));

      // Remove
      notifier.removeAudioTrack(0);
      expect(notifier.state.audioTracks.length, equals(1));
      expect(notifier.state.audioTracks.first.id, equals('t1'));
    });
  });
}
