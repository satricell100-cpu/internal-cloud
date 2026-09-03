import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:internal_cloud/services/auth_provider.dart';
import 'package:internal_cloud/services/app_state.dart';
import 'package:internal_cloud/screens/auth_screen.dart';
import 'package:internal_cloud/screens/home_screen.dart';
import 'package:internal_cloud/main.dart';

void main() {
  // Mock SharedPreferences agar provider tidak butuh plugin asli
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Verifikasi bahwa AuthScreen (layar pertama) RENDER tanpa crash.
  testWidgets('AuthScreen render: menampilkan tombol Masuk', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => AppState()),
        ],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Masuk'), findsWidgets);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  // Verifikasi bahwa RootGate menampilkan AuthScreen saat belum login
  // (aplikasi utama di-render dengan providers yang benar).
  testWidgets('RootGate menampilkan AuthScreen ketika belum login', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => AppState()),
        ],
        child: const InternalCloudApp(),
      ),
    );
    await tester.pump();
    // Belum login -> AuthScreen (bukan HomeScreen)
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
