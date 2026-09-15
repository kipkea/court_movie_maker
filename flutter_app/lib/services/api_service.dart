import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/template_model.dart';
import '../models/project_model.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final String baseUrl;
  static const Duration _timeout = Duration(seconds: 30);

  ApiService({this.baseUrl = 'http://localhost:8000'});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static String _extractErrorMessage(dynamic body, {String fallback = 'เกิดข้อผิดพลาด'}) {
    if (body is Map) {
      final detail = body['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final messages = <String>[];
        for (final item in detail) {
          if (item is Map && item['msg'] != null) {
            final loc = item['loc'] is List ? (item['loc'] as List).join('.') : '';
            messages.add(loc.isNotEmpty ? '${item['msg']} ($loc)' : '${item['msg']}');
          } else {
            messages.add(item.toString());
          }
        }
        return messages.join('\n');
      }
      if (body['message'] is String) return body['message'];
    } else if (body is String) {
      return body;
    }
    return fallback;
  }

  Future<T> _handleResponse<T>(
    Future<http.Response> Function() request,
    T Function(dynamic body) parser,
  ) async {
    try {
      final response = await request().timeout(_timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = json.decode(utf8.decode(response.bodyBytes));
        return parser(body);
      } else {
        dynamic body;
        try {
          body = json.decode(utf8.decode(response.bodyBytes));
        } catch (_) {
          body = utf8.decode(response.bodyBytes);
        }
        throw ApiException(
          _extractErrorMessage(body, fallback: 'เกิดข้อผิดพลาด (${response.statusCode})'),
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้');
    } on http.ClientException catch (e) {
      throw ApiException('เกิดข้อผิดพลาดในการเชื่อมต่อ: ${e.message}');
    } catch (e) {
      throw ApiException('เกิดข้อผิดพลาดไม่ทราบสาเหตุ: $e');
    }
  }

  Future<List<TemplateModel>> getTemplates() async {
    try {
      return await _handleResponse(
        () => http.get(Uri.parse('$baseUrl/templates'), headers: _headers),
        (body) {
          final list = body as List<dynamic>;
          return list.map((e) => TemplateModel.fromJson(e as Map<String, dynamic>)).toList();
        },
      );
    } on ApiException {
      return TemplateModel.defaultTemplates;
    }
  }

  Future<String> createProject(String name, String templateId) async {
    return _handleResponse(
      () => http.post(
        Uri.parse('$baseUrl/projects'),
        headers: _headers,
        body: json.encode({'name': name, 'template_id': templateId}),
      ),
      (body) => body['project_id'] as String,
    );
  }

  Future<void> uploadImages(String projectId, List<File> images) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/projects/$projectId/images'),
    );
    for (final img in images) {
      request.files.add(await http.MultipartFile.fromPath('files', img.path));
      request.files.add(await http.MultipartFile.fromPath('images', img.path));
    }
    try {
      final streamed = await request.send().timeout(const Duration(minutes: 5));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        dynamic body;
        try {
          body = json.decode(utf8.decode(response.bodyBytes));
        } catch (_) {
          body = utf8.decode(response.bodyBytes);
        }
        throw ApiException(
          _extractErrorMessage(body, fallback: 'ไม่สามารถอัปโหลดรูปภาพได้'),
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('อัปโหลดรูปภาพล้มเหลว: $e');
    }
  }

  Future<void> uploadAudio(String projectId, File audio) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/projects/$projectId/audio'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', audio.path));
    request.files.add(await http.MultipartFile.fromPath('audio', audio.path));
    try {
      final streamed = await request.send().timeout(const Duration(minutes: 5));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        dynamic body;
        try {
          body = json.decode(utf8.decode(response.bodyBytes));
        } catch (_) {
          body = utf8.decode(response.bodyBytes);
        }
        throw ApiException(
          _extractErrorMessage(body, fallback: 'ไม่สามารถอัปโหลดไฟล์เสียงได้'),
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('อัปโหลดเสียงล้มเหลว: $e');
    }
  }

  Future<void> uploadScript(
    String projectId,
    String text,
    String lang, {
    String gender = 'female',
    String rate = '+0%',
  }) async {
    await _handleResponse(
      () => http.post(
        Uri.parse('$baseUrl/projects/$projectId/script'),
        headers: _headers,
        body: json.encode({
          'text': text,
          'lang': lang,
          'gender': gender,
          'rate': rate,
        }),
      ),
      (_) {},
    );
  }

  Future<String> startRender(
    String projectId, {
    bool useTts = false,
    bool exportMlt = true,
    bool useBlender = false,
    String blenderPath = 'blender',
    List<String> imageOrder = const [],
  }) async {
    return _handleResponse(
      () => http.post(
        Uri.parse('$baseUrl/render/$projectId'),
        headers: _headers,
        body: json.encode({
          'use_tts': useTts,
          'export_mlt': exportMlt,
          'use_blender': useBlender,
          'blender_path': blenderPath,
          'image_order': imageOrder,
        }),
      ),
      (body) => body['job_id'] as String,
    );
  }

  Future<RenderJob> getRenderStatus(String jobId) async {
    return _handleResponse(
      () => http.get(Uri.parse('$baseUrl/jobs/$jobId'), headers: _headers),
      (body) => RenderJob.fromJson(body as Map<String, dynamic>),
    );
  }

  Future<void> downloadFile(String jobId, String fileType, String savePath) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/jobs/$jobId/download/$fileType'))
          .timeout(const Duration(minutes: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await File(savePath).writeAsBytes(response.bodyBytes);
      } else {
        throw ApiException('ไม่สามารถดาวน์โหลดไฟล์ได้', statusCode: response.statusCode);
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('ดาวน์โหลดล้มเหลว: $e');
    }
  }

  Future<List<ProjectModel>> getProjects() async {
    try {
      return await _handleResponse(
        () => http.get(Uri.parse('$baseUrl/projects'), headers: _headers),
        (body) {
          final list = body as List<dynamic>;
          return list.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
        },
      );
    } on ApiException {
      return [];
    }
  }
}
