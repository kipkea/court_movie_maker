import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/audio_track_model.dart';
import '../theme/app_theme.dart';

class AudioTrackEditorCard extends StatefulWidget {
  final AudioTrackConfig track;
  final int index;
  final int totalCount;
  final ValueChanged<AudioTrackConfig> onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const AudioTrackEditorCard({
    super.key,
    required this.track,
    required this.index,
    required this.totalCount,
    required this.onChanged,
    required this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  State<AudioTrackEditorCard> createState() => _AudioTrackEditorCardState();
}

class _AudioTrackEditorCardState extends State<AudioTrackEditorCard> {
  late final AudioPlayer _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;

  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isPlayingTrimmedOnly = false;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    _positionSub = _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);

      // ตรวจสอบว่าถ้าเล่นช่วงที่ตัดแล้วถึง endTrim ให้หยุด
      final posSec = pos.inMilliseconds / 1000.0;
      if (_isPlayingTrimmedOnly && posSec >= widget.track.endTrim) {
        _player.pause();
        setState(() {
          _isPlaying = false;
          _isPlayingTrimmedOnly = false;
        });
      }
    });

    _durationSub = _player.onDurationChanged.listen((dur) {
      if (!mounted) return;
      final durSec = dur.inMilliseconds / 1000.0;
      if (durSec > 0 && (widget.track.duration <= 0 || (widget.track.duration - durSec).abs() > 1.0)) {
        widget.onChanged(widget.track.copyWith(
          duration: durSec,
          endTrim: widget.track.endTrim <= 0 || widget.track.endTrim > durSec ? durSec : widget.track.endTrim,
        ));
      }
    });

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    try {
      await _player.setSource(DeviceFileSource(widget.track.path));
      final dur = await _player.getDuration();
      if (dur != null && dur.inMilliseconds > 0) {
        final durSec = dur.inMilliseconds / 1000.0;
        if (widget.track.duration <= 0) {
          widget.onChanged(widget.track.copyWith(
            duration: durSec,
            endTrim: durSec,
          ));
        }
      }
    } catch (_) {
      // Ignored for preview initialization error
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _formatTime(double seconds) {
    if (seconds < 0) seconds = 0;
    final int m = seconds ~/ 60;
    final int s = (seconds % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() {
        _isPlaying = false;
        _isPlayingTrimmedOnly = false;
      });
    } else {
      _isPlayingTrimmedOnly = false;
      await _player.setVolume(widget.track.volume.clamp(0.0, 1.0));
      await _player.resume();
    }
  }

  Future<void> _playTrimmed() async {
    _isPlayingTrimmedOnly = true;
    await _player.seek(Duration(milliseconds: (widget.track.startTrim * 1000).toInt()));
    await _player.setVolume(widget.track.volume.clamp(0.0, 1.0));
    await _player.resume();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final maxDur = max(track.duration, 1.0);
    final clampedStart = track.startTrim.clamp(0.0, maxDur);
    final clampedEnd = track.endTrim.clamp(clampedStart, maxDur);
    final currentPosSec = (_position.inMilliseconds / 1000.0).clamp(0.0, maxDur);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.primaryNavy.withOpacity(0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Track Number, Name, Order Controls, Remove
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.primaryNavy,
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'ความยาวเดิม: ${_formatTime(track.duration)} | ความยาวที่ใช้: ${_formatTime(track.trimmedDuration)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (widget.onMoveUp != null && widget.index > 0)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 20),
                    tooltip: 'เลื่อนขึ้น',
                    onPressed: widget.onMoveUp,
                  ),
                if (widget.onMoveDown != null && widget.index < widget.totalCount - 1)
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 20),
                    tooltip: 'เลื่อนลง',
                    onPressed: widget.onMoveDown,
                  ),
                IconButton(
                  icon: Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                  tooltip: _isExpanded ? 'ย่อรายละเอียด' : 'ขยายรายละเอียด',
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'ลบเพลงนี้',
                  onPressed: widget.onRemove,
                ),
              ],
            ),

            // Mini Player Bar
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                    iconSize: 32,
                    color: AppTheme.primaryNavy,
                    onPressed: _togglePlay,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(currentPosSec),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: currentPosSec,
                        min: 0.0,
                        max: maxDur,
                        onChanged: (val) {
                          _player.seek(Duration(milliseconds: (val * 1000).toInt()));
                        },
                      ),
                    ),
                  ),
                  Text(
                    _formatTime(maxDur),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.playlist_play, size: 18),
                    label: const Text('ฟังช่วงที่ตัด', style: TextStyle(fontSize: 12)),
                    onPressed: _playTrimmed,
                  ),
                ],
              ),
            ),

            if (_isExpanded) ...[
              const Divider(height: 24),

              // 1. Trimming Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.content_cut, size: 16, color: Colors.indigo),
                      SizedBox(width: 6),
                      Text('ตัดช่วงของเพลง', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  Text(
                    '${_formatTime(clampedStart)} - ${_formatTime(clampedEnd)} (ยาว ${_formatTime(track.trimmedDuration)})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ],
              ),
              RangeSlider(
                values: RangeValues(clampedStart, clampedEnd),
                min: 0.0,
                max: maxDur,
                labels: RangeLabels(_formatTime(clampedStart), _formatTime(clampedEnd)),
                onChanged: (RangeValues values) {
                  widget.onChanged(track.copyWith(
                    startTrim: values.start,
                    endTrim: values.end,
                  ));
                },
              ),

              const SizedBox(height: 6),

              // 2. Volume Slider & Fade In/Out Controls
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Volume Control
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.volume_up, size: 16, color: Colors.teal),
                                SizedBox(width: 6),
                                Text('ระดับเสียง', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                            Text(
                              '${(track.volume * 100).round()}%',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                            ),
                          ],
                        ),
                        Slider(
                          value: track.volume,
                          min: 0.0,
                          max: 1.5,
                          divisions: 30,
                          label: '${(track.volume * 100).round()}%',
                          onChanged: (val) {
                            widget.onChanged(track.copyWith(volume: val));
                            _player.setVolume(val.clamp(0.0, 1.0));
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Fade In & Fade Out Controls
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.waves, size: 16, color: Colors.orange),
                                SizedBox(width: 6),
                                Text('Fade In / Fade Out', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                            Text(
                              'เข้า ${track.fadeIn}s / ออก ${track.fadeOut}s',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Fade In: ${track.fadeIn}s', style: const TextStyle(fontSize: 11)),
                                  Slider(
                                    value: track.fadeIn,
                                    min: 0.0,
                                    max: 5.0,
                                    divisions: 10,
                                    onChanged: (val) {
                                      widget.onChanged(track.copyWith(fadeIn: val));
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Fade Out: ${track.fadeOut}s', style: const TextStyle(fontSize: 11)),
                                  Slider(
                                    value: track.fadeOut,
                                    min: 0.0,
                                    max: 5.0,
                                    divisions: 10,
                                    onChanged: (val) {
                                      widget.onChanged(track.copyWith(fadeOut: val));
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
