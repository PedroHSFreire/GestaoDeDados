import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../viewmodels/document_ingestion_view_model.dart';

class DocumentIngestionScreen extends StatefulWidget {
  const DocumentIngestionScreen({super.key});

  @override
  State<DocumentIngestionScreen> createState() => _DocumentIngestionScreenState();
}

class _DocumentIngestionScreenState extends State<DocumentIngestionScreen> {
  final _picker = ImagePicker();
  bool _consent = false;
  String _documentType = 'receita';
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<DocumentIngestionViewModel>().loadDocuments();
      });
    }
  }

  bool get _cameraAvailable => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _chooseImage(ImageSource source, DocumentIngestionViewModel model) async {
    if (!_consent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leia e aceite o aviso de privacidade antes de enviar.')));
      return;
    }
    try {
      final image = await _picker.pickImage(source: source, requestFullMetadata: false);
      if (image != null && mounted) await model.processImage(image, _documentType);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível acessar a imagem. Verifique o formato e as permissões e tente novamente.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<DocumentIngestionViewModel>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Proteção de documentos', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Envie uma imagem de receita, exame ou laudo para extração e mascaramento de dados identificadores.'),
        const SizedBox(height: 16),
        Card(
          color: const Color(0xFFEAF5F4),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.shield_outlined), SizedBox(width: 8), Text('Como os dados são tratados', style: TextStyle(fontWeight: FontWeight.bold))]),
              SizedBox(height: 8),
              Text('O aplicativo reprocessa os pixels da imagem antes do envio para remover metadados EXIF. A API faz OCR, NER e mascaramento em memória. Apenas o texto aprovado e mascarado pode ser gravado; a imagem original e o texto bruto não são armazenados.'),
              SizedBox(height: 8),
              Text('Utilize apenas documentos autorizados e revise cuidadosamente o texto mascarado. A detecção automática pode falhar e não substitui a análise profissional.', style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _documentType,
          decoration: const InputDecoration(labelText: 'Tipo de documento'),
          items: const [
            DropdownMenuItem(value: 'receita', child: Text('Receita')),
            DropdownMenuItem(value: 'exame', child: Text('Exame')),
            DropdownMenuItem(value: 'laudo', child: Text('Laudo')),
          ],
          onChanged: model.loading ? null : (value) => setState(() => _documentType = value ?? 'receita'),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consent,
          onChanged: model.loading ? null : (value) => setState(() => _consent = value ?? false),
          title: const Text('Autorizo o processamento temporário desta imagem para extração e mascaramento.'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: model.loading ? null : () => _chooseImage(ImageSource.gallery, model),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Escolher imagem'),
        ),
        if (_cameraAvailable) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: model.loading ? null : () => _chooseImage(ImageSource.camera, model),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Capturar com câmera'),
          ),
        ],
        if (model.loading) ...[
          const SizedBox(height: 20),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text('Processando a imagem sem salvá-la no servidor...'),
        ],
        if (model.error != null) _ResultCard(error: model.error!),
        if (model.result != null) _IngestionResultCard(result: model.result!),
        const SizedBox(height: 20),
        Text('Textos mascarados aprovados', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (model.documents.isEmpty && !model.loading)
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Nenhum documento mascarado armazenado.'))),
        ...model.documents.map((document) => Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${document['document_type']} · risco ${document['risk_score']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SelectableText(document['masked_text'] as String? ?? ''),
                ]),
              ),
            )),
      ],
    );
  }
}

class _IngestionResultCard extends StatelessWidget {
  const _IngestionResultCard({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final approved = result['decision'] == 'approved';
    final title = switch (result['decision']) {
      'approved' => 'Aprovado pelo Gatekeeper',
      'review' => 'Revisão necessária',
      _ => 'Bloqueado pelo Gatekeeper',
    };
    return Card(
      color: approved ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(approved ? Icons.verified_outlined : Icons.warning_amber_rounded), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)))]),
          const SizedBox(height: 8),
          Text(result['message'] as String? ?? ''),
          Text('Risco residual: ${result['risk_score']} · confiança OCR: ${result['ocr_confidence']}'),
          if ((result['findings'] as List<dynamic>? ?? []).isNotEmpty)
            Text('Categorias tratadas: ${(result['findings'] as List<dynamic>).join(', ')}'),
          if (result['masked_text'] is String) ...[
            const Divider(height: 24),
            const Text('Texto após mascaramento', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SelectableText(result['masked_text'] as String),
          ],
        ]),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.error});
  final String error;
  @override
  Widget build(BuildContext context) => Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(14), child: Text(error, style: TextStyle(color: Colors.red.shade900))));
}
