import 'package:flutter/foundation.dart';

import '../models/medication.dart';
import '../services/api_client.dart';
import '../services/medication_service.dart';

class MedicationsViewModel extends ChangeNotifier {
  MedicationsViewModel(this.service);
  final MedicationService service;

  List<Medication> medications = [];
  List<PrescribedMedication> prescribedMedications = [];
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([service.list(), service.prescribed()]);
      medications = results[0] as List<Medication>;
      prescribedMedications = results[1] as List<PrescribedMedication>;
    } catch (exception) {
      error = ApiClient.messageFor(exception);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> create({required String name, String? dosage, required List<String> times}) async {
    try {
      await service.create(name: name, dosage: dosage, times: times);
      await load();
      return true;
    } catch (exception) {
      error = ApiClient.messageFor(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(Medication medication, Map<String, dynamic> changes) async {
    try {
      await service.update(medication.id, changes);
      await load();
      return true;
    } catch (exception) {
      error = ApiClient.messageFor(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(Medication medication) async {
    try {
      await service.delete(medication.id);
      medications.removeWhere((item) => item.id == medication.id);
      notifyListeners();
      return true;
    } catch (exception) {
      error = ApiClient.messageFor(exception);
      notifyListeners();
      return false;
    }
  }
}
