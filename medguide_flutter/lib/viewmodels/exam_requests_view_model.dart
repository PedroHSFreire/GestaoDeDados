import 'package:flutter/foundation.dart';

import '../models/exam_request.dart';
import '../services/api_client.dart';
import '../services/exam_request_service.dart';

class ExamRequestsViewModel extends ChangeNotifier {
  ExamRequestsViewModel(this.service);
  final ExamRequestService service;

  List<ExamRequest> requests = [];
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      requests = await service.listMine();
    } catch (exception) {
      error = ApiClient.messageFor(exception);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> create({required String patientId, required String examType, required String description}) async {
    try {
      await service.create(patientId: patientId, examType: examType, description: description);
      await load();
      return true;
    } catch (exception) {
      error = ApiClient.messageFor(exception);
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(ExamRequest request, String status) async {
    try {
      await service.update(request.id, status);
      await load();
      return true;
    } catch (exception) {
      error = ApiClient.messageFor(exception);
      notifyListeners();
      return false;
    }
  }
}
