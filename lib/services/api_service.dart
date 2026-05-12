import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';

class ApiService {
  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  String? get token => _token;

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<http.Response> get(String endpoint, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint').replace(queryParameters: queryParams);
    return await http.get(uri, headers: _headers);
  }

  Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    return await http.post(
      uri,
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> postForm(String endpoint, {required Map<String, String> body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    return await http.post(
      uri,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
      body: body,
    );
  }

  Future<http.Response> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    return await http.patch(
      uri,
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.StreamedResponse> postMultipart(
    String endpoint, {
    required Uint8List fileBytes,
    required String fileName,
    required Map<String, String> fields,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final request = http.MultipartRequest('POST', uri);

    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    request.fields.addAll(fields);

    // Determine content type from extension
    String mimeType = 'image/jpeg';
    final ext = fileName.toLowerCase().split('.').last;
    if (ext == 'png') {
      mimeType = 'image/png';
    } else if (ext == 'gif') {
      mimeType = 'image/gif';
    } else if (ext == 'webp') {
      mimeType = 'image/webp';
    }

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: MediaType.parse(mimeType),
    ));

    return await request.send();
  }
}
