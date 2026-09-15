import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/project_model.dart';

class WebSocketService {
  final String baseWsUrl;
  WebSocketChannel? _channel;
  StreamController<RenderProgress>? _controller;
  String? _currentJobId;
  Timer? _reconnectTimer;
  bool _disposed = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  WebSocketService({this.baseWsUrl = 'ws://localhost:8000'});

  Stream<RenderProgress> connect(String jobId) {
    _currentJobId = jobId;
    _disposed = false;
    _reconnectAttempts = 0;
    _controller?.close();
    _controller = StreamController<RenderProgress>.broadcast();
    _connect();
    return _controller!.stream;
  }

  void _connect() {
    if (_disposed || _currentJobId == null) return;
    try {
      _channel?.sink.close();
      _channel = WebSocketChannel.connect(
        Uri.parse('$baseWsUrl/ws/$_currentJobId'),
      );
      _channel!.stream.listen(
        (data) {
          if (_controller == null || _controller!.isClosed) return;
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final progress = RenderProgress.fromJson(json);
            _controller!.add(progress);
            if (progress.status == RenderStatus.completed ||
                progress.status == RenderStatus.failed) {
              _dispose();
            }
          } catch (_) {}
        },
        onError: (e) {
          if (!_disposed) _scheduleReconnect();
        },
        onDone: () {
          if (!_disposed) _scheduleReconnect();
        },
        cancelOnError: false,
      );
      _reconnectAttempts = 0;
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectAttempts >= _maxReconnectAttempts) {
      _controller?.addError('การเชื่อมต่อ WebSocket หมดเวลา');
      return;
    }
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
  }

  void _dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _controller?.close();
    _controller = null;
    _channel = null;
  }

  void disconnect() => _dispose();
}
