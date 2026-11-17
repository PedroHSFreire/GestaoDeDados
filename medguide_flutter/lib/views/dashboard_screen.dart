import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/appointment_service.dart';
import '../services/privacy_service.dart';
import '../services/medication_service.dart';
import '../services/exam_request_service.dart';
import '../viewmodels/appointments_view_model.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/document_ingestion_view_model.dart';
import '../viewmodels/medications_view_model.dart';
import '../viewmodels/exam_requests_view_model.dart';
import 'appointments_screen.dart';
import 'document_ingestion_screen.dart';
import 'medications_screen.dart';
import 'profile_screen.dart';
import 'exam_requests_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _createdViewModels = false;
  late AppointmentsViewModel _appointments;
  late DocumentIngestionViewModel _documents;
  late MedicationsViewModel _medications;
  late ExamRequestsViewModel _exams;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_createdViewModels) return;
    final auth = context.read<AuthViewModel>();
    _appointments = AppointmentsViewModel(AppointmentService(auth.api));
    _documents = DocumentIngestionViewModel(PrivacyService(auth.api));
    _medications = MedicationsViewModel(MedicationService(auth.api));
    _exams = ExamRequestsViewModel(ExamRequestService(auth.api));
    _createdViewModels = true;
  }

  @override
  void dispose() {
    _appointments.dispose();
    _documents.dispose();
    _medications.dispose();
    _exams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final user = auth.user!;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _appointments),
        ChangeNotifierProvider.value(value: _documents),
        ChangeNotifierProvider.value(value: _medications),
        ChangeNotifierProvider.value(value: _exams),
      ],
      child: _DashboardScaffold(userIsDoctor: user.isDoctor),
    );
  }
}

class _DashboardScaffold extends StatefulWidget {
  const _DashboardScaffold({required this.userIsDoctor});
  final bool userIsDoctor;

  @override
  State<_DashboardScaffold> createState() => _DashboardScaffoldState();
}

class _DashboardScaffoldState extends State<_DashboardScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isPatient = !widget.userIsDoctor;
    final areaColor = isPatient ? const Color(0xFF087E8B) : const Color(0xFF465AA8);
    final areaBackground = isPatient ? const Color(0xFFE4F3F2) : const Color(0xFFECEFFD);
    final patient = !widget.userIsDoctor;
    final pages = <Widget>[
      AppointmentsScreen(patient: patient),
      if (patient) const MedicationsScreen(),
      const ExamRequestsScreen(),
      if (patient) const DocumentIngestionScreen(),
      const ProfileScreen(),
    ];
    final destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Consultas'),
      if (patient) const NavigationDestination(icon: Icon(Icons.medication_outlined), selectedIcon: Icon(Icons.medication), label: 'Medicamentos'),
      const NavigationDestination(icon: Icon(Icons.biotech_outlined), selectedIcon: Icon(Icons.biotech), label: 'Exames'),
      if (patient) const NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: 'Documentos'),
      const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.health_and_safety, color: Color(0xFF087E8B)),
          const SizedBox(width: 10),
          const Flexible(child: Text('MedGuide')),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(color: areaBackground, borderRadius: BorderRadius.circular(30)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isPatient ? Icons.person_outline : Icons.medical_services_outlined, size: 17, color: areaColor),
              const SizedBox(width: 6),
              Text(isPatient ? 'Área do Paciente' : 'Área do Médico', style: TextStyle(color: areaColor, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: 'Dúvidas frequentes',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Dúvidas frequentes'),
                content: const SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _FaqItem(question: 'Como faço login?', answer: 'Escolha seu perfil e entre com o e-mail e a senha cadastrados.'),
                    _FaqItem(question: 'Como agendo uma consulta?', answer: 'Na aba Consultas, toque em Agendar, selecione o profissional, a modalidade, data, horário e informe o motivo.'),
                    _FaqItem(question: 'Como organizo medicamentos?', answer: 'Cadastre o medicamento, dose e horários na aba Medicamentos. Nesta versão os horários ficam salvos para consulta, sem notificações do sistema.'),
                    _FaqItem(question: 'Como processo uma receita ou exame?', answer: 'Na aba Documentos, selecione uma imagem e confirme o consentimento. OCR real requer que a API tenha Tesseract e os idiomas configurados.'),
                    _FaqItem(question: 'Como os documentos são tratados?', answer: 'A sessão usa token da API. Somente o texto mascarado aprovado é armazenado. Use documentos fictícios ou autorizados e revise os resultados automáticos.'),
                  ]),
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fechar'))],
              ),
            ),
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: () => context.read<AuthViewModel>().logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: destinations,
        onDestinationSelected: (index) {
          setState(() => _index = index);
          if (destinations[index].label == 'Exames') {
            context.read<ExamRequestsViewModel>().load();
          }
          if (destinations[index].label == 'Medicamentos') {
            context.read<MedicationsViewModel>().load();
          }
        },
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600)),
        children: [Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(answer)))],
      );
}
