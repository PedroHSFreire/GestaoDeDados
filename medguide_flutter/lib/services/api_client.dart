import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  ApiClient({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(BaseOptions(
          baseUrl: const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://127.0.0.1:8000',
          ),
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
          headers: {'Accept': 'application/json'},
        )),
        _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) => _storage.write(key: 'access_token', value: token);
  Future<String?> readToken() => _storage.read(key: 'access_token');
  Future<void> clearToken() => _storage.delete(key: 'access_token');

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async =>
      _dio.get<T>(path, queryParameters: query, options: await _authorizedOptions());

  Future<Response<T>> post<T>(String path, {Object? data, Options? options}) async =>
      _dio.post<T>(path, data: data, options: await _authorizedOptions(options));

  Future<Response<T>> put<T>(String path, {Object? data}) async =>
      _dio.put<T>(path, data: data, options: await _authorizedOptions());

  Future<Response<T>> delete<T>(String path) async =>
      _dio.delete<T>(path, options: await _authorizedOptions());

  Future<Options> _authorizedOptions([Options? base]) async {
    final token = await readToken();
    final headers = <String, dynamic>{...?base?.headers};
    if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    return (base ?? Options()).copyWith(headers: headers);
  }

  static String messageFor(Object error) {
    if (error is DioException) {
      final body = error.response?.data;
      if (body is Map && body['detail'] is String) return body['detail'] as String;
      if (body is Map && body['error'] is String) return body['error'] as String;
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Não foi possível conectar à API. Verifique o servidor e a URL configurada.';
      }
    }
    return 'Não foi possível concluir a solicitação. Tente novamente.';
  }
}
