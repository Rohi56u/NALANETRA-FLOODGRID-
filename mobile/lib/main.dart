import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_store.dart';
import 'config.dart';
import 'login_screen.dart';
import 'app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppStore(),
      child: const NalaNetraApp(),
    ),
  );
}

class NalaNetraApp extends StatelessWidget {
  const NalaNetraApp({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: GovColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: GovColors.navy,
          secondary: GovColors.gold,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: GovColors.navy,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE0E6EF)),
          ),
        ),
      ),
      home: !store.ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : store.session == null
          ? const LoginScreen()
          : const AppShell(),
    );
  }
}
