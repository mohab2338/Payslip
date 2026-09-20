import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../theme.dart';

/// Login-only screen. Sign-up is intentionally not exposed here — this app
/// is meant for a fixed, known set of accounts (created directly in the
/// Firebase console), not open public registration.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authService = AuthService();
  final _bioService = BiometricService();

  bool _loading = false;
  bool _obscure = true;
  String? _error;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _prefillAndCheckBiometrics();
  }

  Future<void> _prefillAndCheckBiometrics() async {
    final lastEmail = await _bioService.getLastEmail();
    final bioEnabled = await _bioService.isBiometricEnabled();
    final supported = await _bioService.isDeviceSupported();
    if (lastEmail != null) _emailCtrl.text = lastEmail;
    setState(() => _bioAvailable = supported && bioEnabled && lastEmail != null);
    if (_bioAvailable) {
      // Offer biometric unlock immediately.
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometricLogin());
    }
  }

  Future<void> _tryBiometricLogin() async {
    // Biometric unlock only works because Firebase Auth already persists the
    // session on-device; fingerprint just re-confirms it's the same person.
    if (_authService.currentUser == null) return;
    final ok = await _bioService.authenticate(reason: 'Unlock Salary Tracker');
    if (ok && mounted) {
      // AuthGate listens to authStateChanges and will navigate automatically.
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.signIn(email: _emailCtrl.text, password: _passCtrl.text);
      await _bioService.saveLastEmail(_emailCtrl.text.trim());
    } catch (e) {
      setState(() => _error = _authService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 32),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome back',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Track your salary, savings and spending.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'At least 6 characters' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Log in'),
                    ),
                  ),
                  if (_bioAvailable) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton.icon(
                        onPressed: _tryBiometricLogin,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Use fingerprint'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
