import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/backend_service.dart';
import '../../core/services/auth_state_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLogin = true;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    final backend = ref.read(backendServiceProvider);
    
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final email = _emailController.text.trim();

    if (username.isEmpty || password.isEmpty || (!_isLogin && email.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte alle Felder ausfüllen.')));
      setState(() => _isLoading = false);
      return;
    }

    if (_isLogin) {
      final success = await backend.loginUser(username, password);
      if (success) {
        await checkAuthStatus(ref);
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login fehlgeschlagen. Falsches Passwort oder Netzwerkfehler.')));
      }
    } else {
      final success = await backend.registerUser(username, password, email);
      if (success) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registrierung erfolgreich! Bitte logge dich nun ein.')));
           setState(() => _isLogin = true);
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registrierung fehlgeschlagen.')));
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Registrieren')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_sync, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 24),
            Text(
              _isLogin ? 'Willkommen zurück!' : 'Account erstellen',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Benutzername', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            if (!_isLogin) ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-Mail', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Passwort', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading ? const CircularProgressIndicator() : Text(_isLogin ? 'Einloggen' : 'Registrieren', style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() => _isLogin = !_isLogin);
              },
              child: Text(_isLogin ? 'Noch keinen Account? Hier registrieren.' : 'Bereits registriert? Zum Login.'),
            )
          ],
        ),
      ),
    );
  }
}
