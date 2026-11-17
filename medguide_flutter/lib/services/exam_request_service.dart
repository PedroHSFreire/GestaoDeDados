import '../models/exam_request.dart';
import 'api_client.dart';

class ExamRequestService {
  ExamRequestService(this.api);
  final ApiClient api;

  Future<List<ExamRequest>> listMine() async {
    final response = await api.get<Map<String, dynamic>>('/api/exams/me');
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data.map((item) => ExamRequest.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> create({required String patientId, required String examType, required String description}) async {
    await api.post('/api/exams', data: {'patient_id': patientId, 'exam_type': examType, 'description': description});
  }

  Future<void> update(String id, String status) async {
    await api.patch('/api/exams/$id', data: {'status': status});
  }
}
