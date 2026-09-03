import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/auth_provider.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Akun'),
        backgroundColor: const Color(0xFF128C7E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(auth.user?.displayName ?? 'Pengguna'),
              subtitle: Text(auth.user?.username ?? 'Belum login'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.cloud),
                  title: Text('Google Drive'),
                  subtitle: Text('Belum terhubung. Fitur ini akan ditambahkan bertahap.'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.link),
                      label: const Text('Hubungkan Google'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Login Google/Drive belum aktif. Saya bisa lanjutkan tahap berikutnya.'),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Bagikan'),
                  subtitle: Text('Bagikan teks atau file ke aplikasi lain'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Bagikan demo link'),
                      onPressed: () => Share.share('Internal Cloud: https://localhost'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              onPressed: () => context.read<AuthProvider>().logout(),
            ),
          ),
        ],
      ),
    );
  }
}
