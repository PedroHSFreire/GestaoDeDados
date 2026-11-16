import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import '../services/api_client.dart';
import '../services/appointment_service.dart';

class AppointmentsViewModel extends ChangeNotifier {
  AppointmentsViewModel(this.service);
  final AppointmentService service;

  List<Appointment> appointments = [];
  List<DoctorSummary> doctors = [];
  bool loading = false;
  String? error;

  Future<void> load({required bool patient}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      appointments = await service.mine();
      doctors = patient ? await service.doctors() : [];
    } catch (exception) {
      error = ApiClient.messageFor(exception);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> create({required String doctorId, required DateTime dateTime, required String type, required String symptoms, String? notes}) async {
    try {
      await service.create(doctorId: doctorId, dateTime: dateTime, type: type, symptoms: symptoms, notes: notes);
      await load(patient: true);
      return true;
    } catch (exception) {
      error = ApiClient.messageFor(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(String id, Map<String, dynamic> changes, {required bool patient}) async {
    try {
      await service.update(id, changes);
      await load(patient: patient);
      return true;
    } catch (exception) {
      error = ApiClient.messageFor(exception);
      notifyListeners();
      return false;
    }
  }
}
