import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import 'config.dart';
import 'login_screen.dart';
import 'store.dart';
import 'citizen_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppStore(),
      child: const NalaNetraApp(),
    ),
  );
}

class NalaNetraApp extends StatefulWidget {
  const NalaNetraApp({super.key});

  @override
  State<NalaNetraApp> createState() => _NalaNetraAppState();
}

class _NalaNetraAppState extends State<NalaNetraApp> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppStore>(
      builder: (context, store, _) {
        final isDark = store.themeMode == AppThemeMode.dark;
        return MaterialApp(
          title: appTitle,
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Poppins',
            colorScheme: ColorScheme.fromSeed(
              seedColor: GovColors.navy,
              brightness: Brightness.light,
              primary: GovColors.navy,
            ),
            scaffoldBackgroundColor: const Color(0xFFF4F6FB),
            appBarTheme: const AppBarTheme(
              backgroundColor: GovColors.navy,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Poppins',
            colorScheme: ColorScheme.fromSeed(
              seedColor: GovColors.navyDeep,
              brightness: Brightness.dark,
              primary: GovColors.gold,
            ),
            scaffoldBackgroundColor: const Color(0xFF0D1430),
          ),
          home: Consumer<AppStore>(
            builder: (context, store, _) {
              if (!store.authReady) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final hasVerifiedSession =
                  store.citizenSession != null || store.staffSession != null;
              return hasVerifiedSession
                  ? const CitizenPortal()
                  : const LoginScreen();
            },
          ),
          onGenerateRoute: (settings) =>
              NalaRouter.onGenerateRoute(context, settings),
        );
      },
    );
  }
}
