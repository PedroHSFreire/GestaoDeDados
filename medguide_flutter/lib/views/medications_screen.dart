import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medication.dart';
import '../viewmodels/medications_view_model.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<MedicationsViewModel>().load();
      });
    }
  }

  Future<void> _edit(MedicationsViewModel model, [Medication? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final dosage = TextEditingController(text: existing?.dosage ?? '');
    final times = [...?existing?.times];
    if (times.isEmpty) times.add('08:00');
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Novo medicamento' : 'Editar medicamento'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nome do medicamento'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: dosage, decoration: const InputDecoration(labelText: 'Dose (opcional)')),
                  const SizedBox(height: 20),
                  Text('Horários', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final time in times)
                      InputChip(
                        label: Text(time),
                        onDeleted: times.length <= 1 ? null : () => setDialogState(() => times.remove(time)),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Adicionar horário'),
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (picked != null) {
                          final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          if (!times.contains(value)) setDialogState(() => times.add(value));
                        }
                      },
                    ),
                  ]),
                  const SizedBox(height: 10),
                  const Text('Os horários ficam registrados no app. Notificações do sistema não estão habilitadas nesta versão.', style: TextStyle(fontSize: 12)),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final ok = existing == null
                    ? await model.create(name: name.text.trim(), dosage: dosage.text.trim().isEmpty ? null : dosage.text.trim(), times: times)
                    : await model.update(existing, {'name': name.text.trim(), 'dosage': dosage.text.trim(), 'times': times});
                if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    dosage.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MedicationsViewModel>();
    return RefreshIndicator(
      onRefresh: model.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: Text('Medicamentos', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
            FilledButton.tonalIcon(onPressed: () => _edit(model), icon: const Icon(Icons.add), label: const Text('Adicionar')),
          ]),
          const SizedBox(height: 6),
          const Text('Cadastre medicamentos, doses e horários para consultar sua rotina.'),
          const SizedBox(height: 16),
          if (model.error != null) Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(14), child: Text(model.error!))),
          if (model.loading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (model.medications.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('Você ainda não cadastrou medicamentos.')))
          else
            ...model.medications.map((medication) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.medication_outlined)),
                    title: Text(medication.name),
                    subtitle: Text([
                      if (!medication.active) 'Pausado',
                      if (medication.dosage != null && medication.dosage!.isNotEmpty) medication.dosage!,
                      'Horários: ${medication.times.join(', ')}',
                    ].join(' · ')),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'toggle') {
                          await model.update(medication, {'active': !medication.active});
                        } else if (action == 'edit') {
                          await _edit(model, medication);
                        } else if (action == 'delete' && context.mounted) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Remover medicamento?'),
                              content: Text('Remover ${medication.name} da sua lista?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
                                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remover')),
                              ],
                            ),
                          );
                          if (confirm == true) await model.delete(medication);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'toggle', child: Text(medication.active ? 'Pausar' : 'Ativar')),
                        const PopupMenuItem(value: 'edit', child: Text('Editar')),
                        const PopupMenuItem(value: 'delete', child: Text('Remover')),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
