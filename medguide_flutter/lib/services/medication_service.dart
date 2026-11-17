import '../models/medication.dart';
import 'api_client.dart';

class MedicationService {
  MedicationService(this.api);
  final ApiClient api;

  Future<List<Medication>> list() async {
    final response = await api.get<Map<String, dynamic>>('/api/medications');
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data.map((item) => Medication.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<PrescribedMedication>> prescribed() async {
    final response = await api.get<Map<String, dynamic>>('/api/medications/prescribed');
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data.map((item) => PrescribedMedication.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Medication> create({required String name, String? dosage, required List<String> times}) async {
    final response = await api.post<Map<String, dynamic>>('/api/medications', data: {
      'name': name,
      'dosage': dosage,
      'times': times,
      'active': true,
      'timezone': 'America/Sao_Paulo',
    });
    return Medication.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<void> update(String id, Map<String, dynamic> changes) async {
    await api.patch('/api/medications/$id', data: changes);
  }

  Future<void> delete(String id) async {
    await api.delete('/api/medications/$id');
  }
}
