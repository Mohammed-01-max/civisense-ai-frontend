import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';

class ApiService {
  String? _token;
  void Function()? onUnauthorized;

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

  void _checkResponse(http.Response response) {
    if (response.statusCode == 401) {
      if (onUnauthorized != null) {
        onUnauthorized!();
      }
      throw Exception('session_expired');
    }
    if (response.statusCode >= 500) {
      throw Exception('CiviSense is temporarily unavailable. Please try again.');
    }
  }

  Future<T> _executeRequest<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on http.ClientException {
      throw Exception('Unable to connect to CiviSense. Please check your connection.');
    } catch (e) {
      if (e.toString() == 'Exception: session_expired') {
        rethrow;
      }
      if (e.toString().contains('temporarily unavailable')) {
        rethrow;
      }
      throw Exception('An unexpected error occurred: ' + e.toString());
    }
  }

  Future<http.Response> get(String endpoint, {Map<String, String>? queryParams}) async {
    return await _executeRequest(() async {
      final uri = Uri.parse('${ApiConfig.baseUrl}' + endpoint).replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);
      _checkResponse(response);
      return response;
    });
  }

  Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) async {
    return await _executeRequest(() async {
      final uri = Uri.parse('${ApiConfig.baseUrl}' + endpoint);
      final response = await http.post(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      _checkResponse(response);
      return response;
    });
  }

  Future<http.Response> postForm(String endpoint, {required Map<String, String> body}) async {
    return await _executeRequest(() async {
      final uri = Uri.parse('${ApiConfig.baseUrl}' + endpoint);
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          if (_token != null) 'Authorization': 'Bearer ' + _token!,
        },
        body: body,
      );
      _checkResponse(response);
      return response;
    });
  }

  Future<http.Response> patch(String endpoint, {Map<String, dynamic>? body}) async {
    return await _executeRequest(() async {
      final uri = Uri.parse('${ApiConfig.baseUrl}' + endpoint);
      final response = await http.patch(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      _checkResponse(response);
      return response;
    });
  }

  Future<http.StreamedResponse> postMultipart(
    String endpoint, {
    required Uint8List fileBytes,
    required String fileName,
    required Map<String, String> fields,
  }) async {
    return await _executeRequest(() async {
      final uri = Uri.parse('${ApiConfig.baseUrl}' + endpoint);
      final request = http.MultipartRequest('POST', uri);

      if (_token != null) {
        request.headers['Authorization'] = 'Bearer ' + _token!;
      }

      request.fields.addAll(fields);

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

      final response = await request.send();
      if (response.statusCode == 401) {
        if (onUnauthorized != null) {
          onUnauthorized!();
        }
        throw Exception('session_expired');
      }
      if (response.statusCode >= 500) {
        throw Exception('CiviSense is temporarily unavailable. Please try again.');
      }
      return response;
    });
  }
}
