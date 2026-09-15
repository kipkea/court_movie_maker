enum MediaType { image, audio, tts }

class MediaClip {
  final String path;
  final MediaType type;
  final int durationSeconds;
  final int order;

  const MediaClip({
    required this.path,
    required this.type,
    required this.durationSeconds,
    required this.order,
  });

  MediaClip copyWith({
    String? path,
    MediaType? type,
    int? durationSeconds,
    int? order,
  }) {
    return MediaClip(
      path: path ?? this.path,
      type: type ?? this.type,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      order: order ?? this.order,
    );
  }

  String get fileName {
    final parts = path.replaceAll('\\', '/').split('/');
    return parts.isNotEmpty ? parts.last : path;
  }

  String get extension {
    final name = fileName;
    final dot = name.lastIndexOf('.');
    return dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
  }

  bool get isImage => type == MediaType.image;
  bool get isAudio => type == MediaType.audio || type == MediaType.tts;

  factory MediaClip.fromJson(Map<String, dynamic> json) {
    return MediaClip(
      path: json['path'] as String,
      type: MediaType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'image'),
        orElse: () => MediaType.image,
      ),
      durationSeconds: (json['duration_seconds'] ?? 3) as int,
      order: (json['order'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'type': type.name,
    'duration_seconds': durationSeconds,
    'order': order,
  };
}
