import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';

// Layar login / registrasi
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _displayCtrl = TextEditingController();
  bool _isRegister = false;
  bool _obscure = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _displayCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();

    final bool ok;
    if (_isRegister) {
      ok = await auth.register(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
        _displayCtrl.text.trim().isEmpty
            ? _usernameCtrl.text.trim()
            : _displayCtrl.text.trim(),
      );
    } else {
      ok = await auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
    }

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Gagal masuk')),
      );
    }
    // Jika sukses, AuthProvider.isLoggedIn berubah → main.dart auto pindah layar
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF178A66), Color(0xFF0A5C43)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_upload,
                            size: 64, color: Color(0xFF178A66)),
                        const SizedBox(height: 8),
                        const Text(
                          'Internal Cloud',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRegister
                              ? 'Buat akun baru'
                              : 'Masuk ke akun kamu',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),

                        if (_isRegister) ...[
                          TextFormField(
                            controller: _displayCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nama Tampilan',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        TextFormField(
                          controller: _usernameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.alternate_email),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().length < 3)
                                  ? 'Minimal 3 karakter'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 4)
                              ? 'Minimal 4 karakter'
                              : null,
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF178A66),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                auth.isLoading ? null : () => _submit(),
                            child: auth.isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2)
                                : Text(
                                    _isRegister ? 'Daftar' : 'Masuk',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(
                              () => _isRegister = !_isRegister),
                          child: Text(
                            _isRegister
                                ? 'Sudah punya akun? Masuk'
                                : 'Belum punya akun? Daftar',
                          ),
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
    );
  }
}
