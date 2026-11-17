import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/api_client.dart';
import 'viewmodels/auth_view_model.dart';
import 'views/auth_screen.dart';
import 'views/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthViewModel(ApiClient());
  await auth.restoreSession();
  runApp(ChangeNotifierProvider.value(value: auth, child: const MedGuideApp()));
}

class MedGuideApp extends StatelessWidget {
  const MedGuideApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MedGuide',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087E8B)),
          scaffoldBackgroundColor: const Color(0xFFF5F8FA),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF5F8FA),
            surfaceTintColor: Colors.transparent,
            centerTitle: false,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFE5ECEF)),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: Color(0xFFDCE5E8)),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        home: Consumer<AuthViewModel>(
          builder: (context, auth, _) => auth.isAuthenticated
              ? const DashboardScreen()
              : const AuthScreen(),
        ),
      );
}
