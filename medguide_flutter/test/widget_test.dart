import 'package:flutter_test/flutter_test.dart';
import 'package:medguide_app/services/api_client.dart';
import 'package:medguide_app/viewmodels/auth_view_model.dart';
import 'package:medguide_app/views/auth_screen.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

void main() {
  group('ApiClient.messageFor', () {
    test('traduz erros de validação sem mostrar os valores enviados', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/register'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/register'),
          statusCode: 422,
          data: {
            'success': false,
            'error': {
              'code': 'VALIDATION_INVALID_FIELD',
              'message': 'Confira estes campos: e-mail.',
              'action': 'Corrija os campos indicados e tente novamente.',
              'request_id': 'correlation-id',
            },
          },
        ),
      );

      final message = ApiClient.messageFor(error);
      expect(message, contains('e-mail'));
      expect(message, contains('Corrija os campos'));
      expect(message, isNot(contains('correlation-id')));
    });

    test('orienta quando o serviço está temporariamente indisponível', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/privacy/ingest'),
        response: Response(requestOptions: RequestOptions(path: '/api/privacy/ingest'), statusCode: 503),
      );

      expect(ApiClient.messageFor(error), contains('temporariamente indisponível'));
    });
  });

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
