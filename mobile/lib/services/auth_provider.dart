import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';

// Manajemen state autentikasi
class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;
  User? _user;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get user => _user;

  // Cek token tersimpan saat app mulai
  Future<void> checkLogin() async {
    final token = await ApiService.getToken();
    _isLoggedIn = token != null && token.isNotEmpty;
    if (_isLoggedIn) {
      try {
        final res = await ApiService.getProfile();
        if (res['user'] != null) {
          _user = User.fromJson(res['user'] as Map<String, dynamic>);
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? displayName,
    String? currentPassword,
    String? newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiService.updateProfile(
        displayName: displayName,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (res['user'] != null) {
        _user = User.fromJson(res['user'] as Map<String, dynamic>);
      }
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.login(username, password);
      await ApiService.saveToken(data['token'] as String);
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
      _isLoggedIn = true;
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(
    String username,
    String password,
    String displayName,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data =
          await ApiService.register(username, password, displayName);
      await ApiService.saveToken(data['token'] as String);
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
      _isLoggedIn = true;
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    _isLoggedIn = false;
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
