import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/api_client.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this.api);
  final ApiClient api;

  AppUser? user;
  bool loading = false;
  String? error;
  bool get isAuthenticated => user != null;

  Future<void> restoreSession() async {
    final token = await api.readToken();
    if (token == null) return;
    try {
      final profile = await api.get<Map<String, dynamic>>('/api/pacient/profile');
      user = AppUser.fromJson(profile.data!['data'] as Map<String, dynamic>);
    } catch (_) {
      try {
        final profile = await api.get<Map<String, dynamic>>('/api/doctor/profile');
        user = AppUser.fromJson(profile.data!['data'] as Map<String, dynamic>);
      } catch (_) {
        await api.clearToken();
      }
    }
  }

  Future<bool> login({required String role, required String login, required String password}) async {
    loading = true;
    error = null;
    notifyListeners();
    final route = role == 'doctor' ? '/api/doctor/login' : '/api/pacient/login';
    try {
      final response = await api.post<Map<String, dynamic>>(route, data: {
        'login': login.trim(),
        'password': password,
      });
      final data = response.data!['data'] as Map<String, dynamic>;
      await api.saveToken(data['token'] as String);
      user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
      return true;
    } catch (exception) {
      error = ApiClient.messageFor(exception);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String role,
    required String name,
    required String email,
    required String password,
    String? crm,
    String? specialty,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    final path = role == 'doctor' ? '/api/doctor/register' : '/api/pacient/register';
    try {
      final payload = <String, dynamic>{'name': name.trim(), 'email': email.trim(), 'password': password};
      if (role == 'doctor') {
        payload.addAll({'crm': crm!.trim(), 'specialty': specialty!.trim()});
      }
      await api.post<Map<String, dynamic>>(path, data: payload);
      return await login(role: role, login: email, password: password);
    } catch (exception) {
      error = ApiClient.messageFor(exception);
      loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await api.clearToken();
    user = null;
    error = null;
    notifyListeners();
  }

  Future<bool> updateProfile(Map<String, dynamic> changes) async {
    if (user == null) return false;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final path = user!.isDoctor ? '/api/doctor/profile' : '/api/pacient/profile';
      final response = await api.put<Map<String, dynamic>>(path, data: changes);
      user = AppUser.fromJson(response.data!['data'] as Map<String, dynamic>);
      return true;
    } catch (exception) {
      error = ApiClient.messageFor(exception);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
