import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/app_config.dart';
import 'services/app_state.dart';
import 'services/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Auto-detect jaringan ───────────────────────────────────────
  // Coba WLAN lokal dulu. Jika tidak tersedia → pakai Cloud Railway.
  await AppConfig.detect();
  debugPrint('[Network] Mode: ${AppConfig.connectionMode}');
  debugPrint('[Network] Server: ${AppConfig.baseUrl}');
  // ─────────────────────────────────────────────────────────────

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const InternalCloudApp(),
    ),
  );
}

class InternalCloudApp extends StatelessWidget {
  const InternalCloudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Internal Cloud',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF128C7E),
          primary: const Color(0xFF128C7E),
        ),
        useMaterial3: true,
      ),
      home: const RootGate(),
    );
  }
}

// Gerbang utama: cek login → tampilkan AuthScreen atau HomeScreen
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  @override
  void initState() {
    super.initState();
    // Cek apakah ada token tersimpan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkLogin();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Selama cek status, tampilkan splash singkat
    if (!auth.isLoggedIn) {
      return const AuthScreen();
    }
    return const HomeScreen();
  }
}
