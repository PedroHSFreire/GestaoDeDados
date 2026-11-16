import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_view_model.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _crm = TextEditingController();
  final _specialty = TextEditingController();
  String _role = 'patient';
  bool _registering = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _crm.dispose();
    _specialty.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthViewModel auth) async {
    if (!_formKey.currentState!.validate()) return;
    bool success;
    if (_registering) {
      success = await auth.register(
        role: _role,
        name: _name.text,
        email: _email.text,
        password: _password.text,
        crm: _crm.text,
        specialty: _specialty.text,
      );
    } else {
      success = await auth.login(role: _role, login: _email.text, password: _password.text);
    }
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Não foi possível entrar.')));
    }
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '$label é obrigatório' : null;

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dúvidas frequentes'),
        content: const SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _HelpEntry(question: 'Como faço login?', answer: 'Escolha seu perfil e use o e-mail e a senha cadastrados.'),
            _HelpEntry(question: 'Como agendo uma consulta?', answer: 'Após entrar como paciente, abra Consultas, localize um profissional e escolha Agendar.'),
            _HelpEntry(question: 'Como organizo meus medicamentos?', answer: 'Na área do paciente, cadastre medicamentos e horários para consultá-los no app. Notificações do sistema não fazem parte desta versão.'),
            _HelpEntry(question: 'Como funciona o processamento de documentos?', answer: 'O envio requer consentimento. A API limpa metadados, extrai texto e mascara identificadores antes de aprovar armazenamento. OCR exige Tesseract instalado.'),
            _HelpEntry(question: 'Posso usar documentos reais?', answer: 'Não. Este é um protótipo acadêmico: o OCR e o mascaramento podem falhar e não constituem anonimização validada.'),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fechar'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('MedGuide'),
        actions: [IconButton(tooltip: 'Dúvidas frequentes', onPressed: _showHelp, icon: const Icon(Icons.help_outline))],
      ),
      body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Consumer<AuthViewModel>(
                      builder: (context, auth, _) => Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.health_and_safety, size: 52, color: Color(0xFF087E8B)),
                            const SizedBox(height: 8),
                            Text(_registering ? 'Criar conta MedGuide' : 'Bem-vindo ao MedGuide',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Acompanhamento de saúde com cuidado e privacidade.',
                                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _role,
                              decoration: const InputDecoration(labelText: 'Perfil'),
                              items: const [
                                DropdownMenuItem(value: 'patient', child: Text('Paciente')),
                                DropdownMenuItem(value: 'doctor', child: Text('Profissional de saúde')),
                              ],
                              onChanged: (value) => setState(() => _role = value ?? 'patient'),
                            ),
                            if (_registering) ...[
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _name,
                                decoration: const InputDecoration(labelText: 'Nome'),
                                textCapitalization: TextCapitalization.words,
                                validator: (value) => value == null || value.trim().length < 3 ? 'Informe seu nome' : null,
                              ),
                            ],
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _email,
                              decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined)),
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              validator: (value) => value != null && value.contains('@') ? null : 'Informe um e-mail válido',
                            ),
                            if (_registering && _role == 'doctor') ...[
                              const SizedBox(height: 10),
                              TextFormField(controller: _crm, decoration: const InputDecoration(labelText: 'CRM'), validator: (value) => _required(value, 'CRM')),
                              const SizedBox(height: 10),
                              TextFormField(controller: _specialty, decoration: const InputDecoration(labelText: 'Especialidade'), validator: (value) => _required(value, 'Especialidade')),
                            ],
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _password,
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              validator: (value) => _registering
                                  ? (value != null && value.length >= 8 ? null : 'Use pelo menos 8 caracteres')
                                  : (value == null || value.isEmpty ? 'Informe sua senha' : null),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: auth.loading ? null : () => _submit(auth),
                              icon: auth.loading
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Icon(_registering ? Icons.person_add_alt_1 : Icons.login),
                              label: Text(_registering ? 'Criar conta' : 'Entrar'),
                            ),
                            TextButton(
                              onPressed: auth.loading ? null : () => setState(() => _registering = !_registering),
                              child: Text(_registering ? 'Já tenho uma conta' : 'Criar uma conta'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _HelpEntry extends StatelessWidget {
  const _HelpEntry({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(question),
        children: [Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(answer)))],
      );
}
