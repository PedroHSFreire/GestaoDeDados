import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../viewmodels/appointments_view_model.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/exam_requests_view_model.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key, required this.patient});
  final bool patient;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  bool _loaded = false;
  int _patientTab = 0;
  String _doctorQuery = '';
  String? _specialty;
  String? _status;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppointmentsViewModel>().load(patient: widget.patient);
    });
  }

  Future<void> _newAppointment(AppointmentsViewModel model, [DoctorSummary? preferredDoctor]) async {
    if (model.doctors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não há profissionais cadastrados para agendamento.')));
      return;
    }
    final symptoms = TextEditingController();
    final notes = TextEditingController();
    String doctorId = preferredDoctor?.id ?? model.doctors.first.id;
    String appointmentType = 'online';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text('Agendar consulta', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: doctorId,
                decoration: const InputDecoration(labelText: 'Profissional'),
                items: model.doctors.map((doctor) => DropdownMenuItem(value: doctor.id, child: Text('${doctor.name} · ${doctor.specialty}', overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (value) => setSheetState(() => doctorId = value ?? doctorId),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: appointmentType,
                decoration: const InputDecoration(labelText: 'Modalidade'),
                items: const [
                  DropdownMenuItem(value: 'online', child: Text('Online')),
                  DropdownMenuItem(value: 'presencial', child: Text('Presencial')),
                  DropdownMenuItem(value: 'domiciliar', child: Text('Domiciliar')),
                  DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
                ],
                onChanged: (value) => setSheetState(() => appointmentType = value ?? 'online'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (date != null) setSheetState(() => selectedDate = date);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text('${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}'),
                )),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () async {
                    final time = await showTimePicker(context: context, initialTime: selectedTime);
                    if (time != null) setSheetState(() => selectedTime = time);
                  },
                  icon: const Icon(Icons.schedule),
                  label: Text(selectedTime.format(context)),
                )),
              ]),
              const SizedBox(height: 12),
              TextField(controller: symptoms, minLines: 2, maxLines: 4, maxLength: 3000, decoration: const InputDecoration(labelText: 'Sintomas / motivo da consulta', alignLabelWithHint: true)),
              const SizedBox(height: 8),
              TextField(controller: notes, minLines: 1, maxLines: 3, maxLength: 3000, decoration: const InputDecoration(labelText: 'Observações (opcional)', alignLabelWithHint: true)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  if (symptoms.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o motivo da consulta.')));
                    return;
                  }
                  final dateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                  if (dateTime.isBefore(DateTime.now())) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha uma data e horário futuros.')));
                    return;
                  }
                  final ok = await model.create(doctorId: doctorId, dateTime: dateTime, type: appointmentType, symptoms: symptoms.text.trim(), notes: notes.text.trim().isEmpty ? null : notes.text.trim());
                  if (ok && sheetContext.mounted) Navigator.of(sheetContext).pop();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(model.error ?? 'Não foi possível agendar a consulta. Tente novamente.')));
                  }
                },
                child: const Text('Enviar solicitação'),
              ),
            ]),
          ),
        ),
      ),
    );
    symptoms.dispose();
    notes.dispose();
  }

  Future<void> _editClinicalRecord(Appointment appointment, AppointmentsViewModel model) async {
    final diagnosis = TextEditingController(text: appointment.diagnosis ?? '');
    final medicationName = TextEditingController(text: appointment.medicationName ?? '');
    final medicationDosage = TextEditingController(text: appointment.medicationDosage ?? '');
    final medicationFrequency = TextEditingController(text: appointment.medicationFrequency ?? '');
    final medicationDuration = TextEditingController(text: appointment.medicationDuration ?? '');
    final medicationNotes = TextEditingController(text: appointment.medicationNotes ?? '');
    final doctorNotes = TextEditingController(text: appointment.doctorNotes ?? '');
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registro clínico'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: diagnosis, maxLines: 3, decoration: const InputDecoration(labelText: 'Diagnóstico')),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: Text('Prescrição de medicação (opcional)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            const SizedBox(height: 8),
            TextFormField(controller: medicationName, decoration: const InputDecoration(labelText: 'Medicamento')),
            const SizedBox(height: 10),
            TextFormField(controller: medicationDosage, decoration: const InputDecoration(labelText: 'Dosagem')),
            const SizedBox(height: 10),
            TextFormField(controller: medicationFrequency, decoration: const InputDecoration(labelText: 'Frequência')),
            const SizedBox(height: 10),
            TextFormField(controller: medicationDuration, decoration: const InputDecoration(labelText: 'Duração')),
            const SizedBox(height: 10),
            TextFormField(controller: medicationNotes, maxLines: 2, decoration: const InputDecoration(labelText: 'Orientações / observações')),
            const SizedBox(height: 12),
            TextField(controller: doctorNotes, maxLines: 3, decoration: const InputDecoration(labelText: 'Observações do profissional')),
          ])),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final medicationDetails = [medicationDosage, medicationFrequency, medicationDuration, medicationNotes]
                  .any((field) => field.text.trim().isNotEmpty);
              if (medicationDetails && medicationName.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o nome do medicamento ou limpe os campos da prescrição.')));
                return;
              }
              final ok = await model.update(appointment.id, {
                'diagnosis': diagnosis.text.trim(),
                'prescription': '',
                'medication_name': medicationName.text.trim(),
                'medication_dosage': medicationDosage.text.trim(),
                'medication_frequency': medicationFrequency.text.trim(),
                'medication_duration': medicationDuration.text.trim(),
                'medication_notes': medicationNotes.text.trim(),
                'doctor_notes': doctorNotes.text.trim(),
              }, patient: false);
              if (ok && mounted && dialogContext.mounted) {
                Navigator.pop(dialogContext);
                messenger.showSnackBar(const SnackBar(content: Text('Prontuário salvo e consulta atualizada.')));
              }
              if (!ok && dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(model.error ?? 'Não foi possível salvar o registro clínico. Tente novamente.')));
              }
            },
            child: const Text('Salvar prontuário'),
          ),
        ],
      ),
    );
    diagnosis.dispose();
    medicationName.dispose();
    medicationDosage.dispose();
    medicationFrequency.dispose();
    medicationDuration.dispose();
    medicationNotes.dispose();
    doctorNotes.dispose();
  }

  Future<void> _requestExam(Appointment appointment, ExamRequestsViewModel model) async {
    if (appointment.patientId == null || appointment.patientId!.isEmpty) return;
    final examType = TextEditingController();
    final description = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Solicitar exame para ${appointment.patientName ?? 'paciente'}'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: examType, decoration: const InputDecoration(labelText: 'Tipo de exame'), validator: (value) => value == null || value.trim().length < 2 ? 'Informe o exame' : null),
              const SizedBox(height: 12),
              TextFormField(controller: description, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Orientações (opcional)')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final ok = await model.create(patientId: appointment.patientId!, examType: examType.text.trim(), description: description.text.trim());
              if (ok && mounted && dialogContext.mounted) {
                Navigator.pop(dialogContext);
                messenger.showSnackBar(const SnackBar(content: Text('Solicitação de exame enviada ao paciente.')));
              }
              if (!ok && dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(model.error ?? 'Não foi possível solicitar o exame. Tente novamente.')));
              }
            },
            child: const Text('Enviar solicitação'),
          ),
        ],
      ),
    );
    examType.dispose();
    description.dispose();
  }

  Widget _buildDoctors(AppointmentsViewModel model) {
    final specialties = model.doctors.map((doctor) => doctor.specialty).where((item) => item.isNotEmpty).toSet().toList()..sort();
    final doctors = model.doctors.where((doctor) {
      final query = _doctorQuery.toLowerCase().trim();
      return (query.isEmpty || doctor.name.toLowerCase().contains(query) || doctor.specialty.toLowerCase().contains(query)) && (_specialty == null || doctor.specialty == _specialty);
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Buscar profissional ou especialidade'),
        onChanged: (value) => setState(() => _doctorQuery = value),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String?>(
        initialValue: _specialty,
        decoration: const InputDecoration(labelText: 'Filtrar especialidade'),
        items: [const DropdownMenuItem<String?>(value: null, child: Text('Todas')), ...specialties.map((item) => DropdownMenuItem<String?>(value: item, child: Text(item)))],
        onChanged: (value) => setState(() => _specialty = value),
      ),
      const SizedBox(height: 14),
      if (doctors.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Nenhum profissional encontrado.')))
      else
        ...doctors.map((doctor) => Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.medical_services_outlined)),
                title: Text(doctor.name),
                subtitle: Text([
                  doctor.specialty,
                  if (doctor.crm != null) 'CRM ${doctor.crm}',
                  if (doctor.address?.isNotEmpty == true) doctor.address!,
                ].join(' · ')),
                isThreeLine: true,
                trailing: IconButton(tooltip: 'Agendar consulta', onPressed: model.loading ? null : () => _newAppointment(model, doctor), icon: const Icon(Icons.calendar_month)),
              ),
            )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppointmentsViewModel>();
    final exams = context.watch<ExamRequestsViewModel>();
    final user = context.watch<AuthViewModel>().user!;
    final filteredAppointments = model.appointments.where((item) => _status == null || item.status == _status).toList();
    return RefreshIndicator(
      onRefresh: () => model.load(patient: widget.patient),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: Text('Olá, ${user.name.split(' ').first}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
            if (widget.patient && _patientTab == 1) FilledButton.tonalIcon(onPressed: model.loading ? null : () => _newAppointment(model), icon: const Icon(Icons.add), label: const Text('Agendar')),
          ]),
          const SizedBox(height: 6),
          Text(widget.patient ? 'Encontre profissionais e acompanhe suas consultas.' : 'Gerencie consultas e registros clínicos dos pacientes.'),
          const SizedBox(height: 16),
          if (widget.patient)
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Profissionais'), icon: Icon(Icons.search)),
                ButtonSegment(value: 1, label: Text('Minhas consultas'), icon: Icon(Icons.calendar_month)),
              ],
              selected: {_patientTab},
              onSelectionChanged: (selection) => setState(() => _patientTab = selection.first),
            ),
          const SizedBox(height: 14),
          if (model.error != null) _ErrorCard(message: model.error!),
          if (model.loading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (widget.patient && _patientTab == 0)
            _buildDoctors(model)
          else ...[
            if (!widget.patient || model.appointments.isNotEmpty)
              Wrap(spacing: 8, children: [
                for (final entry in const [(null, 'Todas'), ('agendada', 'Pendentes'), ('confirmada', 'Confirmadas'), ('remarcada', 'Remarcadas'), ('cancelada', 'Canceladas'), ('realizada', 'Realizadas')])
                  ChoiceChip(
                    label: Text('${entry.$2} (${entry.$1 == null ? model.appointments.length : model.appointments.where((item) => item.status == entry.$1).length})'),
                    selected: _status == entry.$1,
                    onSelected: (_) => setState(() => _status = entry.$1),
                  ),
              ]),
            const SizedBox(height: 8),
            if (filteredAppointments.isEmpty)
              _EmptyCard(message: widget.patient ? 'Nenhuma consulta encontrada.' : 'Nenhuma consulta nesta categoria.')
            else
              ...filteredAppointments.map((appointment) => _AppointmentCard(
                    appointment: appointment,
                    patient: widget.patient,
                    onUpdate: (changes) => model.update(appointment.id, changes, patient: widget.patient),
                    onClinicalRecord: () => _editClinicalRecord(appointment, model),
                    onRequestExam: () => _requestExam(appointment, exams),
                  )),
          ],
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment, required this.patient, required this.onUpdate, required this.onClinicalRecord, required this.onRequestExam});
  final Appointment appointment;
  final bool patient;
  final Future<bool> Function(Map<String, dynamic>) onUpdate;
  final VoidCallback onClinicalRecord;
  final VoidCallback onRequestExam;

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.medical_services_outlined, color: Color(0xFF087E8B)),
              const SizedBox(width: 10),
              Expanded(child: Text(patient ? (appointment.doctorName ?? appointment.specialty ?? 'Consulta') : (appointment.patientName ?? 'Paciente'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
              Chip(label: Text(appointment.status)),
            ]),
            const SizedBox(height: 10),
            Text(_formatDate(appointment.dateTime)),
            Text('Modalidade: ${appointment.type}'),
            Text('Motivo: ${appointment.symptoms}'),
            if (appointment.notes?.isNotEmpty == true) Text('Observações: ${appointment.notes}'),
            if (appointment.diagnosis?.isNotEmpty == true) Text('Diagnóstico: ${appointment.diagnosis}'),
            if (appointment.prescription?.isNotEmpty == true) Text('Prescrição: ${appointment.prescription}'),
            if (appointment.medicationName?.isNotEmpty == true) ...[
              const Divider(height: 22),
              Text('Medicação prescrita: ${appointment.medicationName}', style: const TextStyle(fontWeight: FontWeight.w600)),
              if (appointment.medicationDosage?.isNotEmpty == true) Text('Dosagem: ${appointment.medicationDosage}'),
              if (appointment.medicationFrequency?.isNotEmpty == true) Text('Frequência: ${appointment.medicationFrequency}'),
              if (appointment.medicationDuration?.isNotEmpty == true) Text('Duração: ${appointment.medicationDuration}'),
              if (appointment.medicationNotes?.isNotEmpty == true) Text('Orientações: ${appointment.medicationNotes}'),
            ],
            if (appointment.doctorNotes?.isNotEmpty == true) Text('Observações do profissional: ${appointment.doctorNotes}'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (patient && appointment.status == 'agendada') OutlinedButton(onPressed: () => onUpdate({'status': 'cancelada'}), child: const Text('Cancelar solicitação')),
              if (!patient && appointment.status == 'agendada') FilledButton.tonal(onPressed: () => onUpdate({'status': 'confirmada'}), child: const Text('Confirmar')),
              if (!patient && appointment.status == 'agendada') TextButton(onPressed: () => onUpdate({'status': 'cancelada'}), child: const Text('Recusar')),
              if (!patient && appointment.status == 'confirmada') FilledButton.tonal(onPressed: () => onUpdate({'status': 'realizada'}), child: const Text('Concluir consulta')),
              if (!patient && (appointment.status == 'confirmada' || appointment.status == 'realizada')) OutlinedButton.icon(onPressed: onClinicalRecord, icon: const Icon(Icons.note_alt_outlined), label: const Text('Prontuário')),
              if (!patient && (appointment.status == 'confirmada' || appointment.status == 'realizada')) OutlinedButton.icon(onPressed: onRequestExam, icon: const Icon(Icons.biotech_outlined), label: const Text('Solicitar exame')),
            ]),
          ]),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(16), child: Text(message, style: TextStyle(color: Colors.red.shade900))));
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [const Icon(Icons.event_available_outlined, size: 36), const SizedBox(height: 10), Text(message)])));
}
