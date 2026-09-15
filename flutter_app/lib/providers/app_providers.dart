import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/template_model.dart';
import '../models/project_model.dart';
import '../models/media_clip.dart';
import '../models/audio_track_model.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

// ─── SharedPreferences ──────────────────────────────────────────────────────
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// ─── Theme ──────────────────────────────────────────────────────────────────
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

// ─── Backend URL ─────────────────────────────────────────────────────────────
final backendUrlProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString('backend_url') ?? 'http://localhost:8000';
});

// ─── Api Service ─────────────────────────────────────────────────────────────
final apiServiceProvider = Provider<ApiService>((ref) {
  final url = ref.watch(backendUrlProvider);
  return ApiService(baseUrl: url);
});

// ─── WebSocket Service ────────────────────────────────────────────────────────
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final url = ref.watch(backendUrlProvider);
  final wsUrl = url.replaceFirst('http', 'ws');
  return WebSocketService(baseWsUrl: wsUrl);
});

// ─── Templates ───────────────────────────────────────────────────────────────
final templateListProvider = FutureProvider<List<TemplateModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getTemplates();
});

final selectedTemplateProvider = StateProvider<TemplateModel?>((ref) => null);

// ─── Project State ────────────────────────────────────────────────────────────
class ProjectState {
  final ProjectModel? project;
  final List<String> imagePaths;
  final String? audioPath;
  final List<AudioTrackConfig> audioTracks;
  final String? scriptText;
  final bool useScriptAudio;
  final String? scriptAudioPath;
  final bool isLoading;
  final String? errorMessage;
  final String? projectId;
  // TTS options
  final String ttsGender;   // 'female' | 'male'
  final String ttsRate;     // '+0%' | '-10%' | '+10%' etc.
  // Blender 3D options
  final bool useBlender;
  final String blenderPath;
  // Transition options
  final String? customTransition;
  final double transitionDuration;
  final List<String> clipTransitions;

  const ProjectState({
    this.project,
    this.imagePaths = const [],
    this.audioPath,
    this.audioTracks = const [],
    this.scriptText,
    this.useScriptAudio = false,
    this.scriptAudioPath,
    this.isLoading = false,
    this.errorMessage,
    this.projectId,
    this.ttsGender = 'female',
    this.ttsRate = '+0%',
    this.useBlender = false,
    this.blenderPath = 'blender',
    this.customTransition,
    this.transitionDuration = 1.5,
    this.clipTransitions = const [],
  });

  ProjectState copyWith({
    ProjectModel? project,
    List<String>? imagePaths,
    String? audioPath,
    List<AudioTrackConfig>? audioTracks,
    String? scriptText,
    bool? useScriptAudio,
    String? scriptAudioPath,
    bool? isLoading,
    String? errorMessage,
    String? projectId,
    String? ttsGender,
    String? ttsRate,
    bool? useBlender,
    String? blenderPath,
    String? customTransition,
    double? transitionDuration,
    List<String>? clipTransitions,
    bool clearTransition = false,
    bool clearError = false,
    bool clearAudio = false,
    bool clearScriptAudio = false,
  }) {
    return ProjectState(
      project: project ?? this.project,
      imagePaths: imagePaths ?? this.imagePaths,
      audioPath: clearAudio ? null : (audioPath ?? this.audioPath),
      audioTracks: audioTracks ?? this.audioTracks,
      scriptText: scriptText ?? this.scriptText,
      useScriptAudio: useScriptAudio ?? this.useScriptAudio,
      scriptAudioPath: clearScriptAudio ? null : (scriptAudioPath ?? this.scriptAudioPath),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      projectId: projectId ?? this.projectId,
      ttsGender: ttsGender ?? this.ttsGender,
      ttsRate: ttsRate ?? this.ttsRate,
      useBlender: useBlender ?? this.useBlender,
      blenderPath: blenderPath ?? this.blenderPath,
      customTransition: clearTransition ? null : (customTransition ?? this.customTransition),
      transitionDuration: transitionDuration ?? this.transitionDuration,
      clipTransitions: clipTransitions ?? this.clipTransitions,
    );
  }

  List<MediaClip> get imageClips => imagePaths
      .asMap()
      .entries
      .map((e) => MediaClip(path: e.value, type: MediaType.image, durationSeconds: 3, order: e.key))
      .toList();
}

class ProjectNotifier extends StateNotifier<ProjectState> {
  ProjectNotifier() : super(const ProjectState());

  void setImagePaths(List<String> paths) {
    state = state.copyWith(imagePaths: paths, clearError: true);
  }

  void reorderImages(int oldIndex, int newIndex) {
    final list = List<String>.from(state.imagePaths);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(imagePaths: list);
  }

  void removeImage(int index) {
    final list = List<String>.from(state.imagePaths);
    list.removeAt(index);
    state = state.copyWith(imagePaths: list);
  }

  void setAudioPath(String? path) {
    if (path == null) {
      state = state.copyWith(clearAudio: true);
    } else {
      state = state.copyWith(audioPath: path);
    }
  }

  void setAudioTracks(List<AudioTrackConfig> tracks) {
    state = state.copyWith(
      audioTracks: tracks,
      audioPath: tracks.isNotEmpty ? tracks.first.path : null,
      clearAudio: tracks.isEmpty,
    );
  }

  void addAudioTrack(AudioTrackConfig track) {
    final list = List<AudioTrackConfig>.from(state.audioTracks);
    list.add(track);
    state = state.copyWith(
      audioTracks: list,
      audioPath: list.first.path,
    );
  }

  void updateAudioTrack(int index, AudioTrackConfig track) {
    if (index < 0 || index >= state.audioTracks.length) return;
    final list = List<AudioTrackConfig>.from(state.audioTracks);
    list[index] = track;
    state = state.copyWith(audioTracks: list);
  }

  void removeAudioTrack(int index) {
    if (index < 0 || index >= state.audioTracks.length) return;
    final list = List<AudioTrackConfig>.from(state.audioTracks);
    list.removeAt(index);
    state = state.copyWith(
      audioTracks: list,
      audioPath: list.isNotEmpty ? list.first.path : null,
      clearAudio: list.isEmpty,
    );
  }

  void reorderAudioTracks(int oldIndex, int newIndex) {
    final list = List<AudioTrackConfig>.from(state.audioTracks);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(
      audioTracks: list,
      audioPath: list.isNotEmpty ? list.first.path : null,
    );
  }

  void setScriptText(String text) {
    state = state.copyWith(scriptText: text);
  }

  void setUseScriptAudio(bool val) {
    state = state.copyWith(useScriptAudio: val);
  }

  void setScriptAudioPath(String? path) {
    if (path == null) {
      state = state.copyWith(clearScriptAudio: true);
    } else {
      state = state.copyWith(scriptAudioPath: path);
    }
  }

  void setProjectId(String id) {
    state = state.copyWith(projectId: id);
  }

  void setLoading(bool val) {
    state = state.copyWith(isLoading: val);
  }

  void setError(String? msg) {
    state = state.copyWith(errorMessage: msg, isLoading: false);
  }

  // TTS setters
  void setTtsGender(String gender) => state = state.copyWith(ttsGender: gender);
  void setTtsRate(String rate) => state = state.copyWith(ttsRate: rate);

  // Blender setters
  void setUseBlender(bool val) => state = state.copyWith(useBlender: val);
  void setBlenderPath(String path) => state = state.copyWith(blenderPath: path);

  static const List<String> availableTransitionIds = [
    'crossfade',
    'push_slide',
    'slide',
    'wipe_diagonal',
    'wipe',
    'zoom_in',
    'glitter',
  ];

  // Transition setters
  void setTransition(String? transition, {double? duration}) {
    state = state.copyWith(
      customTransition: transition,
      transitionDuration: duration ?? state.transitionDuration,
      clearTransition: transition == null,
    );
    if (transition != null) {
      setAllClipTransitions(transition);
    }
  }

  void setClipTransition(int index, String transition) {
    final neededCount = max(0, state.imagePaths.length - 1);
    final list = List<String>.from(state.clipTransitions);
    while (list.length < neededCount) {
      list.add(state.customTransition ?? 'crossfade');
    }
    if (index >= 0 && index < list.length) {
      list[index] = transition;
      state = state.copyWith(clipTransitions: list);
    }
  }

  void setAllClipTransitions(String transition) {
    final neededCount = max(0, state.imagePaths.length - 1);
    final list = List<String>.filled(neededCount, transition);
    state = state.copyWith(clipTransitions: list, customTransition: transition);
  }

  void randomizeClipTransitions() {
    final neededCount = max(0, state.imagePaths.length - 1);
    if (neededCount == 0) return;
    final rand = Random();
    final list = <String>[];
    String? last;
    for (int i = 0; i < neededCount; i++) {
      final choices = availableTransitionIds.where((t) => t != last).toList();
      final picked = choices[rand.nextInt(choices.length)];
      list.add(picked);
      last = picked;
    }
    state = state.copyWith(clipTransitions: list);
  }

  List<String> getEffectiveClipTransitions(String defaultTransition) {
    final neededCount = max(0, state.imagePaths.length - 1);
    final list = List<String>.from(state.clipTransitions);
    while (list.length < neededCount) {
      list.add(state.customTransition ?? defaultTransition);
    }
    if (list.length > neededCount) {
      return list.sublist(0, neededCount);
    }
    return list;
  }

  void reset() {
    state = const ProjectState();
  }
}

final projectProvider = StateNotifierProvider<ProjectNotifier, ProjectState>((ref) {
  return ProjectNotifier();
});

// ─── Render Job State ─────────────────────────────────────────────────────────
class RenderJobState {
  final RenderJob? job;
  final bool isRendering;
  final List<String> logMessages;
  final String? errorMessage;

  const RenderJobState({
    this.job,
    this.isRendering = false,
    this.logMessages = const [],
    this.errorMessage,
  });

  RenderJobState copyWith({
    RenderJob? job,
    bool? isRendering,
    List<String>? logMessages,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RenderJobState(
      job: job ?? this.job,
      isRendering: isRendering ?? this.isRendering,
      logMessages: logMessages ?? this.logMessages,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class RenderJobNotifier extends StateNotifier<RenderJobState> {
  RenderJobNotifier() : super(const RenderJobState());

  void startRender(String jobId) {
    state = RenderJobState(
      job: RenderJob.initial(jobId),
      isRendering: true,
      logMessages: ['🚀 เริ่มต้น Render job: $jobId'],
    );
  }

  void updateProgress(RenderProgress progress) {
    final current = state.job ?? RenderJob.initial('');
    final updated = current.copyWith(
      status: progress.status,
      progress: progress.progress,
      message: progress.message,
      outputFiles: progress.outputFiles,
    );
    final pctText = _pct(progress.progress);
    final newMsg = '[$pctText] ${progress.message}';
    final msgs = List<String>.from(state.logMessages);
    if (msgs.isEmpty || msgs.last != newMsg) {
      msgs.add(newMsg);
    }
    state = state.copyWith(
      job: updated,
      isRendering: progress.status == RenderStatus.running || progress.status == RenderStatus.pending,
      logMessages: msgs,
    );
  }

  void setError(String msg) {
    final msgs = List<String>.from(state.logMessages)..add('❌ $msg');
    state = state.copyWith(isRendering: false, errorMessage: msg, logMessages: msgs);
  }

  void reset() {
    state = const RenderJobState();
  }

  String _pct(double p) => '${(p > 1.0 ? p : p * 100).toStringAsFixed(0)}%';
}

final renderJobProvider = StateNotifierProvider<RenderJobNotifier, RenderJobState>((ref) {
  return RenderJobNotifier();
});

// ─── Recent projects ─────────────────────────────────────────────────────────
final recentProjectsProvider = FutureProvider<List<ProjectModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getProjects();
});
