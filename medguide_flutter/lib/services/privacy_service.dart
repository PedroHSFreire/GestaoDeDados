import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'api_client.dart';

class PrivacyService {
  PrivacyService(this.api);
  final ApiClient api;

  Future<Map<String, dynamic>> ingestImage({required List<int> sanitizedImage, required String mimeType, required String documentType}) async {
    final response = await api.post<Map<String, dynamic>>(
      '/api/privacy/ingest?document_type=$documentType',
      data: Uint8List.fromList(sanitizedImage),
      options: Options(
        contentType: mimeType,
        headers: {
          'X-Privacy-Consent': 'true',
        },
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> documents() async {
    final response = await api.get<Map<String, dynamic>>('/api/privacy/documents');
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data.cast<Map<String, dynamic>>();
  }
}
