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

  Future<Response<T>> patch<T>(String path, {Object? data}) async =>
      _dio.patch<T>(path, data: data, options: await _authorizedOptions());

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
      final status = error.response?.statusCode;
      if (status != null && status >= 500) return _statusMessage(status);
      final body = error.response?.data;
      if (body is Map) {
        final detail = _serverMessage(body['detail'] ?? body['error']);
        if (detail != null) return detail;
      }
      if (status != null) return _statusMessage(status);
      return switch (error.type) {
        DioExceptionType.connectionTimeout => 'A conexão demorou para responder. Verifique sua rede e tente novamente.',
        DioExceptionType.sendTimeout => 'O envio demorou mais que o esperado. Verifique sua conexão e tente novamente.',
        DioExceptionType.receiveTimeout => 'O servidor demorou para responder. Tente novamente em instantes.',
        DioExceptionType.transformTimeout => 'Não foi possível interpretar a resposta do serviço. Tente novamente.',
        DioExceptionType.connectionError => 'Não foi possível conectar ao serviço. Verifique a conexão com a internet e tente novamente.',
        DioExceptionType.badCertificate => 'A conexão segura não pôde ser validada. Verifique a configuração do serviço.',
        DioExceptionType.cancel => 'A solicitação foi cancelada.',
        DioExceptionType.badResponse => 'O serviço retornou uma resposta inesperada. Tente novamente.',
        DioExceptionType.unknown => 'Ocorreu um problema de comunicação. Tente novamente.',
      };
    }
    return 'Não foi possível concluir a solicitação. Tente novamente.';
  }

  static String? _serverMessage(Object? value) {
    if (value is Map) {
      final message = value['message'];
      final action = value['action'];
      if (message is String && message.trim().isNotEmpty) {
        final cleanMessage = message.trim();
        if (action is String && action.trim().isNotEmpty && action.trim() != cleanMessage) {
          return '$cleanMessage ${action.trim()}';
        }
        return cleanMessage;
      }
    }
    if (value is String && value.trim().isNotEmpty) {
      final message = value.trim();
      if (message.toLowerCase() == 'internal server error') return null;
      return message.length <= 240 ? message : '${message.substring(0, 237)}…';
    }
    if (value is List) {
      final fields = <String>{};
      const labels = <String, String>{
        'name': 'nome',
        'email': 'e-mail',
        'password': 'senha',
        'crm': 'CRM',
        'specialty': 'especialidade',
        'date_time': 'data e horário',
        'symptoms': 'motivo da consulta',
        'doctor_id': 'profissional',
        'medication_name': 'nome do medicamento',
        'medication_dosage': 'dosagem',
        'medication_frequency': 'frequência',
        'medication_duration': 'duração',
        'times': 'horários',
      };
      for (final item in value) {
        if (item is! Map) continue;
        final location = item['loc'];
        if (location is List && location.isNotEmpty) {
          final field = location.last.toString();
          if (labels.containsKey(field)) fields.add(labels[field]!);
        }
      }
      if (fields.isNotEmpty) return 'Confira estes campos: ${fields.join(', ')}.';
      return 'Alguns dados estão inválidos ou incompletos. Revise os campos e tente novamente.';
    }
    return null;
  }

  static String _statusMessage(int status) => switch (status) {
        400 => 'Não foi possível concluir a solicitação. Revise os dados informados.',
        401 => 'Sua sessão expirou ou os dados de acesso não conferem. Entre novamente.',
        403 => 'Seu perfil não tem permissão para esta ação.',
        404 => 'Este conteúdo não está mais disponível. Atualize a tela e tente novamente.',
        409 => 'Esta alteração conflita com um cadastro existente. Revise os dados e tente novamente.',
        413 => 'O arquivo excede o tamanho permitido. Escolha um arquivo menor.',
        415 => 'Formato de arquivo não compatível. Escolha uma imagem JPEG, PNG ou WEBP.',
        422 => 'Alguns dados estão inválidos ou incompletos. Revise os campos e tente novamente.',
        429 => 'Muitas solicitações em sequência. Aguarde um pouco e tente novamente.',
        503 => 'Este recurso está temporariamente indisponível. Tente novamente mais tarde.',
        _ => 'Não foi possível concluir a solicitação (código $status). Tente novamente.',
      };
}
