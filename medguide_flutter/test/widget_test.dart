import 'package:flutter_test/flutter_test.dart';
import 'package:medguide_app/services/api_client.dart';
import 'package:medguide_app/viewmodels/auth_view_model.dart';
import 'package:medguide_app/views/auth_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('exibe login e alterna para cadastro sem coletar CPF', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthViewModel(ApiClient()),
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    expect(find.text('Bem-vindo ao MedGuide'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    await tester.tap(find.text('Criar uma conta'));
    await tester.pumpAndSettle();

    expect(find.text('Criar conta MedGuide'), findsOneWidget);
    expect(find.text('Nome'), findsOneWidget);
    expect(find.text('CPF'), findsNothing);
  });
}
