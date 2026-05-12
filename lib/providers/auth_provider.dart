import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  late final AuthService _authService;

  User? _user;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._apiService) {
    _authService = AuthService(_apiService);
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;
  String get role => _user?.role ?? '';
  AuthService get authService => _authService;
  ApiService get apiService => _apiService;

  /// Try to auto-login from stored token.
  Future<bool> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _authService.loadToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _user = await _authService.getMe();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      await _authService.clearToken();
      _user = null;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    String? fullName,
    String role = 'citizen',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.register(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
      );
      // Auto-login after registration
      await _authService.login(email: email, password: password);
      _user = await _authService.getMe();
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.login(email: email, password: password);
      _user = await _authService.getMe();
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.clearToken();
    _user = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
