import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api;

  AuthService(this._api);

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    _api.setToken(token);
  }

  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      _api.setToken(token);
    }
    return token;
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    _api.setToken(null);
  }

  /// Register a new user. Returns the created User on success.
  Future<User> register({
    required String email,
    required String password,
    required String jurisdiction,
    String? fullName,
  }) async {
    final response = await _api.post(ApiConfig.register, body: {
      'email': email,
      'password': password,
      'jurisdiction': jurisdiction,
      if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
    });

    if (response.statusCode == 201) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Registration failed');
    }
  }

  /// Login with email and password. Returns the JWT access token.
  /// The backend expects OAuth2 form-urlencoded with `username` field = email.
  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.postForm(ApiConfig.login, body: {
      'username': email,
      'password': password,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'] as String;
      await saveToken(token);
      return token;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Login failed');
    }
  }

  /// Get the current authenticated user's profile.
  Future<User> getMe() async {
    final response = await _api.get(ApiConfig.me);

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch user profile');
    }
  }
}
