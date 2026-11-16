import '../models/appointment.dart';
import 'api_client.dart';

class AppointmentService {
  AppointmentService(this.api);
  final ApiClient api;

  Future<List<Appointment>> mine() async {
    final response = await api.get<Map<String, dynamic>>('/api/appointments/mine');
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data.map((item) => Appointment.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<DoctorSummary>> doctors() async {
    final response = await api.get<Map<String, dynamic>>('/api/doctor/search');
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    return data.map((item) => DoctorSummary.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> create({required String doctorId, required DateTime dateTime, required String type, required String symptoms, String? notes}) async {
    await api.post('/api/appointments', data: {
      'doctor_id': doctorId,
      'date_time': dateTime.toUtc().toIso8601String(),
      'type': type,
      'symptoms': symptoms,
      'notes': notes,
    });
  }

  Future<void> update(String id, Map<String, dynamic> changes) async {
    await api.put('/api/appointments/$id', data: changes);
  }
}
