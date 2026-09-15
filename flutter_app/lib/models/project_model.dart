enum ProjectStatus { draft, uploading, rendering, done, error }
enum RenderStatus { pending, running, completed, failed }

class ProjectModel {
  final String id;
  final String name;
  final String templateId;
  final List<String> imagePaths;
  final String? audioPath;
  final String? scriptText;
  final ProjectStatus status;
  final DateTime createdAt;

  const ProjectModel({
    required this.id,
    required this.name,
    required this.templateId,
    required this.imagePaths,
    this.audioPath,
    this.scriptText,
    required this.status,
    required this.createdAt,
  });

  ProjectModel copyWith({
    String? id,
    String? name,
    String? templateId,
    List<String>? imagePaths,
    String? audioPath,
    String? scriptText,
    ProjectStatus? status,
    DateTime? createdAt,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      templateId: templateId ?? this.templateId,
      imagePaths: imagePaths ?? this.imagePaths,
      audioPath: audioPath ?? this.audioPath,
      scriptText: scriptText ?? this.scriptText,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      name: json['name'] as String,
      templateId: json['template_id'] as String,
      imagePaths: List<String>.from(json['image_paths'] ?? []),
      audioPath: json['audio_path'] as String?,
      scriptText: json['script_text'] as String?,
      status: ProjectStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'draft'),
        orElse: () => ProjectStatus.draft,
      ),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'template_id': templateId,
    'image_paths': imagePaths,
    'audio_path': audioPath,
    'script_text': scriptText,
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
  };
}

class RenderJob {
  final String jobId;
  final RenderStatus status;
  final double progress;
  final String message;
  final List<String> outputFiles;
  final String? errorMessage;

  const RenderJob({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.message,
    required this.outputFiles,
    this.errorMessage,
  });

  RenderJob copyWith({
    String? jobId,
    RenderStatus? status,
    double? progress,
    String? message,
    List<String>? outputFiles,
    String? errorMessage,
  }) {
    return RenderJob(
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      outputFiles: outputFiles ?? this.outputFiles,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  static RenderStatus parseStatus(dynamic raw) {
    final s = (raw ?? 'pending').toString().toLowerCase();
    if (s == 'success' || s == 'completed' || s == 'done') return RenderStatus.completed;
    if (s == 'failed' || s == 'error') return RenderStatus.failed;
    if (s == 'running' || s == 'processing') return RenderStatus.running;
    return RenderStatus.pending;
  }

  static double parseProgress(dynamic raw) {
    if (raw == null) return 0.0;
    final numVal = raw as num;
    final d = numVal.toDouble();
    if (d > 1.0) return d / 100.0;
    return d;
  }

  factory RenderJob.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] ?? json['state'];
    return RenderJob(
      jobId: (json['job_id'] ?? '') as String,
      status: parseStatus(rawStatus),
      progress: parseProgress(json['progress']),
      message: (json['message'] ?? '') as String,
      outputFiles: json['output_files'] is Map
          ? (json['output_files'] as Map).values.map((v) => v.toString()).toList()
          : List<String>.from(json['output_files'] ?? []),
      errorMessage: json['error_message'] as String? ?? json['error'] as String?,
    );
  }

  factory RenderJob.initial(String jobId) => RenderJob(
    jobId: jobId,
    status: RenderStatus.pending,
    progress: 0,
    message: 'กำลังเริ่มต้น...',
    outputFiles: [],
  );
}

class RenderProgress {
  final double progress;
  final String message;
  final RenderStatus status;
  final List<String> outputFiles;

  const RenderProgress({
    required this.progress,
    required this.message,
    required this.status,
    this.outputFiles = const [],
  });

  factory RenderProgress.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] ?? json['state'];
    return RenderProgress(
      progress: RenderJob.parseProgress(json['progress']),
      message: (json['message'] ?? '') as String,
      status: RenderJob.parseStatus(rawStatus),
      outputFiles: json['output_files'] is Map
          ? (json['output_files'] as Map).values.map((v) => v.toString()).toList()
          : List<String>.from(json['output_files'] ?? []),
    );
  }
}
