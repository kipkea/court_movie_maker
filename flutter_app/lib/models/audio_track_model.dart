class AudioTrackConfig {
  final String id;
  final String path;
  final String name;
  final double duration;
  final double startTrim;
  final double endTrim;
  final double volume;
  final double fadeIn;
  final double fadeOut;
  final String? serverFilename;

  const AudioTrackConfig({
    required this.id,
    required this.path,
    required this.name,
    required this.duration,
    this.startTrim = 0.0,
    required this.endTrim,
    this.volume = 1.0,
    this.fadeIn = 1.0,
    this.fadeOut = 1.5,
    this.serverFilename,
  });

  double get trimmedDuration => (endTrim > startTrim) ? (endTrim - startTrim) : 0.0;

  AudioTrackConfig copyWith({
    String? id,
    String? path,
    String? name,
    double? duration,
    double? startTrim,
    double? endTrim,
    double? volume,
    double? fadeIn,
    double? fadeOut,
    String? serverFilename,
  }) {
    return AudioTrackConfig(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      duration: duration ?? this.duration,
      startTrim: startTrim ?? this.startTrim,
      endTrim: endTrim ?? this.endTrim,
      volume: volume ?? this.volume,
      fadeIn: fadeIn ?? this.fadeIn,
      fadeOut: fadeOut ?? this.fadeOut,
      serverFilename: serverFilename ?? this.serverFilename,
    );
  }

  factory AudioTrackConfig.fromJson(Map<String, dynamic> json) {
    return AudioTrackConfig(
      id: json['id'] as String? ?? '',
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      startTrim: (json['start_trim'] as num?)?.toDouble() ?? 0.0,
      endTrim: (json['end_trim'] as num?)?.toDouble() ?? (json['duration'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      fadeIn: (json['fade_in'] as num?)?.toDouble() ?? 1.0,
      fadeOut: (json['fade_out'] as num?)?.toDouble() ?? 1.5,
      serverFilename: json['filename'] as String? ?? json['server_filename'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'name': name,
    'filename': serverFilename ?? (path.replaceAll('\\', '/').split('/').last),
    'duration': duration,
    'start_trim': startTrim,
    'end_trim': endTrim,
    'volume': volume,
    'fade_in': fadeIn,
    'fade_out': fadeOut,
  };
}
