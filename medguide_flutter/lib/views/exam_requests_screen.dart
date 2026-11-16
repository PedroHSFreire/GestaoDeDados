import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_view_model.dart';
import '../viewmodels/exam_requests_view_model.dart';

class ExamRequestsScreen extends StatefulWidget {
  const ExamRequestsScreen({super.key});

  @override
  State<ExamRequestsScreen> createState() => _ExamRequestsScreenState();
}

class _ExamRequestsScreenState extends State<ExamRequestsScreen> {
  bool _loaded = false;

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ExamRequestsViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ExamRequestsViewModel>();
    final isDoctor = context.watch<AuthViewModel>().user!.isDoctor;
    return RefreshIndicator(
      onRefresh: model.load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Solicitações de exames', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(isDoctor ? 'Acompanhe os exames solicitados durante consultas.' : 'Consulte a situação dos exames solicitados pelo profissional.'),
        const SizedBox(height: 18),
        if (model.error != null) Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(14), child: Text(model.error!))),
        if (model.loading)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else if (model.requests.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('Nenhuma solicitação de exame encontrada.')))
        else
          ...model.requests.map((request) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.biotech_outlined, color: Color(0xFF087E8B)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(request.examType, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                      Chip(label: Text(request.status)),
                    ]),
                    if (isDoctor && request.patientName != null) Text('Paciente: ${request.patientName}'),
                    if (!isDoctor && request.doctorName != null) Text('Profissional: ${request.doctorName}'),
                    Text('Solicitado em ${_formatDate(request.requestDate)}'),
                    if (request.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(request.description)),
                    if (request.status == 'pendente')
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(spacing: 8, children: [
                          if (isDoctor)
                            OutlinedButton(onPressed: () => model.update(request, 'cancelado'), child: const Text('Cancelar')),
                          if (isDoctor)
                            FilledButton.tonal(onPressed: () => model.update(request, 'concluido'), child: const Text('Marcar concluído')),
                          if (!isDoctor)
                            OutlinedButton(onPressed: () => model.update(request, 'cancelado'), child: const Text('Cancelar solicitação')),
                        ]),
                      ),
                  ]),
                ),
              )),
      ]),
    );
  }
}
