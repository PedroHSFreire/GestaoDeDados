import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_view_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _specialty = TextEditingController();
  final _crm = TextEditingController();
  final _experience = TextEditingController();
  final _education = TextEditingController();
  final _bio = TextEditingController();
  bool _initialized = false;
  bool _editing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final user = context.read<AuthViewModel>().user!;
    _name.text = user.name;
    _email.text = user.email;
    _phone.text = user.phone ?? '';
    _address.text = user.address ?? '';
    _specialty.text = user.specialty ?? '';
    _crm.text = user.crm ?? '';
    _experience.text = user.experience ?? '';
    _education.text = user.education ?? '';
    _bio.text = user.bio ?? '';
    _initialized = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _specialty.dispose();
    _crm.dispose();
    _experience.dispose();
    _education.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save(AuthViewModel auth) async {
    if (!_formKey.currentState!.validate()) return;
    final changes = <String, dynamic>{
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'address': _address.text.trim(),
    };
    if (auth.user!.isDoctor) {
      changes.addAll({
        'crm': _crm.text.trim(),
        'specialty': _specialty.text.trim(),
        'experience': _experience.text.trim(),
        'education': _education.text.trim(),
        'bio': _bio.text.trim(),
      });
    }
    final ok = await auth.updateProfile(changes);
    if (!mounted) return;
    if (ok) {
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil atualizado.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Não foi possível atualizar o perfil.')));
    }
  }

  void _cancelEditing() {
    final user = context.read<AuthViewModel>().user!;
    _name.text = user.name;
    _email.text = user.email;
    _phone.text = user.phone ?? '';
    _address.text = user.address ?? '';
    _crm.text = user.crm ?? '';
    _specialty.text = user.specialty ?? '';
    _experience.text = user.experience ?? '';
    _education.text = user.education ?? '';
    _bio.text = user.bio ?? '';
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final user = auth.user!;
    final doctor = user.isDoctor;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const CircleAvatar(radius: 34, child: Icon(Icons.person, size: 36)),
                  const SizedBox(height: 14),
                  Text(user.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                  Text(user.email, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(doctor ? 'Profissional de saúde' : 'Paciente', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF087E8B))),
                  const SizedBox(height: 20),
                  if (!_editing) ...[
                    if (user.phone?.isNotEmpty == true) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.phone_outlined), title: Text(user.phone!)),
                    if (user.address?.isNotEmpty == true) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.location_on_outlined), title: Text(user.address!)),
                    if (doctor && user.crm != null) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.badge_outlined), title: Text('CRM ${user.crm}')),
                    if (doctor && user.specialty?.isNotEmpty == true) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.medical_services_outlined), title: Text(user.specialty!)),
                    if (doctor && user.experience?.isNotEmpty == true) ListTile(contentPadding: EdgeInsets.zero, title: Text('Experiência: ${user.experience}')),
                    if (doctor && user.education?.isNotEmpty == true) ListTile(contentPadding: EdgeInsets.zero, title: Text('Formação: ${user.education}')),
                    if (doctor && user.bio?.isNotEmpty == true) ListTile(contentPadding: EdgeInsets.zero, title: Text(user.bio!)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(onPressed: () => setState(() => _editing = true), icon: const Icon(Icons.edit_outlined), label: const Text('Editar perfil')),
                  ] else ...[
                    Form(
                      key: _formKey,
                      child: Column(children: [
                        TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nome'), validator: (value) => value == null || value.trim().length < 3 ? 'Informe seu nome' : null),
                        const SizedBox(height: 12),
                        TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'E-mail'), keyboardType: TextInputType.emailAddress, validator: (value) => value == null || !value.contains('@') ? 'Informe um e-mail válido' : null),
                        const SizedBox(height: 12),
                        TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Telefone (opcional)'), keyboardType: TextInputType.phone),
                        const SizedBox(height: 12),
                        TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Endereço (opcional)')),
                        if (doctor) ...[
                          const SizedBox(height: 12),
                          TextFormField(controller: _crm, decoration: const InputDecoration(labelText: 'CRM'), validator: (value) => value == null || value.trim().length < 3 ? 'Informe um CRM válido' : null),
                          const SizedBox(height: 12),
                          TextFormField(controller: _specialty, decoration: const InputDecoration(labelText: 'Especialidade'), validator: (value) => value == null || value.trim().length < 2 ? 'Informe a especialidade' : null),
                          const SizedBox(height: 12),
                          TextFormField(controller: _experience, decoration: const InputDecoration(labelText: 'Experiência (opcional)')),
                          const SizedBox(height: 12),
                          TextFormField(controller: _education, decoration: const InputDecoration(labelText: 'Formação (opcional)')),
                          const SizedBox(height: 12),
                          TextFormField(controller: _bio, decoration: const InputDecoration(labelText: 'Apresentação (opcional)'), minLines: 2, maxLines: 4),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: OutlinedButton(onPressed: auth.loading ? null : _cancelEditing, child: const Text('Cancelar'))),
                      const SizedBox(width: 12),
                      Expanded(child: FilledButton.icon(onPressed: auth.loading ? null : () => _save(auth), icon: auth.loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('Salvar'))),
                    ]),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
