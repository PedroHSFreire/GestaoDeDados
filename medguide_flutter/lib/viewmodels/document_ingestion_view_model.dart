import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../services/privacy_service.dart';

class DocumentIngestionViewModel extends ChangeNotifier {
  DocumentIngestionViewModel(this.service);
  final PrivacyService service;

  bool loading = false;
  String? error;
  Map<String, dynamic>? result;
  List<Map<String, dynamic>> documents = [];

  Future<void> loadDocuments() async {
    try {
      documents = await service.documents();
      error = null;
    } catch (exception) {
      error = ApiClient.messageFor(exception);
    }
    notifyListeners();
  }

  Future<void> processImage(XFile file, String documentType) async {
    loading = true;
    error = null;
    result = null;
    notifyListeners();
    try {
      final source = await file.readAsBytes();
      if (source.length > 20 * 1024 * 1024) {
        throw const FormatException('Escolha uma imagem de até 20 MB');
      }
      final decoded = img.decodeImage(source);
      if (decoded == null) throw const FormatException('Formato de imagem inválido');
      final oriented = img.bakeOrientation(decoded);
      // Re-encoding pixels creates a new file without EXIF/GPS metadata.
      final sanitized = img.encodePng(oriented, level: 6);
      if (sanitized.length > 8 * 1024 * 1024) {
        throw const FormatException('A imagem processada excede o limite de 8 MB');
      }
      result = await service.ingestImage(
        sanitizedImage: sanitized,
        mimeType: 'image/png',
        documentType: documentType,
      );
      if (result?['decision'] == 'approved') await loadDocuments();
    } catch (exception) {
      error = exception is FormatException ? exception.message : ApiClient.messageFor(exception);
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
