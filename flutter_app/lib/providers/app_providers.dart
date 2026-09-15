import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/template_model.dart';
import '../models/project_model.dart';
import '../models/media_clip.dart';
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

  const ProjectState({
    this.project,
    this.imagePaths = const [],
    this.audioPath,
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
  });

  ProjectState copyWith({
    ProjectModel? project,
    List<String>? imagePaths,
    String? audioPath,
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
    bool clearError = false,
    bool clearAudio = false,
    bool clearScriptAudio = false,
  }) {
    return ProjectState(
      project: project ?? this.project,
      imagePaths: imagePaths ?? this.imagePaths,
      audioPath: clearAudio ? null : (audioPath ?? this.audioPath),
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
